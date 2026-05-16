# PRODUCT.md — methodology-platform

Единый источник правды о том как методология ведёт себя **с точки зрения консьюмера** — разработчика или команды которая использует её на своём проекте.

> Сверка с реальностью: `/product-check` каждые 5 планов или перед каждым push в main.

**Дата актуализации:** 2026-05-16
**Версия методологии:** см. [VERSION](VERSION)

---

## Agent TL;DR

- **Продукт одной фразой:** общая методология AI-assisted разработки для всех cait.solutions проектов — slash-команды, шаблоны артефактов, защитные хуки, bootstrap/sync скрипты, model tier system.
- **Основные точки входа:** 12 slash-команд (`/plan` → `/code` → `/review` → `/deploy` + `/retro`, `/architecture-audit`, `/sync-vision`, `/product-*`, `/diagnose`, `/onboard`) + 2 скрипта (`new-project-init.sh`, `sync-methodology.sh`).
- **Ключевые хранилища:** methodology repo = git source; consumers получают banner-prefixed копии через sync (commands/hooks); consumers владеют CLAUDE.md, PRODUCT.md, DEVLOG.md, etc. (project-specific content).
- **Главные инварианты доверия:** локальные правки команд запрещены — все изменения через PR в этот репо; sync не затирает project content; tier-абстракция моделей переживает ребренды Anthropic.
- **На что обратить внимание при `/plan [product]`:** новая slash-команда → добавь матрицу в `model-tiers.md` + секцию "Рекомендуемая модель" в command-файл (обязательно). Phase G2 ввёл split CLAUDE → CLAUDE_LONG convention.

---

## Философия

Методология даёт **общий рабочий процесс** для AI-assisted разработки на всех проектах cait.solutions. Один источник правды на slash-команды, шаблоны артефактов, и защитные хуки.

Главная идея: проект **не пишет** методологию — он её **потребляет**. Локальные правки запрещены; нужны изменения — PR в этот репо.

Методология развивалась из опыта как single-developer, так и multi-service проектов. Patterns из обоих подходов (хуки, IDEAS таксономия, ROADMAP структура, level-4 framework) влиты как универсальные дополнения.

---

## Целевые пользователи

| Роль | Задачи в системе | Ключевые боли которые продукт закрывает |
|---|---|---|
| **Solo developer** | Один человек ведёт проект через Claude Code; нужны guard-rails чтобы не дрейфовать с архитектурой | Дисциплина "записать в DEVLOG", "проверить риски", "не лечить симптом" — методология автоматизирует через slash-команды и счётчики |
| **Team lead на multi-service** | Координирует AI-агентов нескольких разработчиков; нужна общая methodology чтобы PR от агентов соответствовали стандартам | Per-service триггеры в `/architecture-audit`, `/sync-vision` для разрешения конфликтов между vision и кодом, `/retro` для анализа skip-rates |
| **Владелец методологии** (this repo) | Развивает методологию, реагирует на feedback из проектов | Единое место для канона; банер + sync механизм гарантирует распространение |

---

## Команды / точки входа

### Slash-команды (синхронизируются в `.claude/commands/` каждого проекта)

Колонка **Tier** показывает рекомендуемую модель по умолчанию (см. [model-tiers.md](.claude/model-tiers.md) для полной матрицы с условиями upgrade/downgrade).

