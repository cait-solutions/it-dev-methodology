# CLAUDE.md — methodology-platform

Обязательные правила для AI-агентов работающих в этом репозитории.

> **Project type:** `methodology-platform` — особый тип. Это **продукт** методологии для других проектов. Большинство runtime-проверок (state pollution, deploy smoke tests) неприменимы. Применимы: контракты команд, валидность скриптов, кросс-ссылки артефактов.

---

## Обязательно перед началом работы

1. Прочитай [VISION.md](VISION.md) перед каждым `/plan`.
2. Прочитай [PRODUCT.md](PRODUCT.md) чтобы понять что методология обещает консьюмерам.
3. Прочитай [SYSTEM-MAP.md](docs/architecture/SYSTEM-MAP.md) — связи между компонентами методологии.

---

## Архитектура

Методология состоит из 5 слоёв:

| Слой | Где живёт | Кто меняет |
|---|---|---|
| **Команды** (slash commands) | [commands/](commands/) | Только владелец методологии |
| **Шаблоны артефактов** | [templates/](templates/) | Только владелец методологии |
| **Хуки защиты** | [hooks/](hooks/) | Только владелец методологии |
| **Скелеты агентов** | [agents/](agents/) | Только владелец методологии |
| **Скрипты доставки** | [scripts/](scripts/) | Только владелец методологии |

Консьюмеры (другие проекты cait.solutions) получают банер-prefixed копии через `scripts/sync-methodology.sh`. Они **не редактируют** доставленные файлы — только PR в этот репо.

См. [SYSTEM-MAP.md](docs/architecture/SYSTEM-MAP.md) для полной диаграммы.

---

## Стек

- **Скрипты:** Bash 3.2+ (Git Bash на Windows совместим)
- **Хуки:** Python 3 (CPython 3.10+ — type hints с `dict[str, str]`)
- **Шаблоны:** Markdown + YAML frontmatter (agents) + JSON (settings, triggers)
- **CI/CD:** ручной push в GitHub; нет автоматических деплоев (методология версионируется через VERSION + git tag)
- **Деплой:** `git push origin main`; консьюмеры подтягивают через `sync-methodology.sh`

---

## Карта данных

В отличие от обычных проектов, методология не имеет runtime БД. "Хранилища" — это слои репо.

| Слой | Что хранит | Источник правды | Кто пишет | Кто читает | Инвалидация |
|---|---|---|---|---|---|
| `commands/*.md` | Slash-команды (канон) | да | владелец методологии | bootstrap, sync, `/review` в консьюмерах | при правке + push |
| `templates/*.md` | Шаблоны артефактов | да | владелец | bootstrap | при правке + push |
| `hooks/*.py` | Универсальные защитные хуки | да | владелец | bootstrap + sync | при правке + push |
| `agents/*.template.md` | Скелеты sub-agents | да | владелец | bootstrap (только для новых проектов) | редко — body per-project |
| `VERSION` | Semver методологии | да | владелец | оба скрипта (для баннера и `.version` пойнтера) | при ручном bump |
| `.claude/` (этот репо) | Self-application копия | нет (производное) | `new-project-init.sh` | Claude Code | при `sync-methodology.sh .` |
| Консьюмер `.claude/commands/*.md` | Баннер-prefixed копия | нет (производное) | `sync-methodology.sh` | Claude Code в консьюмере | при следующем sync |

**Инварианты:**
- `commands/`, `templates/`, `hooks/`, `agents/` — единственный источник правды. `.claude/` (и любая копия в консьюмере) — производное.
- Перед коммитом правок в `.claude/commands/*.md` — отверни: исходник в `commands/*.md`. Никогда не оставляй расхождение.
- Любая правка в синхронизируемом артефакте → bump VERSION (минорный для additive, мажорный для breaking).

---

## Сила регуляторов поведения (Level-4 framework)

Применимо при добавлении новых команд, правил, или хуков.

1. **Правило в командном тексте** — слабо, дрейфует.
2. **Description инструмента / агента** — учитывается слабо.
3. **Few-shot примеры в команде** — средне, дрейфуют.
4. **Структура шаблона** (что физически попадает в проект через bootstrap) — сильно.
5. **Отсутствие альтернативы** (одна команда для задачи, нет дубля) — очень сильно.
6. **Schema constraint** (валидация в скрипте, banner-check в sync) — гарантия.

**Правило:** при добавлении правила в методологию — спросить "есть ли level-4+ структурный фикс?". Если есть — он primary. Правило — secondary документация.

Пример: defensive `triggers.json` чтение в командах = level-1 (требует дисциплины при каждой правке). Level-4 — единая схема в `templates/triggers.json.template` + валидация структуры в `/plan` Шаг -3. Если бы валидация была — defensive код в каждой команде стал бы ненужным.

---

## Don'ts (что НЕЛЬЗЯ)

