# SYSTEM-MAP — methodology-platform

**Версия:** v1.6
**Обновлён:** 2026-05-20
**Граф проверен против кода:** 2026-05-20 (architecture-audit: 2 undocumented scripts added — mermaid-link.py, validate-artifact-map.sh; stack note: mixed Bash + Python); v1.5: added validate-mermaid-links.sh (S-2/R-003); v1.6: extended validate-artifact-map.sh checks (S-1/R-002)

> Обновлять этот файл в том же PR что и изменения в `scripts/`, `commands/`, `templates/`, или добавления компонентов.
>
> В отличие от обычных проектов, "компоненты" здесь — это **слои репозитория**, а "коммуникации" — это **отношения копирования** между методологией и консьюмерами.

---

## Agent TL;DR

- **Основные подсистемы:** Methodology Platform (canon — commands/templates/scripts) → Self-application (.claude/ в этом репо) → Consumers (проекты с произвольной архитектурой).
- **Источники правды:** `commands/`, `templates/` (включая `templates/.claude/hooks/` и `templates/.claude/agents/`), `VERSION` — единственный canon. `.claude/` в любом проекте — производное.
- **Критичные edges:** scripts (`new-project-init.sh`, `sync-methodology.sh`) → консьюмеры (copy + banner). Нарушение banner-механизма ломает версионную трассируемость.
- **Известные gap-ы:** branch protection не настроен (R-01); CI для idempotent тестирования скриптов отсутствует; нет auto version-drift check у консьюмеров; sync затирает per-project fills в `docs_reminder.py` LIBS.
- **На что обратить внимание при `/plan [data]` или `[contract]`:** изменение схемы `triggers.json.template` = **breaking** (мажор bump + migration). Изменение banner-формата в скриптах = breaking для версионной трассировки.

---

## Граф системы

