# CLAUDE.md — methodology-platform

Operational rules. Short form. For rationale and history — see [CLAUDE_LONG.md](CLAUDE_LONG.md).

> **Convention:** CLAUDE.md = WHAT (rules). CLAUDE_LONG.md = WHY (rationale, edge cases, examples).

**Project type:** `methodology-platform` — особый. Это продукт методологии для других проектов. Runtime-проверки неприменимы. Применимы: контракты команд, валидность скриптов, кросс-ссылки артефактов.

---

## Read before work

1. [VISION.md](VISION.md) перед каждым `/plan`
2. [PRODUCT.md](PRODUCT.md) — что методология обещает консьюмерам
3. [SYSTEM-MAP.md](docs/architecture/SYSTEM-MAP.md) — связи компонентов

---

## Architecture invariants (MUST / MUST NOT)

Методология = 5 слоёв (см. [SYSTEM-MAP.md](docs/architecture/SYSTEM-MAP.md)): команды / шаблоны / хуки / агенты-скелеты / скрипты.

**MUST:**
- `commands/`, `templates/`, `hooks/`, `agents/` — единственный источник правды
- Любая правка синхронизируемого артефакта → bump VERSION
- При изменении схемы `triggers.json.template` → мажор bump

**MUST NOT:**
- ❌ Редактировать `.claude/commands/*.md` напрямую — это банер-prefixed копии; канон в `commands/`
- ❌ Удалять команды без мажор bump VERSION + migration инструкция (breaking)
- ❌ Использовать bash 4-features (`${var,,}`, associative arrays) — Git Bash на Windows ставит 3.2
- ❌ Дублировать контент между шаблонами

Rationale: [CLAUDE_LONG.md § Architecture](CLAUDE_LONG.md).

---

## Stack

- **Скрипты:** Bash 3.2+ (Git Bash on Windows)
- **Хуки:** Python 3.10+
- **Шаблоны:** Markdown + JSON + YAML
- **CI/CD:** ручной push в GitHub
- **Деплой:** `git push origin main`; consumers подтягивают через `sync-methodology.sh`

---

## Data ownership (short)

| Слой | Источник правды | Кто пишет | Инвалидация |
|---|---|---|---|
| `commands/*.md` | да | владелец | при правке + push |
| `templates/*.md` | да | владелец | при правке + push |
| `hooks/*.py` | да | владелец | при правке + push |
| `agents/*.template.md` | да | владелец (структура); консьюмер (тело) | при правке + push |
| `VERSION` | да | владелец | при ручном bump |
| `.claude/` (этот репо) | нет (производное) | `new-project-init.sh .` | при self-sync |
| Консьюмер `.claude/commands/*.md` | нет (производное) | `sync-methodology.sh` | при sync |