- ❌ **Не редактировать `.claude/commands/*.md` напрямую** — это банер-prefixed копии. Канон в `commands/`. Правки делаются там.
- ❌ **Не удалять команды без миграции** — консьюмеры синкаются и потеряют функционал. Удаление = breaking change → мажор bump VERSION.
- ❌ **Не ломать `{{Project Name}}` плейсхолдер** в шаблонах. `sed`-подстановка простая, экзотика типа `\1` в RHS сломает её.
- ❌ **Не использовать bash 4-features** (`${var,,}`, associative arrays) — Git Bash на Windows ставит 3.2. Используй `tr` и indexed arrays.
- ❌ **Не коммитить `.claude/settings.local.json`** — у каждого dev свой. См. `.gitignore`.
- ❌ **Не дублировать контент между шаблонами** — если правило живёт и в `CLAUDE.template.md` и в `PRODUCT.template.md`, при изменении методологии оба разойдутся.

---

## Реализация через /code

После `/plan` — реализация через `/code`. Прямая правка нетривиальных изменений запрещена (новая команда, новый шаблон, изменение скрипта, изменение схемы `triggers.json`).

Мелкие правки (опечатки, пример в шаблоне) — можно без `/plan`, но запись в DEVLOG обязательна.

---

## Deploy rule

"Деплой" методологии = `git push origin main`. Перед каждым push:

1. Запустить `/review` если не запускался в этой сессии.
2. Обновить [DEVLOG.md](DEVLOG.md) с тегом `[deploy]` / `[feat:X]` / `[fix:X]` / `[methodology]`.
3. Если изменены команды / шаблоны / хуки — bump VERSION (минорный для additive, мажорный для breaking).
4. Если поменялась схема `triggers.json.template` — это **breaking**: мажор bump + миграционная инструкция в DEVLOG.

После push: консьюмер-проекты прогоняют `sync-methodology.sh` для получения обновлений. Это не автоматизировано — преднамеренно (контроль владельца проекта).

---

## Architecture decision rule

Перед изменением которое затрагивает контракт методологии (новая команда, новая обязательная секция в шаблоне, изменение схемы `triggers.json`):

1. Запустить `architect` sub-agent (`.claude/agents/architect.md`).
2. Дай свою рекомендацию ПЕРЕД запуском — independent review, не подтверждение.
3. Финальное решение — владелец методологии.

---

## Fix rule

Перед фиксом:

- **Симптом или причина?** Сломалась одна команда на одном проекте → симптом. Шаблон не сгенерил часть структуры → причина в шаблоне или скрипте.
- **Локальный или системный?** Опечатка в одном шаблоне → локальный. Banner injection ломает `.py` файлы → системный, фикси в скрипте, не в каждом хуке.

⛔ Локальный без обоснования — красный флаг.

---

## DEVLOG теги

См. [DEVLOG.md](DEVLOG.md). Релевантные для методологии:

- `[feat:command]` — добавлена/изменена slash-команда
- `[feat:template]` — добавлен/изменён шаблон
- `[feat:hook]` — добавлен/изменён хук
- `[feat:script]` — изменения в bootstrap / sync
- `[methodology]` — изменения в архитектуре методологии
- `[phase-a]` … `[phase-f]` — milestone-теги истории разработки

---

## Реальные угрозы для методологии

При планировании `[security]` / `[infra]` задач:

**Утечка GitHub PAT:**
- GitHub PAT с правами write на этот репо — единственный токен с риском. Хранится локально владельца, не в репо.

**Прямой push в main:**
- Текущая модель: branch protection не настроен. Любой с write-доступом может сломать main.
- **Мера:** будущая задача (R-01 в RISKS) — настроить branch protection с required PR.

**Drift между методологией и консьюмерами:**
- Консьюмер прогнал sync 3 месяца назад, методология ушла вперёд → консьюмер работает по устаревшей версии.
- **Мера:** `.claude/.version` в консьюмере; будущая задача — добавить version check в `/plan` Шаг -3.

**Sync overwrites local fills:**
- `docs_reminder.py` LIBS dict заполняется per-project. Sync затирает.
- **Мера:** документировано в шаблоне; будущая задача — поддержать `*.local.py` соседние файлы.

---

## Ключевые файлы / точки входа

- [scripts/new-project-init.sh](scripts/new-project-init.sh) — bootstrap нового проекта
- [scripts/sync-methodology.sh](scripts/sync-methodology.sh) — обновление существующего проекта
- [commands/plan.md](commands/plan.md) — entry point всего workflow для консьюмеров
- [templates/triggers.json.template](templates/triggers.json.template) — каноническая схема state
- [VERSION](VERSION) — semver методологии

---

## Внешние ссылки

- GitHub: https://github.com/cait-solutions/it-dev-methodology
- Консьюмер-проекты:
  - **PAI** (single-developer, Telegram bot) — single-tier vision, без architecture-audit
  - **ERP — nexchance** (multi-service B2B platform) — multi-tier vision, per-service триггеры, inbox, ADR
