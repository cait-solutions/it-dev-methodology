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
        text = claude_local_path.read_text(encoding="utf-8", errors="replace")
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
        data = json.loads(triggers_path.read_text(encoding="utf-8"))
        return data.get("last_auto_pull", {}).get("at")
    except (json.JSONDecodeError, OSError):
        return None


def write_last_pull(triggers_path: Path, version_before: str | None,
                    version_after: str | None, status: str) -> None:
    """Обновляет last_auto_pull в triggers.json. Создаёт если нет."""
    try:
        data = json.loads(triggers_path.read_text(encoding="utf-8")) if triggers_path.is_file() else {}
    except (json.JSONDecodeError, OSError):
        data = {}
    data["last_auto_pull"] = {
        "at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "version_before": version_before,
        "version_after": version_after,
        "status": status,
    }
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
        text = version_path.read_text(encoding="utf-8")
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


def main() -> int:
    project_root = Path.cwd()
    claude_local = project_root / "CLAUDE.local.md"
    version_file = project_root / ".claude" / ".version"
    triggers_file = project_root / ".claude" / "state" / "triggers.json"
    lock_file = project_root / ".claude" / ".auto-update.lock"

    config = parse_config(claude_local)
    if not config["enabled"]:
        return 0

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
            ["bash", str(sync_script), str(project_root)],
            capture_output=True,
            text=True,
            timeout=120,
        )

        version_after = read_version(version_file)
        status = "success" if result.returncode == 0 else "failed"
        write_last_pull(triggers_file, version_before, version_after, status)

        if result.returncode != 0:
            message = (
                f"⚠️ Auto-update: sync-methodology.sh завершился с ошибкой (код {result.returncode}).\n"
                f"   stderr: {result.stderr.strip()[:300]}\n"
                f"   Запусти вручную для диагностики: `bash {sync_script} .`"
            )
            if config["on_failure"] == "notify":
                print(message)
            elif config["on_failure"] == "block":
                print(message, file=sys.stderr)
                return 1
            return 0

        # Успех — печатать только если версия реально изменилась (anti-spam)
        if version_before != version_after and version_after is not None:
            print(f"✓ Methodology auto-synced: {version_before} → {version_after}")

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