Full table with examples and trade-offs: [CLAUDE_LONG.md § Data map](CLAUDE_LONG.md#карта-данных-полная).

---

## Don'ts

- ❌ Не редактировать `.claude/commands/*.md` напрямую (банер-prefixed копии)
- ❌ Не удалять команды без мажор bump + migration
- ❌ Не ломать `{{Project Name}}` плейсхолдер
- ❌ Не использовать bash 4+
- ❌ Не коммитить `.claude/settings.local.json`
- ❌ Не дублировать контент между шаблонами
- ❌ Не использовать project-specific имена в templates (canon + consumers должны быть абстрактны; примеры в comments только)

---

## Workflow rules

**Implementation through /code:** после `/plan` — реализация через `/code`. Прямая правка нетривиальных изменений запрещена.

**Deploy branch tracing (F5):** Деплой через `/deploy` команду выполняется на ветке `ai-dev` (или другой designated для agent deploys) чтобы различить agent-automated от manual human work. Team collaboration: git log показывает "commit by Claude on ai-dev" vs "commit by John on feature/auth". Это важно для audit trail и regression tracking.

**Deploy rule:** "деплой" = `git push origin main`. Перед каждым push:
1. `/review` если не запускался
2. DEVLOG запись `[deploy]` / `[feat:X]` / `[fix:X]` / `[methodology]`
3. Bump VERSION если изменены команды / шаблоны / хуки

**Architecture decision rule:** новая команда / шаблон / изменение `triggers.json` схемы → запустить `architect` sub-agent. Сначала собственная рекомендация, потом architect.

**Fix rule:**
- Симптом или причина? Симптом → найди причину
- Локальный или системный? Локальный без обоснования = красный флаг

**Completeness rule:**
Каждое решение (в /plan, /code, /review, /deploy) ДОЛЖНО явно указать:
- Что закрывается (main path, happy cases)
- Что НЕ закрывается (gaps, edge cases, параллельные пути)
- Почему эти gaps OK или требуют дополнительных шагов
Без этого анализа → план не утверждён, код не merged, деплой не выполнен.

Rationale and historical examples: [CLAUDE_LONG.md § Workflow rules](CLAUDE_LONG.md).

---

## Regulator levels (Level-4 framework)

Strong → weak: Schema constraint > No alternative path > Input structure > Few-shot > Description > Prompt rule.

При добавлении правила → спросить "есть ли level-4+ структурный фикс?". Если да — primary, правило secondary.

Пример: defensive `triggers.json` чтение в командах = level-1. Level-4 — единая схема в `templates/triggers.json.template`.

Details: [CLAUDE_LONG.md § Level-4 framework](CLAUDE_LONG.md).

---

## Model tier rule

Каждая команда методологии MUST содержать секцию `## Рекомендуемая модель` (5 полей: Default tier / Upgrade / Downgrade / Mid-task escalation / Pre-flight model check).

Канон: [.claude/model-tiers.md](.claude/model-tiers.md). При добавлении новой команды → добавь строку в матрицу + секцию в command-файл; `/review` блокирует merge без обеих.

Pre-flight check **спрашивает пользователя** о текущей модели (не self-detect — system prompt unreliable). Подтверждённое значение переиспользуется в сессии.

Когда Anthropic переименовывает модели — обнови **только** Mapping таблицу в `model-tiers.md`.

Details: [CLAUDE_LONG.md § Model tier rule](CLAUDE_LONG.md).

---

## Documentation map rule

**SYSTEM-MAP и USER-MAP MUST содержать Mermaid-диаграмму.** Замена на ASCII art или plain text запрещена — в больших проектах только Mermaid обеспечивает читаемый обзор.

**Гибридный язык (EN + RU):**
- Технические термины, имена файлов/команд — EN: `commands/`, `triggers.json`, `/plan → /code`
- Описания поведения, аннотации, метки на русском: `"анализ накопленного"`, `"единственный источник правды"`
- Пример корректного node: `Workflow["🔄 Workflow Cycle<br/>/plan → /code → /review → /deploy"]`

**Repo / setup контекст обязателен в USER-MAP.** Если проект использует внешний methodology-repo или infrastructure-repo — добавить `subgraph` или аннотацию, показывающую откуда берутся команды/шаблоны. Без этого новый разработчик не поймёт структуру.

`/review` блокирует merge если: (1) SYSTEM-MAP или USER-MAP изменены и Mermaid удалён; (2) новый разработчик не сможет понять repo-структуру из диаграммы.

---

## DEVLOG теги

`[fix:component]` `[feat:command]` `[feat:template]` `[feat:hook]` `[feat:script]` `[methodology]` `[process:X]` `[milestone]`

Phase-теги: `[phase-a]` … `[phase-g2]` — milestone history.

Команды методологии: `[architecture-audit]` `[sync-vision]` `[retro]` `[diagnose]` `[product-vision]` `[product-review]` `[product-check]`

**Semantic tagging rule (D6):** Проблемы categorize семантически, не по surface name. 

Одна проблема — один semantic indicator, даже если люди называют по-разному:
- `[git-failure]` — не `[git_push-failed]` ИЛИ `[github-error]` ИЛИ `[branch-push-issue]` (все sync failures)
- `[async-failure:operation]` — не `[vault-sync-error]` И `[queue-dropped]` (оба fire-and-forget failures)
- `[state-pollution]` — не `[history-leak]` И `[cache-contamination]` (оба внутренние состояния)

**Reason:** Regex-based detection fails когда люди называют одно разными именами. Semantic category stays stable.

---

## Security: real threats

**Утечка GitHub PAT (High):** Единственный токен с риском. Локально владельца, не в репо.

**Прямой push в main (High):** Branch protection не настроен. Будущая задача — required PR + review.

**Drift между методологией и консьюмерами (Med):** Sync ручной. Будущая задача — auto version-drift check в `/plan` Шаг -3.

**Sync overwrites local fills (Low):** `docs_reminder.py` LIBS заполняется per-project. Будущая задача — поддержка `*.local.py` соседних файлов.

Details with mitigation scenarios: [CLAUDE_LONG.md § Security threats](CLAUDE_LONG.md).

---

## Key files

- [scripts/new-project-init.sh](scripts/new-project-init.sh) — bootstrap
- [scripts/sync-methodology.sh](scripts/sync-methodology.sh) — sync
- [scripts/migrate-claude-md.sh](scripts/migrate-claude-md.sh) — Phase G2 split migration helper
- [commands/plan.md](commands/plan.md) — workflow entry point
- [templates/triggers.json.template](templates/triggers.json.template) — canonical state schema
- [templates/model-tiers.md](templates/model-tiers.md) — model recommendation registry
- [VERSION](VERSION) — semver

---

## External links

- GitHub: https://github.com/cait-solutions/it-dev-methodology
- Примеры консьюмер-проектов:
  - **Single-developer project** (e.g., solo-dev consumer) — single-tier vision
  - **Multi-service platform** (e.g., team-based consumer) — multi-tier vision, per-service триггеры, inbox, ADR
