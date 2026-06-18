"""
SessionStart hook — авто-обновление методологии + bootstrap detection.

Запускается Claude Code при старте каждой сессии в проекте. Два режима работы:

1. BOOTSTRAP mode — `.claude/.version` отсутствует:
   Методология никогда не была инициализирована в этом проекте.
   Hook печатает сообщение в контекст агента — агент в первом ответе
   предложит пользователю запустить `new-project-init.sh`.

2. UPDATE mode — `.claude/.version` существует:
   Hook проверяет когда был последний auto-pull (.claude/state/triggers.json
   → last_auto_pull.at). Если прошло больше `interval_hours` из конфига —
   запускает `sync-methodology.sh` для обновления команд/хуков/skills.

Конфиг читается из CLAUDE.local.md секция `## Auto-update`:
- enabled (default: true)
- interval_hours (default: 2)
- on_failure (notify|silent|block, default: notify)
- methodology_path (default: ../it-dev-methodology)

Wired в .claude/settings.json под "hooks.SessionStart".
Output попадает в системный prompt агента (как UserPromptSubmit).
"""
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# Дефолты — переопределяются секцией ## Auto-update в CLAUDE.local.md
DEFAULTS = {
    "enabled": True,
    "interval_hours": 2,
    "on_failure": "notify",  # notify | silent | block
    "methodology_path": "../it-dev-methodology",
    "audit_threshold": 3,  # minor version delta для recommendation /sync-audit
}

LOCK_TIMEOUT_SECONDS = 60


def parse_config(claude_local_path: Path) -> dict:
    """Читает секцию ## Auto-update из CLAUDE.local.md. YAML-подобный плоский формат:
       enabled: true
       interval_hours: 2
       Если файл/секция отсутствуют — возвращает DEFAULTS."""
    config = dict(DEFAULTS)
    if not claude_local_path.is_file():
        return config
    try:
        text = claude_local_path.read_text(encoding="utf-8-sig", errors="replace")
    except OSError:
        return config

    in_section = False
    line_re = re.compile(r"^\s*([a-z_]+)\s*:\s*(.+?)\s*$")
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            in_section = "auto-update" in stripped.lower()
            continue
        if not in_section:
            continue
        m = line_re.match(line)
        if not m:
            continue
        key, raw = m.group(1), m.group(2)
        if key not in DEFAULTS:
            continue
        # Type coercion
        if isinstance(DEFAULTS[key], bool):
            config[key] = raw.strip().lower() in ("true", "yes", "1")
        elif isinstance(DEFAULTS[key], int):
            try:
                config[key] = int(raw)
            except ValueError:
                pass
        else:
            config[key] = raw.strip().strip('"').strip("'")
    return config


def read_last_pull(triggers_path: Path) -> str | None:
    """Возвращает ISO timestamp последнего auto-pull или None."""
    if not triggers_path.is_file():
        return None
    try:
        # utf-8-sig: BOM-tolerant (PowerShell-written triggers.json carries EF BB BF) — closes G-081
        data = json.loads(triggers_path.read_text(encoding="utf-8-sig"))
        return data.get("last_auto_pull", {}).get("at")
    except (json.JSONDecodeError, OSError):
        return None


def write_last_pull(triggers_path: Path, version_before: str | None,
                    version_after: str | None, status: str,
                    error: str | None = None) -> None:
    """Обновляет last_auto_pull в triggers.json. Создаёт если нет."""
    try:
        data = json.loads(triggers_path.read_text(encoding="utf-8-sig")) if triggers_path.is_file() else {}
    except (json.JSONDecodeError, OSError):
        data = {}
    entry: dict = {
        "at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "version_before": version_before,
        "version_after": version_after,
        "status": status,
    }
    if error is not None:
        entry["error"] = error  # первые 300 символов stderr/stdout
    data["last_auto_pull"] = entry
    triggers_path.parent.mkdir(parents=True, exist_ok=True)
    triggers_path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def hours_since(iso_ts: str) -> float:
    try:
        dt = datetime.fromisoformat(iso_ts)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        delta = datetime.now(timezone.utc) - dt
        return delta.total_seconds() / 3600
    except (ValueError, TypeError):
        return float("inf")


def read_version(version_path: Path) -> str | None:
    if not version_path.is_file():
        return None
    try:
        text = version_path.read_text(encoding="utf-8-sig")
        # Формат: "methodology: v4.18.0" или просто "v4.18.0"
        m = re.search(r"v?\d+\.\d+\.\d+", text)
        return m.group(0) if m else None
    except OSError:
        return None


def try_lock(lock_path: Path) -> bool:
    """Атомарная попытка взять lock. True если получили, False если другая сессия держит."""
    if lock_path.is_file():
        try:
            ts = lock_path.stat().st_mtime
            age = (datetime.now(timezone.utc).timestamp() - ts)
            if age < LOCK_TIMEOUT_SECONDS:
                return False
            # Stale lock — затираем
        except OSError:
            pass
    try:
        lock_path.parent.mkdir(parents=True, exist_ok=True)
        lock_path.write_text(str(os.getpid()), encoding="utf-8")
        return True
    except OSError:
        return False


