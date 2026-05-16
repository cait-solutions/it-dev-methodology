# DEVLOG — methodology-platform

Хронологический журнал значимых событий: принятые решения, изменения курса, фиксы, milestones. Новые записи — сверху.

> **Назначение:** новый разработчик читает этот файл и понимает эволюцию проекта, решения и их причины. Дополняет ADR контекстом "почему именно сейчас".

---

## Когда писать

- **После каждого деплоя** — обязательно (через `/deploy` Шаг 2).
- Принято архитектурное решение.
- Обнаружена критическая проблема или регрессия.
- Завершён крупный milestone.
- Запущен `/architecture-audit`, `/sync-vision` или `/retro` — записать итог.

---

## Формат записи

```
## YYYY-MM-DD — <Короткое описание> [<тег>]

**Что:** одна строка — что изменилось
**Почему:** одна строка — мотивация / контекст
**Решение:** одна строка — если архитектурное (опционально)
**Карта данных:** изменилась / не изменилась (явно — не пропускать)
**Связано:** [ADR-NNN], [RISKS.md R-NN], [OQ-NNN], [план YYYY-MM-DD]
```

Правила:
- **Карта данных** заполняется всегда явно — даже если "не изменилась". Это форсирует подумать про схему/инвалидацию.
- **Связано** — ссылки на ADR / RISKS / OPEN-QUESTIONS / план / sync-vision report.
- Записи идут от новых к старым.

---

## Таксономия тегов

### Базовые

| Тег | Когда использовать |
|---|---|
| `[fix:<component>]` | исправление бага |
| `[feat:<component>]` | новая функциональность |
| `[process:<X>]` | изменение процесса разработки / методологии |
| `[infra:<component>]` | серверная конфигурация, деплой, CI/CD |
| `[security:<component>]` | защита от угроз, hardening |
| `[ops:<X>]` | операционные задачи (миграция, бэкап, чистка) |
| `[milestone]` | крупный этап проекта |
| `[regression:<X>]` | обнаружена регрессия после фикса |
| `[missed-signal]` | сигнал был пропущен и зафиксирован задним числом |
| `[methodology]` | изменения в методологических артефактах |

### Результаты методологических команд

| Тег | Когда |
|---|---|
| `[architecture-audit]` | итог `/architecture-audit` |
| `[sync-vision]` | итог `/sync-vision` |
| `[retro]` | итог `/retro` |
| `[diagnose]` | итог `/diagnose` |
| `[methodology-override]` | локальная правка `.claude/commands/*` без PR в методологию (требует PR в 48h) |

### Стратегические оси (из VISION.md)

Каждая активная ось из `VISION.md` имеет свой `feat:<axis-tag>`. Используется чтобы в `/retro` посчитать долю работы на каждую ось.

Пример: `[feat:knowledge-axis]`, `[feat:multi-context]`, `[feat:proactivity]`.

---

## Пример записи

```
## 2026-05-16 — Fix: повторные пустые ответы Gemini при overflow истории [fix:history-overflow]

**Что:** в `_build_gemini_history()` добавлен cap 2000 символов на каждое сообщение при передаче в Gemini; в `respond()` — `empty_streak`, после 2+ пустых ответов бот предлагает `/reset`.
**Почему:** большой текст пользователя сохранялся без ограничений → попадал в историю при следующих запросах → Gemini возвращал пустой ответ. `TOOL_RESPONSE_MAX_CHARS` защищал только tool responses, не сообщения пользователя — gap.
**Решение:** level-4 structural cap в `_build_gemini_history` — автоматически ограничивает все пути.
**Карта данных:** не изменилась.
**Связано:** [HYPOTHESES.md 2026-05-16], [план 2026-05-16-history-overflow]
```

---

<!-- Записи ниже, новые — сверху -->

## 2026-05-16 — Phase G1: navigation maps + model recommendation tiers [phase-g1][feat:command][methodology]