> 🔗 [Открыть в Mermaid Live](https://mermaid.live/edit#pako:eNqVVu1u2lYYvpVXliqlm8Frm30oWiNRQxI0EhCQ_DFRZOwTOJ3tg3yO00WlU9au-9CmVZr2bzdBu6BGzdLcgn0LvZK959gEEwjpkAD7nMfP-_0cP9Uc5hJtTeuF9qAP7UedAPDDo2660NG2iegzl3msdwwNzxaHLPRhRfQph5AM2N2Olj4iP-Z2uWU5zPftwOXG193QWL93H7hn834hfhe_j_-NR_FFfKp2cEHevI8v9qcM7e1GzRLEH6AlklF8v_oZJL8g-HV8LuH4fQPxKDlJnsfj5EfceIdXuLic9mCrXv-mlSMvOp4ducToM_ZtZmoV4rfI_Gt8howXyW_JS0heJi8k5y3kpc3KTnsRu90jgcjoH0DyA1KMMY4xGhjhLZK_LiDpP7h6cVsYLbNZbaAV7oR0MCHtMia4wGrBp8CPAwf_fIrVEyQlOkObl0h0jnQyLGn9LEe6V2la-G1V6zvqAU78IxLmAM3dWqVlhZE3KQg6exafop18NOnORTwGVelLtHWCweEOBvkqoyOB2wnmWqxFvMOCPRh41LEFZQGsTJIHNIDFrdaq1DYOVL9NsLN9d-XEK_QSsHVkNtG75ES24f41orQ1FjTE_6PJmmBR6XNEyDKO386Sja5TtdqlduWKiQsspyFC2uuRkBcfcxYoVo85tgdqd46g0m5Xdzan3nAiBA16c087LDikvaUFMlnAI5-E8OHkLygFxzAI2WPiiJnZr--0drcrzQOzVtotT11Xlia10UHlVoc0NXrqOv5lvu0v4Cs129WNkol5TZmLvqtDo1kv75ptdb1Xlb2Ll4bK_0F6ryvD5cperb6pQ7VcKbV0aNZL5e1SQweXOdyw3dDQoVgsKii26XPVsqgmyQtZE8AbnJn4jSwR9vooPk9-x5WRDvL3aqrGCjWGAQkLWWaWpnOTiq2om09es9KoWz0q-lG3iLkyHJuKAmdeJMch6yBccclRwZ_q8fKaqfSDifIOK2EUCOqTWbE2rTzGrFXBkHkC8p0gAadZkyQ_K9UYyUmGSVE_ASnB58kf2MQ4BxBfqoEYKyUeL_Er_htBSuvi03g0dcalIWZNzn6tOV2t3bNK-1AorA8dNjhGwenaQUDCIdTuW49yvVJ7YJmIKyIwJLYLtoAsYoSuWuU89HOrsg8PH64Pn4QUdRrcKMTOAwNlOwAiHHziC2sj_8SX1qZ0gg0HEe8bg8jzEPOVtTUf5p07kD8uHTtgAZUz9uGnPzGtxIkEC3mKzbRcRSed5kN1fN64KU-ZpZupiC2HpAJ1IwaPgVwoc7J8RG0IyJNJjxdoQEWR97NzJ9-ZuDpv5FoNrxT845A3RCehw7z6zkOkm8Ocqi5HZLKZy0OZ4vFKu2oWQTApmEoNOaygqEW25x1DJs3EvXtrNNeEcrE3YIeCHtqO4MMFSphzrpn2OagKpqumOR0Fnr59wUSA59K-HDzn65zdBVOkgyFfKnU5TcUrK7mRU6I_X5FZUKrchhJuAzX6ljzMFMnpy1x7GS3GqsYX9RVyIyw1N0XI0bgdkXbgR-DSPlwOnNZ7IUjTNWww36Yuvpo_7WiiT3zS0dY6mksO7cjDk_cZYmzUkxaOnrYmwojoWjRwMbNlaqPY-unis_8AYzVlkw)
> _(обновить ссылку: `py scripts/mermaid-link.py docs/architecture/SYSTEM-MAP.md`)_

```mermaid
graph TB
    subgraph "Methodology Platform (this repo)"
        CMDS[commands/<br/>12 slash-команд<br/>канон]
        TMPL[templates/<br/>~40 шаблонов артефактов<br/>канон]
        TMPL_HOOKS[templates/.claude/hooks/<br/>4 защитных хука<br/>канон]
        TMPL_AGENTS[templates/.claude/agents/<br/>3 скелета суб-агентов<br/>канон]
        SCRIPTS[scripts/<br/>bootstrap + sync + migrate<br/>исполнители]
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

    subgraph "Consumer — Any project"
        CONSUMER_CLAUDE[.claude/<br/>commands, hooks, agents, state, settings]
        CONSUMER_ARTIFACTS[CLAUDE.md, PRODUCT.md, VISION.md/AGENT_VISION,<br/>DEVLOG, IDEAS, ROADMAP, docs/adr/, ...<br/>структура универсальна, наполнение per-project]
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
    SCRIPTS -->|reads| TMPL_HOOKS
    SCRIPTS -->|reads| TMPL_AGENTS
    SCRIPTS -->|reads| VER

    %% Self-application via new-project-init.sh + sync-methodology.sh
    SCRIPTS -->|copy + banner| SELF_CMDS
    SCRIPTS -->|copy + banner| SELF_HOOKS
    SCRIPTS -->|copy| SELF_AGENTS
    SCRIPTS -->|init| SELF_STATE
    SCRIPTS -->|init| SELF_SETTINGS

    %% Distribution to consumers (manually triggered)
    SCRIPTS -->|copy + banner| CONSUMER_CLAUDE
    SCRIPTS -->|init artifacts| CONSUMER_ARTIFACTS

    %% Runtime reads
    CC -.->|reads slash commands| SELF_CMDS
    CC -.->|reads slash commands| CONSUMER_CLAUDE

    %% Runtime writes during /plan, /code, etc.
    CC ==>|writes state| SELF_STATE
    CC ==>|writes DEVLOG/IDEAS/...| CONSUMER_ARTIFACTS

    %% Distribution channel
    CMDS --o|git push/pull| REPO
    TMPL --o|git push/pull| REPO
    TMPL_HOOKS --o|git push/pull| REPO
    TMPL_AGENTS --o|git push/pull| REPO
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

- **Назначение:** шаблоны для bootstrap новых проектов и для guided заполнения артефактов (~40 файлов)
- **Владелец:** владелец методологии
- **Стек:** Markdown с `{{Project Name}}` placeholders + JSON (triggers, settings) + YAML (services-registry)
- **Точки входа:** `templates/*.template.md`, `templates/*.template.json`, подкаталоги `templates/vision/`, `templates/adr/`, `templates/inbox/`, `templates/.claude/`
- **Зависимости:** читаются скриптом bootstrap

### `templates/.claude/hooks/` — Защитные хуки (канон)

- **Назначение:** PreToolUse / UserPromptSubmit хуки для Claude Code — блокируют опасные команды и edit-операции
- **Владелец:** владелец методологии
- **Стек:** Python 3.10+
- **Точки входа:** `bash_protect.py` (PreToolUse Bash), `protect.py` (PreToolUse Edit|Write), `docs_reminder.template.py` (UserPromptSubmit), `agent-gaps-watchdog.py` (Stop — AI error admission detector)
- **Зависимости:** stdin JSON от Claude Code; stderr выход к пользователю
- **Примечание:** расположены внутри `templates/.claude/` (Phase KK2). Копируются в `.claude/hooks/` у консьюмера через скрипты.

### `templates/.claude/agents/` — Скелеты суб-агентов (канон)

- **Назначение:** Claude Code sub-agent definitions (с YAML frontmatter) для `architect`, `qa`, `security`
- **Владелец:** владелец методологии (структура); владелец консьюмера (контент после копирования)
- **Стек:** Markdown с YAML frontmatter (`name`, `description`, `tools`)
- **Точки входа:** копируются на bootstrap; body заполняется per-project — sync **не** перезаписывает
- **Примечание:** расположены внутри `templates/.claude/` (Phase KK2). Копируются в `.claude/agents/` у консьюмера через скрипты.

### `scripts/` — Исполнители

- **Назначение:** bootstrap нового проекта, sync существующего, миграция split CLAUDE.md, структурная валидация артефактов, генерация mermaid.live ссылок
- **Владелец:** владелец методологии
- **Стек:** Bash 3.2+ (Git Bash на Windows совместим) **+ Python 3.10+** (для `mermaid-link.py`) — смешанный стек
- **Точки входа:**
  - `new-project-init.sh <name> [target-dir]` — bootstrap (Bash)
  - `sync-methodology.sh <target>` — sync (Bash; поддерживает self-apply: `bash scripts/sync-methodology.sh .`)
  - `migrate-claude-md.sh` — одноразовый хелпер для Phase G2 split CLAUDE.md → CLAUDE.md + CLAUDE_LONG.md (Bash)
  - `validate-artifact-map.sh` — Level-4 структурный валидатор ARTIFACT-MAP: (1) W→RW arrow type mismatches; (2) LANG — Cyrillic node ID = ERROR; (3) COVERAGE — команда в таблице без node-label в Mermaid = ERROR; (4) ISLAND — node без единой стрелки = WARNING; вызывается из `commands/architecture-audit.md`, `commands/deploy.md`, `commands/product-check.md` (Bash + встроенный Python)
  - `validate-mermaid-links.sh` — Level-4 валидатор mermaid.live ссылок: покрывает все .md файлы включая gitignored; проверяет наличие ссылки над каждым `\`\`\`mermaid` блоком + соответствие URL текущему коду; вызывается из `commands/code.md` Шаг 4 и `commands/review.md` Шаг 3; пропускает *.template.md и consumers/ (Bash + встроенный Python)
  - `mermaid-link.py` — генератор mermaid.live URL (pako-encoding: zlib level 9 + base64url) для любого Mermaid-блока в markdown; используется для обновления `🔗 [Открыть в Mermaid Live](<url>)` ссылок в SYSTEM-MAP / USER-MAP / ARTIFACT-MAP и т.п. (Python)
- **Зависимости:** читают `commands/`, `templates/`, `templates/.claude/hooks/`, `templates/.claude/agents/`, `VERSION`. `validate-artifact-map.sh` и `validate-mermaid-links.sh` парсят markdown с Mermaid-блоками. `mermaid-link.py` — stateless, только stdin/файл вход

### `rules/` — Документация (не копируется)

- **Назначение:** методический гид по написанию tech-stack-specific правил
- **Владелец:** владелец методологии
- **Стек:** Markdown
- **Точки входа:** `README.md` (объяснение), `_TEMPLATE.md` (пустой скелет для копирования вручную)
- **Зависимости:** консьюмеры копируют `_TEMPLATE.md` руками когда хотят написать правила своего стека

### `.claude/` (этот репо) — Self-application

- **Назначение:** методология применённая к самой себе (Phase F). Содержит копии с баннерами + локальный state.
- **Владелец:** автогенерируется через `sync-methodology.sh .`
- **Стек:** аналогично консьюмеру
- **Точки входа:** Claude Code читает при работе с этим репо
- **Зависимости:** производное от `commands/`, `templates/.claude/hooks/`, `templates/.claude/agents/`

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