def release_lock(lock_path: Path) -> None:
    try:
        lock_path.unlink()
    except OSError:
        pass


def parse_version(v: str | None) -> tuple[int, int, int] | None:
    """Парсит 'v4.22.0' или '4.22.0' → (4, 22, 0). None при невалидном."""
    if not v:
        return None
    m = re.match(r"v?(\d+)\.(\d+)\.(\d+)", v.strip())
    if not m:
        return None
    return (int(m.group(1)), int(m.group(2)), int(m.group(3)))


def semver_minor_delta(before: str | None, after: str | None) -> int | None:
    """Возвращает количество minor versions между before и after (для same major).
    None если нельзя сравнить или major изменился (forced trigger через 999)."""
    b = parse_version(before)
    a = parse_version(after)
    if b is None or a is None:
        return None
    if b[0] != a[0]:
        return 999  # major bump = forced trigger
    if a <= b:
        return 0
    return a[1] - b[1]


def check_hook_health(project_root: Path) -> None:
    """Детектор drift: settings.json ссылается на hook-файл которого НЕТ на диске.

    WHY (closes class «settings→missing hook → тихий fail», erp 2026-06-06):
    fix может быть в методологии, но если consumer не сделал full sync — hook-файл
    отсутствует, а settings.json уже на него ссылается → каждый hook молча падает
    (sh: run-hook.sh: No such file). Ничто это не детектило. Реальный пример: erp
    iteration-watchdog.py + run-hook.sh отсутствовали, settings ссылался → G-082 fix
    был мёртв у консьюмера, повтор reasoning-depth залипания.

    Печатает warning в контекст агента если найдены missing-хуки. Non-blocking.
    """
    settings_file = project_root / ".claude" / "settings.json"
    hooks_dir = project_root / ".claude" / "hooks"
    if not settings_file.is_file():
        return
    try:
        text = settings_file.read_text(encoding="utf-8-sig", errors="replace")
    except OSError:
        return
    # Извлечь имена hook-файлов: и прямой вызов (.claude/hooks/X.py), и через
    # run-hook.sh обёртку (sh .claude/hooks/run-hook.sh X.py → нужны ОБА: run-hook.sh И X.py).
    referenced: set[str] = set()
    for m in re.finditer(r'\.claude/hooks/([A-Za-z0-9._-]+)', text):
        referenced.add(m.group(1))
    for m in re.finditer(r'run-hook\.sh\s+([A-Za-z0-9._-]+)', text):
        referenced.add(m.group(1))
    missing = sorted(h for h in referenced if not (hooks_dir / h).is_file())
    if missing:
        print(
            "⚠️ HOOK DRIFT detected — settings.json ссылается на отсутствующие hook-файлы:\n"
            + "".join(f"   • .claude/hooks/{h} — НЕ найден на диске\n" for h in missing)
            + "   Следствие: эти хуки молча падают (sh: No such file) → защита/детекторы не работают.\n"
            "   Причина: методология обновилась, но full sync не прогонялся в этом проекте.\n"
            "   Рекомендация: предложи пользователю `bash <methodology>/scripts/sync-methodology.sh .`"
        )