**Что:** Реализован Phase G1 через формальный `/plan` → `/code` → `/review` → `/deploy` процесс. 7 атомарных коммитов:
1. Создан `templates/model-tiers.md` — центральный реестр (4 tier-абстракции, per-command матрица, mid-task escalation + pre-flight model check протоколы).
2. Секция "Рекомендуемая модель" (5 полей) добавлена во все 12 команд (grep -L подтверждает 0 пропусков).
3. `/plan` Шаг 3 output расширен блоком "Recommended models"; в Шаге -3.2 каждый trigger-вопрос теперь включает рекомендуемую модель.
4. Шаг "Complexity reassessment" добавлен в `/code` (1.5), `/review` (3.5), `/diagnose` (2.5) — обязательная остановка при превышении плановой оценки.
5. Навигационные карты добавлены в `/review` (6 осей × 18 проверок), `/deploy` (6 project-types × 12 шагов), `/onboard` (2 режима × 13 шагов).
6. Скрипты `new-project-init.sh` и `sync-methodology.sh` копируют `model-tiers.md` → `.claude/model-tiers.md` с банером. Тестировано end-to-end.
7. VERSION bump v2.4.0 → v2.5.0 (minor, additive). CLAUDE.md получил "Model tier rule" (правило обязательной секции для новых команд). PRODUCT.md — колонка Default tier в таблице команд.

**Почему:** Cost-optimization для разработки + предсказуемое качество выполнения команд. Раньше: developer выбирал модель по интуиции (или дефолту Sonnet) — overpay на простых задачах (Sonnet вместо Haiku) и underdeliver на сложных (Sonnet вместо Opus). Теперь: каждая команда даёт явную рекомендацию tier, и при mismatch ≥ 2 ступени — пауза перед стартом. Mid-task triggers ловят случай когда реальность сложнее плановой оценки.

**Решение:** Tier-абстракция (Fast/Default/Extended/Capable) вместо хардкода имён моделей — single source of truth в `model-tiers.md` секция Mapping. Когда Anthropic выпустит новую модель — правка одной таблицы.

**Scope extension:** В commit 2 добавлено поле "Pre-flight model check" (5-е поле в секции) — было добавлено по запросу владельца mid-execution beyond original plan. Зафиксировано как добавление scope в commit message commit 2.

**Карта данных:** добавлен новый канонический артефакт `templates/model-tiers.md` (производное в консьюмере — `.claude/model-tiers.md` с банером). Per-command матрица — единственный источник правды для tier-рекомендаций; команды ссылаются на путь `.claude/model-tiers.md` (relative to consumer root).

**Связано:** [VISION v2 — нет прямого upgrade оси, но Cost-awareness стал implicit Quality bar], [Phase G2 — следующий план: CLAUDE.md split + Agent TL;DR convention]

---

## 2026-05-16 — VISION v2: первый формальный /product-vision [product-vision][feat:stack-agnostic][feat:dog-fooding][methodology]

**Что:** Запущен формально `/product-vision` (первый раз через slash-команду, не как ручной анализ). Применил 5-вопросный фильтр + anti-anchoring expansion к заявленным целям владельца методологии. Результат: VISION.md v1 → v2 с 4 активными осями вместо 3 (➕ Stack-agnostic adoption), Quality bar расширен с 1 до 6 пунктов (➕ regression prevention, security awareness, edge case detection, closed product feedback loop), стратегические границы 4 → 6 (➕ "только владелец контролирует канон", "не плагин-система — монолит с флагами"). Введён раздел Watch list для отложенных кандидатов на оси (engineering analytics, multi-tool support, cross-project knowledge propagation) с явными триггерами активации. `triggers.json.global.last_product_vision.date` сброшен в 2026-05-16, `plans_since` = 0.

**Почему:** После Phase F появилась возможность реально применить методологию к самой себе. Запуск `/product-vision` через настоящий slash-механизм Claude Code (не ручной анализ) — это первая dog-food итерация по оси 4 VISION. Цели владельца методологии (anti-regression, security, edge cases, cross-stack применимость, контроль) после фильтра распределились между: ось 2 (cross-stack стало явной осью stack-agnostic adoption), Quality bar (regression / security / edge cases) и стратегические границы (контроль владельца).

**Решение:** Сделано через `/product-vision` шаги -0.5 (anti-anchoring) → -1 (calibration) → 1 (axes) → 2 (decomposition top-2) → 3 (value hypotheses) → 4 (ranking) → 5 (anti-roadmap). Top-2 для ROADMAP: self-managing methodology (Phase 1 → 2 transition, reminder lifecycle, drift detection) и stack-agnostic adoption (starter rules catalog, `--starter-rules` флаг). Watch list получил конкретные триггеры активации (например engineering analytics — после 3+ месяцев `triggers.json` data и 30+ DEVLOG entries у консьюмеров).

