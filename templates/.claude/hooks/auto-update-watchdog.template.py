"""
SessionStart hook — methodology drift DETECTOR (read-only).

Запускается Claude Code при старте каждой сессии в проекте. ДВА read-only режима:

1. BOOTSTRAP detect — `.claude/.version` отсутствует:
   Методология никогда не инициализировалась. Hook печатает сообщение в контекст
   агента — агент предложит пользователю запустить `new-project-init.sh`.

2. DRIFT detect — `.claude/.version` существует:
   Hook СРАВНИВАЕТ версию консьюмера (.claude/.version) с локальным клоном методологии
   (VERSION) и, если консьюмер отстаёт, печатает read-only notify. Плюс hook-health
   drift detector (settings.json → отсутствующий hook-файл).

⛔ Push-only consolidation: консьюмеры НИКОГДА не обновляются сами. Доставка обновлений —
   ТОЛЬКО maintainer-driven через `/push-consumers` с репозитория методологии. Этот hook
   НЕ запускает sync, НЕ пишет в .claude/, НЕ коммитит — только ДЕТЕКТИРУЕТ и сообщает.
   (Раньше здесь был UPDATE mode с автономным `sync-methodology.sh --auto-commit` —
   удалён: конкурирующий писатель оставлял dirty .claude/ → deadlock в /push-consumers.)

Конфиг читается из CLAUDE.local.md секция `## Auto-update`:
- enabled (default: true) — выключить hook целиком
- methodology_path (default: ../it-dev-methodology) — где искать клон для version-сравнения

Wired в .claude/settings.json под "hooks.SessionStart".
Output попадает в системный prompt агента.
"""
import json
import re
import sys
from pathlib import Path

# Дефолты — переопределяются секцией ## Auto-update в CLAUDE.local.md
DEFAULTS = {
    "enabled": True,
    "methodology_path": "../it-dev-methodology",
}


def parse_config(claude_local_path: Path) -> dict:
    """Читает секцию ## Auto-update из CLAUDE.local.md. YAML-подобный плоский формат:
       enabled: true
       methodology_path: ../it-dev-methodology
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
        if isinstance(DEFAULTS[key], bool):
            config[key] = raw.strip().lower() in ("true", "yes", "1")
        else:
            config[key] = raw.strip().strip('"').strip("'")
    return config


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
    None если нельзя сравнить; 999 если major изменился (forced)."""
    b = parse_version(before)
    a = parse_version(after)
    if b is None or a is None:
        return None
    if b[0] != a[0]:
        return 999
    if a <= b:
        return 0
    return a[1] - b[1]


def check_hook_health(project_root: Path) -> None:
    """Детектор drift: settings.json ссылается на hook-файл которого НЕТ на диске.

    WHY (closes class «settings→missing hook → тихий fail», erp 2026-06-06):
    fix может быть в методологии, но если consumer не получил full sync (maintainer
    не запустил /push-consumers) — hook-файл отсутствует, а settings.json уже на него
    ссылается → каждый hook молча падает (sh: run-hook.sh: No such file).

    Печатает warning в контекст агента если найдены missing-хуки. Non-blocking, read-only.
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
    # run-hook.sh обёртку (sh .claude/hooks/run-hook.sh X.py → нужны ОБА).
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
            "   Причина: методология обновилась, но обновления ещё не доставлены в этот проект.\n"
            "   Рекомендация: maintainer доставит через /push-consumers с репозитория методологии."
        )


def main() -> int:
    project_root = Path.cwd()
    claude_local = project_root / "CLAUDE.local.md"
    version_file = project_root / ".claude" / ".version"

    config = parse_config(claude_local)
    if not config["enabled"]:
        return 0

    # Drift detector — независим, запускается каждый SessionStart. Read-only.
    check_hook_health(project_root)

    # BOOTSTRAP detect — нет .claude/.version, методология не инициализирована
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

    # DRIFT detect (read-only) — сравнить версию консьюмера с локальным клоном методологии.
    # НЕ синкаем, НЕ пишем .claude/ — только уведомление. Доставка = maintainer /push-consumers.
    methodology_path = (project_root / config["methodology_path"]).resolve()
    clone_version_file = methodology_path / "VERSION"
    consumer_version = read_version(version_file)
    clone_version = read_version(clone_version_file)
    delta = semver_minor_delta(consumer_version, clone_version)
    if delta is not None and delta != 0:
        delta_text = "major bump" if delta == 999 else f"{delta} minor"
        print(
            f"ℹ️ Methodology drift: проект на {consumer_version}, клон методологии на "
            f"{clone_version} ({delta_text} впереди).\n"
            f"   Этот проект НЕ обновляется сам — доставка только через /push-consumers\n"
            f"   с репозитория методологии (maintainer-driven). Сообщи maintainer'у если нужно обновить."
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