| Команда | Default tier | Что делает |
|---|---|---|
| `/plan` | Default | Pre-flight checks (счётчики триггеров, stale OQ), 5-типовая классификация конфликтов источников (A-E), архитектурный анализ, план с рисками. Не пишет код. |
| `/code` | inherits from /plan | Реализация по подтверждённому плану. Self-review (Lite 2 точки / Full 6 точек), self-lint, опциональный `/review`. Mid-task complexity reassessment. |
| `/review` | one tier below /code | Архитектурное ревью без правок. Проверка повторных фиксов, регрессий, параллельных путей, контрактов, безопасности. 🔴/🟡/🔵 классификация. |
| `/deploy` | Fast | Pre-flight (hard blocker на повторный деплой за 24h), DEVLOG обновление, smoke test, after-effects check. |
| `/retro` | Default | Методологическая ретроспектива при `last_retro.plans_since` ≥ 15. Анализ skip-rates триггеров, повторяющихся проблем, M/N reminder health. |
| `/architecture-audit` | Default | Сверка SYSTEM-MAP с реальным кодом. Stale edges, undocumented edges, phantom services, missing services. |
| `/sync-vision` | Default | Двусторонняя сверка vision ↔ реальность. 5-типовая классификация (A/B/C/D/E). Отчёт в `docs/sync-vision-reports/`. |
| `/diagnose` | **Capable** | Глубокая диагностика проблемы. Обязательна перед вторым фиксом одного компонента за 7 дней. 3+ гипотезы перед действием. |
| `/onboard` | Default | Адаптация нового разработчика (2 часа) или передача legacy домена под AI (создание SKILL.md). |
| `/product-vision` | **Capable** | Стратегическая оптика. 5-вопросный фильтр калибровки оси. Раз в 1-2 квартала. |
| `/product-review` | Default | Анализ сигналов из IDEAS.md. 4 вопроса (friction/discovery/visibility/extensions). 5-7 предложений с привязкой к данным. |
| `/product-check` | Fast | Сверка PRODUCT.md с кодом. Каждые 5 планов или перед деплоем. |

При старте любой команды агент **обязан** выполнить Pre-flight model check: определить текущую модель и сравнить с Default tier для команды. Если mismatch ≥ 2 ступени — пауза + рекомендация. Cost-aware методология.

### Скрипты (для владельца проекта-консьюмера)

| Скрипт | Что делает |
|---|---|
| `scripts/new-project-init.sh <name> [target] [flags]` | Bootstrap нового проекта. Создаёт `.claude/{commands,agents,hooks,state,settings.json}`, копирует основные артефакты с подстановкой `{{Project Name}}`. Поддерживает 8 флагов (`--multi-service`, `--with-adr`, `--with-inbox`, ..., `--all-optional`). |
| `scripts/sync-methodology.sh <target>` | Обновление консьюмера до текущей методологии. Перезаписывает commands и hooks с банером; preserved agents и settings.json. Детектит локальные правки и спрашивает подтверждение. |

---

## Ключевые сценарии (Happy Path)

### Сценарий 1 & 2: Bootstrap — любого проекта (одна команда, v3.1.0+)

```
$ bash methodology-platform/scripts/new-project-init.sh my-app ~/projects/my-app
→ создаются .claude/{commands,agents,hooks,state}/ + settings.json + .version
→ создаются ВСЕ артефакты: CLAUDE.md, PRODUCT.md, VISION.md
→ создаются многоуровневые структуры: docs/vision/{AGENT_VISION,LONG_VISION_v1}.md
→ создаются docs/adr/, docs/data-map.md, inbox/, services-registry.yaml, и т.д.
→ git init если нет
```

**One methodology, one bootstrap.** Разница между solo-dev и multi-service — только в наполнении:

- **Solo-dev проект:** используешь VISION.md, игнорируешь docs/vision/ и services-registry.yaml (или удаляешь если не нужны)
- **Multi-service платформа:** заполняешь docs/vision/AGENT_VISION.md и LONG_VISION_v1.md, создаёшь services-registry.yaml

Дальше:
1. Заполнить CLAUDE.md (project_type, угрозы, карта данных).
2. Заполнить PRODUCT.md (команды, хранилища, поведение).
3. Для multi-service: заполнить docs/vision/ и services-registry.yaml; для solo-dev: заполнить VISION.md.
4. Открыть в Claude Code → `/plan` для первой фичи.

