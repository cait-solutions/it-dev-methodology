# SYSTEM-MAP — methodology-platform

**Версия:** v1.1
**Обновлён:** 2026-05-16
**Граф проверен против кода:** 2026-05-16 (Phase G2)

> Обновлять этот файл в том же PR что и изменения в `scripts/`, `commands/`, `templates/`, или добавления компонентов.
>
> В отличие от обычных проектов, "компоненты" здесь — это **слои репозитория**, а "коммуникации" — это **отношения копирования** между методологией и консьюмерами.

---

## Agent TL;DR

- **Основные подсистемы:** Methodology Platform (canon — commands/templates/hooks/agents/scripts) → Self-application (.claude/ в этом репо) → Consumers (PAI, ERP).
- **Источники правды:** `commands/`, `templates/`, `hooks/`, `agents/`, `VERSION` — единственный canon. `.claude/` в любом проекте — производное.
- **Критичные edges:** scripts (`new-project-init.sh`, `sync-methodology.sh`) → консьюмеры (copy + banner). Нарушение banner-механизма ломает версионную трассируемость.
- **Известные gap-ы:** branch protection не настроен (R-01); CI для idempotent тестирования скриптов отсутствует; нет auto version-drift check у консьюмеров; sync затирает per-project fills в `docs_reminder.py` LIBS.
- **На что обратить внимание при `/plan [data]` или `[contract]`:** изменение схемы `triggers.json.template` = **breaking** (мажор bump + migration). Изменение banner-формата в скриптах = breaking для версионной трассировки.

---

## Граф системы

```mermaid
graph TB
    subgraph "Methodology Platform (this repo)"
        CMDS[commands/<br/>12 slash-команд<br/>канон]
        TMPL[templates/<br/>~20 шаблонов артефактов<br/>канон]
        HOOKS[hooks/<br/>3 защитных хука<br/>канон]
        AGENTS[agents/<br/>3 скелета суб-агентов<br/>канон]
        SCRIPTS[scripts/<br/>bootstrap + sync<br/>исполнители]
        VER[VERSION<br/>semver]
        RULES[rules/<br/>гид + скелет<br/>не копируется]
    end

    subgraph "Self-application (.claude/ in this repo)"
        SELF_CMDS[.claude/commands/<br/>копия с баннером]
        SELF_HOOKS[.claude/hooks/<br/>копия с баннером]
        SELF_AGENTS[.claude/agents/<br/>копия без баннера]
        SELF_STATE[.claude/state/triggers.json<br/>local state]
        SELF_SETTINGS[.claude/settings.json<br/>local config]
    end

    subgraph "Consumer A — PAI (single-developer)"
        PAI_CLAUDE[.claude/<br/>commands, hooks, agents, state, settings]
        PAI_ARTIFACTS[CLAUDE.md, PRODUCT.md, VISION.md,<br/>DEVLOG, IDEAS, ROADMAP, ...<br/>заполнены per-project]
    end

    subgraph "Consumer B — ERP (multi-service)"
        ERP_CLAUDE[.claude/<br/>commands, hooks, agents, state, settings]
        ERP_ARTIFACTS[CLAUDE.md, PRODUCT.md,<br/>docs/vision/AGENT_VISION + LONG_VISION,<br/>docs/adr/, services-registry.yaml,<br/>inbox/, ...]
    end

    subgraph "GitHub"
        REPO[github.com/cait-solutions/<br/>it-dev-methodology]
    end

    subgraph "Claude Code (runtime)"
        CC[Claude Code CLI / IDE extension<br/>читает .claude/* в любом проекте]
    end

    subgraph Легенда
        direction LR
        L1[A] -->|copy + banner| L2[B]
        L3[C] -.->|read at runtime| L4[D]
        L5[E] ==>|writes during /plan etc| L6[F]
        L7[G] --o|push/pull| L8[H]
    end

    %% Methodology canonical → executors
    SCRIPTS -->|reads| CMDS
    SCRIPTS -->|reads| TMPL
    SCRIPTS -->|reads| HOOKS
    SCRIPTS -->|reads| AGENTS
    SCRIPTS -->|reads| VER

    %% Self-application via new-project-init.sh + sync-methodology.sh
    SCRIPTS -->|copy + banner| SELF_CMDS
    SCRIPTS -->|copy + banner| SELF_HOOKS
    SCRIPTS -->|copy| SELF_AGENTS
    SCRIPTS -->|init| SELF_STATE
    SCRIPTS -->|init| SELF_SETTINGS

    %% Distribution to consumers (manually triggered)
    SCRIPTS -->|copy + banner| PAI_CLAUDE
    SCRIPTS -->|copy + banner| ERP_CLAUDE
    SCRIPTS -->|init artifacts| PAI_ARTIFACTS
    SCRIPTS -->|init artifacts| ERP_ARTIFACTS

    %% Runtime reads
    CC -.->|reads slash commands| SELF_CMDS
    CC -.->|reads slash commands| PAI_CLAUDE
    CC -.->|reads slash commands| ERP_CLAUDE

    %% Runtime writes during /plan, /code, etc.
    CC ==>|writes state| SELF_STATE
    CC ==>|writes DEVLOG/IDEAS/...| PAI_ARTIFACTS
    CC ==>|writes DEVLOG/IDEAS/...| ERP_ARTIFACTS

    %% Distribution channel
    CMDS --o|git push/pull| REPO
    TMPL --o|git push/pull| REPO
    HOOKS --o|git push/pull| REPO
    AGENTS --o|git push/pull| REPO
    SCRIPTS --o|git push/pull| REPO
```