**Карта данных:** не изменилась. `.claude/state/triggers.json` обновлён (поле `last_product_vision` — это его нормальное использование, не схема).

**Связано:** [VISION.md v2], [commands/product-vision.md], [triggers.json], [Phase F dog-fooding axis]

---

## 2026-05-16 — Phase F: Self-application — методология применена к себе [phase-f][milestone][methodology]

**Что:** Запустил `bash scripts/new-project-init.sh methodology-platform . --with-adr` на самом репозитории методологии. Создались `.claude/{commands,agents,hooks,state,settings.json,.version}`, ADR-структура в `docs/adr/`. Авторил реальный контент для CLAUDE.md / PRODUCT.md / VISION.md / SYSTEM-MAP.md (вместо template-плейсхолдеров). DEVLOG получил историю phase A-F. VERSION bumped до v2.4.0.
**Почему:** Финал roadmap из Phase A — eat your own dog food. Любые дальнейшие изменения методологии пойдут через её собственный `/plan` → `/code` → `/review` → `/deploy`. Если процесс плохо работает на этом репо — значит плохо работает у консьюмеров. Прямая обратная связь.
**Решение:** Bootstrap идемпотентен — повторный запуск ничего не сломает. CLAUDE.md теперь содержит `project_type: methodology-platform` (особый, не из enum) с явным указанием что runtime-проверки неприменимы.
**Карта данных:** не изменилась (методология не имеет runtime БД; `.claude/` — производное от `commands/`, `templates/`, `hooks/`, `agents/`).
**Связано:** [VISION.md ось 3 — dog-fooding], [PRODUCT.md], [CLAUDE.md]

---

## 2026-05-16 — Phase E: hooks + agents + rules + settings [phase-e][feat:hook][feat:script][methodology]

**Что:** Добавлены 3 универсальных хука (`bash_protect.py`, `protect.py`, `docs_reminder.template.py`), 3 скелета суб-агентов (`architect`, `qa`, `security`) в Claude Code YAML-frontmatter формате, гид по правилам в `rules/README.md` + `rules/_TEMPLATE.md`, `templates/settings.template.json` с wiring всех 3 хуков и safe git denies. Скрипты получили `inject_py_banner()`; bootstrap копирует `.template.py` со stripped suffix; sync овверайтит хуки с Python-баннером, preserves agents и settings.json.
**Почему:** Хуки — универсальная защитная инфраструктура (`rm -rf`, secrets edit). Раньше были только в PAI; теперь любой консьюмер получает их при bootstrap. Sub-agents — скелеты для запуска через `Architecture decision rule` в CLAUDE.md.
**Решение:** Level-4 регулятор — хуки на уровне Claude Code (PreToolUse exit 2). Запрещают опасные команды без участия разработчика. Settings.json — copy-if-missing (project-owned после bootstrap), хуки переписываются через sync.
**Карта данных:** добавлены `.claude/hooks/`, `.claude/agents/`, `.claude/settings.json` в схему производных от методологии.
**Связано:** [commit 11e8b9c]

---

## 2026-05-16 — Phase D: tier-2 опциональные шаблоны + флаги bootstrap [phase-d][feat:template][feat:script]

**Что:** 11 опциональных шаблонов — `vision/AGENT_VISION.template.md` + `vision/LONG_VISION.template.md` (двухуровневая ERP-стиль), `adr/_TEMPLATE.md` + `adr/README.template.md`, `data-map.template.md`, `glossary.template.md`, `BEHAVIOR.template.md`, `threat-model.template.md`, `SKILL.template.md`, `services-registry.template.yaml`, `inbox/README.template.md`. Bootstrap-скрипт получил флаги: `--multi-service`, `--with-adr`, `--with-inbox`, `--with-data-map`, `--with-glossary`, `--with-behavior`, `--with-threat-model`, `--all-optional`.
**Почему:** Single-developer проекты (PAI) и multi-service платформы (ERP) имеют разные потребности. Раньше — копировали всё или ничего; теперь — селективный bootstrap.
**Решение:** `--multi-service` структурно меняет layout (заменяет VISION.md на `docs/vision/AGENT_VISION + LONG_VISION_v1` + `services-registry.yaml`), остальные флаги — additive (создают файлы в `docs/`).
**Карта данных:** не изменилась.
**Связано:** [commit 309608b]

---

## 2026-05-16 — Phase C: переписаны CLAUDE / PRODUCT / VISION / SYSTEM-MAP шаблоны [phase-c][feat:template]