### Сценарий 3: Sync существующего проекта после обновления методологии

```
$ bash methodology-platform/scripts/sync-methodology.sh ~/projects/my-app
→ если в .claude/commands/*.md есть файлы без AUTO-GENERATED банера — спрашивает подтверждение
→ перезаписывает commands/ с банером, удаляет команды убранные апстримом
→ перезаписывает hooks/ с банером
→ сохраняет agents/ (per-project body)
→ не трогает settings.json (project-owned)
→ обновляет .claude/.version
```

### Сценарий 4: Разработчик хочет изменить slash-команду

⛔ **Локальные правки запрещены** — sync затрёт.

Правильный flow:
1. Открыть PR в `methodology-platform` репо.
2. Дождаться merge.
3. Прогнать `sync-methodology.sh` на проекте.

**Emergency override:** срочно — отредактировать локально, обязательно PR в течение 48 часов. Запись в DEVLOG с тегом `[methodology-override]`.

---

## Флоу обработки входящих

### Bootstrap (sync-команды + начальная структура)

- Скрипт читает методологию через `BASH_SOURCE` → знает где она лежит независимо от cwd.
- Шаблоны подставляют `{{Project Name}}` через `sed`.
- Hooks с расширением `.template.py` теряют `.template` при копировании (e.g. `docs_reminder.template.py` → `docs_reminder.py`).
- Idempotent: существующие файлы preserved (только `.claude/commands/` overwritten by sync).

### Sync (update существующего проекта)

- Детект банера через `head -1 | grep AUTO-GENERATED`.
- Команды/хуки без банера → warning + подтверждение оверрайта.
- Команды убранные из методологии → удаляются из консьюмера.
- Agent skeletons preserved (body per-project).
- settings.json preserved (project-owned после bootstrap).

### Workflow в консьюмере

`/plan` → `/code` → `/review` → `/deploy`. Триггеры через счётчики в `triggers.json` запускают `/architecture-audit`, `/sync-vision`, `/retro`, `/product-*` команды периодически.

---

## Хранилища данных (с точки зрения консьюмера)

Когда консьюмер использует методологию, он получает следующие "хранилища":

| Источник / действие | `.claude/` | Корень проекта | `docs/` (опционально) | Примечание |
|---|---|---|---|---|
| bootstrap | ✅ полный | ✅ CLAUDE/PRODUCT/VISION/DEVLOG/IDEAS/ROADMAP/HYPOTHESES/RISKS/OPEN-QUESTIONS | ✅ architecture/SYSTEM-MAP.md | + флаги добавляют data-map, glossary, BEHAVIOR, threat-model, vision/, adr/, inbox/ |
| sync | ✅ commands/hooks overwritten | ❌ не трогается | ❌ | agents preserved |
| `/plan` (в Claude Code) | ✅ читает state/triggers.json | ✅ читает все корневые артефакты | ✅ читает docs/ | пишет триггер-счётчики |
| `/code`, `/review`, `/deploy` | ✅ читает commands, hooks | ✅ пишет в DEVLOG | ✅ пишет в data-map если применимо | |

### Правила памяти

- Методология — **единый источник правды** для команд / шаблонов / хуков. Локальная правка → разойдётся через sync.
- Консьюмер **владеет** контентом артефактов (CLAUDE.md заполнен per-project, PRODUCT.md специфичен и т.д.).
- `triggers.json` — local state консьюмера, нигде не синхронизируется централизованно.

---

## Поведение системы

### Что bootstrap делает автоматически

- Создаёт всю структуру `.claude/`, копирует commands с банером.
- Подставляет `{{Project Name}}` в шаблонах.
- Создаёт `triggers.json` с дефолтными нулями.
- Создаёт `settings.json` с wiring 3 хуков.
- Инициализирует git если не было.

### Что sync делает автоматически