def main() -> int:
    project_root = Path.cwd()
    claude_local = project_root / "CLAUDE.local.md"
    version_file = project_root / ".claude" / ".version"
    triggers_file = project_root / ".claude" / "state" / "triggers.json"
    lock_file = project_root / ".claude" / ".auto-update.lock"

    config = parse_config(claude_local)
    if not config["enabled"]:
        return 0

    # Drift detector — независим от update-cadence (запускается каждый SessionStart).
    # Ловит «settings→missing hook» даже если auto-update interval ещё не наступил.
    check_hook_health(project_root)

    # Re-notify если прошлый auto-pull завершился с ошибкой.
    # Повторяем при каждом SessionStart пока status не сменится на success,
    # чтобы failed не терялся тихо (closes G-112b / PLAN-03).
    if triggers_file.is_file():
        try:
            _tdata = json.loads(triggers_file.read_text(encoding="utf-8-sig"))
            _last = _tdata.get("last_auto_pull") or {}
            if _last.get("status") == "failed":
                _err = _last.get("error", "")
                _err_hint = f": {_err[:200]}" if _err else ""
                print(
                    f"⚠️ Прошлый auto-pull FAILED (at {_last.get('at', '?')}){_err_hint}\n"
                    f"   Методология может быть устаревшей. Запусти `/sync-audit` или\n"
                    f"   `bash scripts/sync-methodology.sh .` для диагностики."
                )
        except (json.JSONDecodeError, OSError):
            pass

    # BOOTSTRAP mode — нет .claude/.version, методология не инициализирована
    if not version_file.is_file():
        methodology_path = (project_root / config["methodology_path"]).resolve()
        init_script = methodology_path / "scripts" / "new-project-init.sh"
        if methodology_path.is_dir() and init_script.is_file():
            print(
                f"🔧 Methodology bootstrap detected — `.claude/.version` отсутствует в этом проекте.\n"
                f"   Методология никогда не была инициализирована.\n"
                f"   Рекомендация: предложи пользователю запустить:\n"
                f"     `bash {init_script} .`\n"
                f"   (Конфиг: methodology_path={config['methodology_path']} из CLAUDE.local.md)"
            )
        else:
            print(
                f"🔧 Methodology bootstrap detected — `.claude/.version` отсутствует.\n"
                f"   Каталог методологии не найден по пути: {methodology_path}\n"
                f"   Рекомендация: предложи пользователю склонировать it-dev-methodology рядом с проектом\n"
                f"   (`git clone https://github.com/cait-solutions/it-dev-methodology ../it-dev-methodology`)\n"
                f"   и запустить `bash ../it-dev-methodology/scripts/new-project-init.sh .`"
            )
        return 0

    # UPDATE mode — проверка интервала
    last_at = read_last_pull(triggers_file)
    if last_at is not None and hours_since(last_at) < config["interval_hours"]:
        return 0  # Свежий sync, тихий выход

    # Lock — защита от race condition двух параллельных сессий
    if not try_lock(lock_file):
        return 0  # Другая сессия уже синхронизирует

    try:
        methodology_path = (project_root / config["methodology_path"]).resolve()
        sync_script = methodology_path / "scripts" / "sync-methodology.sh"
        if not sync_script.is_file():
            message = (
                f"⚠️ Auto-update: скрипт sync-methodology.sh не найден по пути {sync_script}.\n"
                f"   Проверь methodology_path в CLAUDE.local.md секция ## Auto-update."
            )
            if config["on_failure"] == "notify":
                print(message)
            elif config["on_failure"] == "block":
                print(message, file=sys.stderr)
                return 1
            return 0

        version_before = read_version(version_file)

        result = subprocess.run(
            ["bash", str(sync_script), str(project_root), "--auto-commit"],
            capture_output=True,
            text=True,
            timeout=120,
        )

        version_after = read_version(version_file)
        status = "success" if result.returncode == 0 else "failed"
        # Собрать error excerpt: предпочитаем stderr, fallback на stdout (errors=replace — cp1252 safe)
        error_excerpt: str | None = None
        if result.returncode != 0:
            raw_err = (result.stderr or result.stdout or "").strip()
            error_excerpt = raw_err[:300] if raw_err else f"exit code {result.returncode}"
        write_last_pull(triggers_file, version_before, version_after, status, error=error_excerpt)

        if result.returncode != 0:
            message = (
                f"⚠️ Auto-update: sync-methodology.sh завершился с ошибкой (код {result.returncode}).\n"
                f"   stderr: {(result.stderr or result.stdout or '').strip()[:300]}\n"
                f"   Запусти вручную для диагностики: `bash {sync_script} .`"
            )
            if config["on_failure"] == "notify":
                print(message)
            elif config["on_failure"] == "block":
                print(message, file=sys.stderr)
                return 1
            return 0

        # Успех — печатать только если версия реально изменилась (anti-spam)
        # Guard: version_before=None означает bootstrap (первый sync) — не триггерим sync-audit
        if version_before is not None and version_before != version_after and version_after is not None:
            delta = semver_minor_delta(version_before, version_after)
            delta_text = "major bump" if delta == 999 else (f"{delta} minor" if delta else "patch")
            print(f"✓ Methodology auto-synced: {version_before} → {version_after} ({delta_text})")

            # Директивная инструкция агенту — выполнить /sync-audit в этой сессии.
            # Не рекомендация: версия изменилась = adoption-gap возможен, аудит обязателен.
            print(
                f"\n🔄 SYNC-AUDIT REQUIRED — methodology обновилась ({version_before} → {version_after}).\n"
                f"   Выполни /sync-audit прямо сейчас (до ответа на другие запросы):\n"
                f"   1. Прочитай .claude/.version (текущая: {version_after})\n"
                f"   2. Открой CHANGELOG.md в methodology repo — что добавилось\n"
                f"   3. Выполни шаги /sync-audit: delta analysis, gap-проверки (Gaps 1-8), report\n"
                f"   ⚠️ Если пользователь уже написал срочный запрос — выполни его сначала,\n"
                f"      затем /sync-audit в этой же сессии.\n"
                f"   (Настройка: methodology_path={config['methodology_path']} из CLAUDE.local.md)"
            )

        return 0

    except subprocess.TimeoutExpired:
        message = "⚠️ Auto-update: sync-methodology.sh timeout (>120s). Запусти вручную."
        if config["on_failure"] == "notify":
            print(message)
        return 0
    finally:
        release_lock(lock_file)


if __name__ == "__main__":
    sys.exit(main())