**Что:** Замена плейсхолдер-стабов на реальные шаблоны из живых проектов. `CLAUDE.template.md` 75 → 233 строки (project_type enum, карта данных, level-4 framework, security threats). `PRODUCT.template.md` 32 → 141 (команды/storage таблицы, Happy Path, поведение агента). `VISION.template.md` 34 → 116 (axes structure с obsolescence маркером, Quality bar, Стратегические границы). `SYSTEM-MAP.template.md` 47 → 120 (Mermaid scaffold с 5 subgraphs + легенда).
**Почему:** Phase A создавал шаблоны как заглушки. После анализа PAI + ERP стало ясно что должно быть в каждом — мы наполнили шаблоны живой структурой.
**Решение:** База — ERP, влияние PAI — level-4 framework, security threats, axes calibration filter.
**Карта данных:** не изменилась.
**Связано:** [commit fe54a8c]

---

## 2026-05-16 — Phase B: полные шаблоны для 6 операционных артефактов [phase-b][feat:template]

**Что:** Шаблоны для `DEVLOG.template.md`, `IDEAS.template.md`, `ROADMAP.template.md`, `OPEN-QUESTIONS.template.md`, `HYPOTHESES.template.md`, `RISKS.template.md`. База — ERP с вливаниями PAI. IDEAS — целиком PAI (7 типов сигналов). ROADMAP — PAI (Now/Next/Considered с подгруппами/On hold/Arch review/Rejected). OPEN-QUESTIONS — ERP с механизмом Reminder (time/metric/event-gated + Expires hard-block + M/N health metric). HYPOTHESES — гибрид (ERP forward-looking + PAI backward debug + missed-signal shorthand). RISKS — ERP формат с матрицей вероятность×влияние. Bootstrap теперь копирует все 6 из шаблонов вместо стабов.
**Почему:** Phase A создал inflastructure но артефакты были стабами. Без них команды (`/plan`, `/review`, `/deploy`) ссылались на пустые файлы.
**Решение:** Базовый формат ERP, специфичные паттерны PAI добавлены как опциональные секции.
**Карта данных:** не изменилась.
**Связано:** [commit 9d8a014]

---

## 2026-05-16 — Phase A: реальный bootstrap + sync + каноническая схема triggers [phase-a][feat:script][feat:template][milestone]

**Что:** Переименовал `commands/product.vision.md` → `product-vision.md` (Claude Code требует match имени и slash-команды). Добавил 6 новых команд из работы пользователя/линтера: `diagnose`, `onboard`, `product-check`, `product-review`, `product-vision`, `sync-vision`. Расширил 6 существующих команд с богатым контентом. Создал `templates/triggers.json.template` с ERP-канонической схемой. Написал `scripts/new-project-init.sh` (реальный бутстрап) и `scripts/sync-methodology.sh` (с баннер-детектом и orphan-deletion). README + .gitignore.
**Почему:** До Phase A репо имел определения команд но ни новый проект не мог их потребить, ни существующий не мог получить обновления. Phase A — критичная инфраструктура чтобы любой следующий шаг был возможен.
**Решение:** AUTO-GENERATED banner как контракт неизменяемости + два скрипта (bootstrap vs sync) — разные жизненные циклы. Sync детектит локальные правки через отсутствие баннера и спрашивает подтверждение.
**Карта данных:** установлена начальная — `commands/`/`templates/`/`hooks/` как канон, `.claude/` в консьюмерах как производное.
**Связано:** [commit b01cd04]

---

## 2026-05-16 — Initial methodology platform v2.3.1 [phase-init][milestone]

**Что:** Создан репозиторий `methodology-platform/` на GitHub `cait-solutions/it-dev-methodology`. Начальная структура: `commands/`, `agents/`, `rules/`, `templates/`, VERSION (v2.3.1).
**Почему:** До этого PAI и ERP имели свои собственные `.claude/commands/` с расхождениями. Цель — единый репо для канона методологии с read-only доступом для разработчиков и write-доступом только для владельца.
**Решение:** Подход Copy + Sync (Вариант 2) — банер в начале каждой синхронизированной команды + .version check. Локальные правки разрешены только как emergency override с обязательным PR в 48h.
**Карта данных:** не применимо — первый коммит.
**Связано:** [commit bb2c917], [GitHub repo cait-solutions/it-dev-methodology]