- Перезаписывает все `commands/*.md` (банер свежий каждый раз).
- Удаляет команды убранные из методологии.
- Перезаписывает все `hooks/*.py`.
- Обновляет `.claude/.version`.

### Что требует явного действия владельца

- **Локальная правка команды:** запрещена → PR в методологию.
- **Pre-flight check затрёта файлов:** sync спрашивает подтверждение если детектит правки без банера.
- **Bump VERSION:** только владелец методологии. Минорный для additive, мажорный для breaking.

---

## Доменные сущности

### Triggers — счётчики методологических процессов

Файл `.claude/state/triggers.json` в каждом консьюмере. Каноническая схема (см. `templates/triggers.json.template`):

- **`global`** — счётчики применяющиеся ко всему проекту (`last_sync_vision`, `last_retro`, `last_product_*`)
- **`per_service`** — счётчики по сервисам (для multi-service; в single-service пусто)
- **`queues`** — состояние inbox / OPEN-QUESTIONS
- **`skipped_warnings`** — сколько раз показали warning, пользователь проигнорировал
- **`last_plan_session`** — связь plan ↔ code (структурный enforcement через `code_run` флаг)
- **`last_deploy`** — для warning "давно не деплоили"

`/plan` инкрементит `*.plans_since`. Команды (`/retro`, `/architecture-audit`, ...) сбрасывают свой счётчик когда отрабатывают. При достижении порога `/plan` предлагает запуск.

### Banner — контракт неизменяемости

Каждый синхронизированный командный файл и хук начинается с:

```
<!-- AUTO-GENERATED from methodology-platform vX.Y.Z -->
<!-- Synced: YYYY-MM-DD -->
<!-- DO NOT EDIT — changes will be overwritten on next sync -->
<!-- Modify via PR to https://github.com/cait-solutions/it-dev-methodology -->
<!-- Emergency override: edit locally + open PR within 48h -->
```

Sync проверяет наличие банера. Отсутствие → файл считается локально правленым → warning перед оверрайтом.

---

## Ограничения и non-goals

**Что методология НЕ делает:**

- **Не управляет деплоем кода консьюмера.** `/deploy` — это лишь чек-лист и DEVLOG-формат. Реальный deploy — это `_update.py`, `kubectl apply`, или что-то другое в каждом проекте.
- **Не валидирует код.** Это работа линтеров и type checker'ов. Методология валидирует **процесс**: запустили ли `/review`, обновили ли DEVLOG, есть ли регрессионный тест.
- **Не синхронизирует state между проектами.** Каждый консьюмер имеет свой `triggers.json`.
- **Не автоматизирует sync.** Sync — ручной (преднамеренно). Консьюмер решает когда подтянуть обновления.
- **Не поддерживает плагин-систему.** Методология монолитна. Опциональные шаблоны — через флаги bootstrap, не через рантайм-плагины.

---

## Метрики успеха

| Метрика | Текущее значение | Целевое значение |
|---|---|---|
| Количество консьюмер-проектов | 2+ | 3+ к концу 2026 |
| Среднее расхождение версий между методологией и консьюмерами | n/a | < 1 minor bump |
| % консьюмеров имеющих single-source-of-truth (нет версионного дрейфа) | 100% (после Phase A-F) | 100% |
| Skip rate триггеров в `/retro` (среднее по консьюмерам) | n/a | < 30% после 3 месяцев работы |

---

## Связь с остальной документацией

- Архитектура и техническая реализация: [CLAUDE.md](CLAUDE.md) + [SYSTEM-MAP.md](docs/architecture/SYSTEM-MAP.md)
- Стратегические оси развития: [VISION.md](VISION.md)
- Дорожная карта реализации: [ROADMAP.md](ROADMAP.md)
- История изменений и решений: [DEVLOG.md](DEVLOG.md)
- Идеи для развития методологии: [IDEAS.md](IDEAS.md)
- Архитектурные решения: [docs/adr/](docs/adr/)