**Легенда:**
- `-->` Копирование (с баннером для синхронизируемых артефактов)
- `-.->` Чтение в runtime (Claude Code читает slash-команды и хуки)
- `==>` Запись в runtime (Claude Code обновляет triggers.json, DEVLOG, etc.)
- `--o` Распространение через git (push/pull в GitHub)

---

## Компоненты

### `commands/` — Slash-команды (канон)

- **Назначение:** определения 12 slash-команд (`/plan`, `/code`, `/review`, `/deploy`, `/retro`, `/diagnose`, `/onboard`, `/architecture-audit`, `/sync-vision`, `/product-vision`, `/product-review`, `/product-check`)
- **Владелец:** владелец методологии
- **Стек:** Markdown
- **Точки входа:** каждый файл — отдельная команда
- **Зависимости:** читают `.claude/state/triggers.json` в консьюмере; могут читать другие артефакты (DEVLOG, IDEAS, etc.)
- **Записывает:** через инструкции Claude Code — обновления `triggers.json`, записи в DEVLOG/IDEAS/RISKS/OPEN-QUESTIONS

### `templates/` — Шаблоны артефактов (канон)

- **Назначение:** шаблоны для bootstrap новых проектов и для guided заполнения артефактов
- **Владелец:** владелец методологии
- **Стек:** Markdown с `{{Project Name}}` placeholders + JSON (triggers, settings) + YAML (services-registry)
- **Точки входа:** `templates/*.template.md`, `templates/*.template.json`, подкаталоги `templates/vision/`, `templates/adr/`, `templates/inbox/`
- **Зависимости:** читаются скриптом bootstrap

### `hooks/` — Защитные хуки (канон)

- **Назначение:** PreToolUse / UserPromptSubmit хуки для Claude Code — блокируют опасные команды и edit-операции
- **Владелец:** владелец методологии
- **Стек:** Python 3.10+
- **Точки входа:** `bash_protect.py` (PreToolUse Bash), `protect.py` (PreToolUse Edit|Write), `docs_reminder.template.py` (UserPromptSubmit)
- **Зависимости:** stdin JSON от Claude Code; stderr выход к пользователю

### `agents/` — Скелеты суб-агентов (канон)

- **Назначение:** Claude Code sub-agent definitions (с YAML frontmatter) для `architect`, `qa`, `security`
- **Владелец:** владелец методологии (структура); владелец консьюмера (контент после копирования)
- **Стек:** Markdown с YAML frontmatter (`name`, `description`, `tools`)
- **Точки входа:** копируются на bootstrap; body заполняется per-project — sync **не** перезаписывает

### `scripts/` — Исполнители

- **Назначение:** bootstrap нового проекта и sync существующего
- **Владелец:** владелец методологии
- **Стек:** Bash 3.2+ (Git Bash на Windows совместим)
- **Точки входа:**
  - `new-project-init.sh <name> [target] [flags]` — bootstrap
  - `sync-methodology.sh <target>` — sync
- **Зависимости:** читают `commands/`, `templates/`, `hooks/`, `agents/`, `VERSION`

### `rules/` — Документация (не копируется)

- **Назначение:** методический гид по написанию tech-stack-specific правил
- **Владелец:** владелец методологии
- **Стек:** Markdown
- **Точки входа:** `README.md` (объяснение), `_TEMPLATE.md` (пустой скелет для копирования вручную)
- **Зависимости:** консьюмеры копируют `_TEMPLATE.md` руками когда хотят написать правила своего стека

### `.claude/` (этот репо) — Self-application

- **Назначение:** методология применённая к самой себе (Phase F). Содержит копии с баннерами + локальный state.
- **Владелец:** автогенерируется через `new-project-init.sh .`
- **Стек:** аналогично консьюмеру
- **Точки входа:** Claude Code читает при работе с этим репо
- **Зависимости:** производное от `commands/`, `hooks/`, `agents/`

---

## Внешние зависимости

| Сервис | Назначение | Владелец | SLA / тариф |
|---|---|---|---|
| GitHub | Хранение репо, версионирование, distribution | GitHub Inc. | free tier (public repo, < 1000 contributors) |
| Anthropic Claude API | Backend для Claude Code | Anthropic | по тарифу пользователя |
| Python 3.10+ | Runtime для хуков | n/a | устанавливается локально консьюмером |
| Git Bash (Windows) или Bash 3.2+ (Mac/Linux) | Runtime для скриптов | n/a | системный |

---

## Инфраструктура

- **Cloud provider:** GitHub Pages не используется; репо чисто как git source
- **Регионы:** n/a (статический git)
- **CI/CD:** **не настроен** (R-02 в RISKS); deploy = `git push origin main` ручной
- **Secrets management:** только локальный `git config` для PAT — в репо нет ничего секретного
- **Monitoring:** n/a (нет runtime сервиса)
- **Logging:** git log + DEVLOG.md

---

## Известные пробелы и техдолг

- **Branch protection не настроен** — любой с write-доступом может push в main без PR. Мера: настроить required PR + review (см. RISKS R-01).
- **Нет CI** для проверки идемпотентности bootstrap + sync. Мера: добавить GitHub Actions workflow который запускает оба скрипта на чистом target и проверяет diff (см. RISKS R-02).
- **Нет автоматического version-drift check** для консьюмеров. Сейчас `.claude/.version` в консьюмере существует но не проверяется автоматически в `/plan`. Мера: добавить чтение и сравнение в `/plan` Шаг -3 (см. VISION ось 1).
- **Sync overwrites `docs_reminder.py` LIBS dict** — задокументировано, но user-friendly не закрыто. Мера: поддержка `docs_reminder.local.py` соседнего файла.

---

## Изменения карты

Изменения фиксируются в git history этого файла.
Аудит на дрейф: запустить `/architecture-audit` периодически (хотя для методологии граф простой и меняется редко).
