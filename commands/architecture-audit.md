# /architecture-audit — Структурный аудит проекта

> **Цель:** структурный аудит **архитектуры проекта** — SYSTEM-MAP ↔ code drift, AGENT-GAPS pattern analysis (Level 4+ ladder), decommission candidates, cross-project aggregation. НЕ для methodology adoption (push-only delivery через `/push-consumers`), НЕ для тактических проблем (это `/retro`), НЕ для product gaps (это `/vision review`).

Универсальная команда структурного анализа. Применима к **любому проекту** (консьюмер или methodology-platform). Способности команды активируются автоматически по наличию артефактов в проекте:

| Способность | Активируется если | Применимо к |
|---|---|---|
| **A. SYSTEM-MAP ↔ code drift** | существует `docs/architecture/SYSTEM-MAP.md` | проекты с архитектурной картой |
| **B. Gap pattern analysis + Level 4+ ladder + decommission** | существует `AGENT-GAPS.md` И ≥ 3 записи (open + addressed). **Scope: только AGENT-GAPS** — agent's reasoning failures (methodology improvements). PRODUCT-GAPS обрабатывается через `/vision review`, не здесь. | проекты использующие AGENT-GAPS культуру |
| **C. Cross-project gap aggregation** | существует `consumers/*.yaml` registry с ≥ 1 ссылкой на склонированный проект имеющий `AGENT-GAPS.md` | methodology-platform или родительский проект с дочерними |
| **D. Diagram semantic review** | существует ≥ 1 living-карта с mermaid-блоком (`SYSTEM-MAP` / `USER-MAP` / `ARTIFACT-MAP` / `ROADMAP`) | любой проект с живыми картами (ADR-015) |

**Запускается:**
- `global.last_architecture_audit.plans_since` ≥ 5-10 (триггер из /plan)
- `agent_gaps_open_count` ≥ 10 (накопилось критическая масса — нужен структурный взгляд)
- Перед квартальным планированием
- После крупных архитектурных изменений
- ОБЯЗАТЕЛЬНО при добавлении нового сервиса/компонента
- Manual triggered (запрос пользователя)

**ЗАПРЕЩЕНО:** обновлять SYSTEM-MAP.md / AGENT-GAPS.md / commands / templates автоматически. Только анализ + рекомендации + PR-черновики. Human review required.

---

## Рекомендуемая модель

**Extended (UI settings):** effort: **High** · thinking: **ON** (Способность B/D — pattern analysis / semantic review) / **Medium** · thinking: **ON** (только Способность A — drift detection). См. `.claude/model-tiers.md` § Effort & Thinking.

**Default tier:** **Capable tier** обязателен **если активна Способность B** (gap pattern analysis требует Level 4+ ladder reasoning).
Если активна только Способность A (только drift detection) — Default tier достаточен.

**Tier matrix:**
| Активные способности | Минимальный tier | Обоснование |
|---|---|---|
| Только A | Default | Стандартный drift анализ |
| A + B (≥ 3 gaps) | **Capable** | Regulator ladder mapping требует deep reasoning |
| A + B + C | **Capable** обязательно | Cross-project pattern detection |
| D активна (semantic review) | **Capable** обязательно | Семантическое сравнение узлов/связей карт с реальностью — LLM-reasoning, не grep |

**Pre-flight model check:** **да** — спроси какая модель активна, сравни с минимальным tier из матрицы. Если ниже → ⛔ hard-block: «На текущей модели Способность B даст тактические рекомендации, не Level 4+. Переключись на Capable или запускай только Способность A.»

**Mid-task escalation:** нет (single-pass).

---

## Шаг 0 — Capability detection

Просканируй проект:

```
Detected capabilities:
- A (SYSTEM-MAP drift):  ✓ / ✗  (источник: docs/architecture/SYSTEM-MAP.md)
- B (gap analysis):      ✓ / ✗  (источник: AGENT-GAPS.md, N=записей)
- C (cross-project):     ✓ / ✗  (источник: consumers/*.yaml, N=consumers с GAPs)
- D (diagram semantic):  ✓ / ✗  (источник: living-карты с mermaid: N найдено)
```

Если **ни одна способность не активна** → ⛔ exit «нет данных для аудита; запусти когда появится хотя бы один из артефактов».

Если активна **только A** → дальше выполняется только Способность A (Шаги 1-4), пропускается всё остальное.

Способность D выполняется в **Шаге 3.5** (после drift-сравнения A, перед gap-анализом B) — независима от A/B/C, может быть единственной активной.

**Scope-граница (methodology adoption):**

> /architecture-audit это **архитектурный** audit — что **построено в проекте** vs design (SYSTEM-MAP drift, AGENT-GAPS pattern analysis).
> **Methodology adoption** (что методология доставила vs применено) — это push-only delivery: maintainer доставляет обновления через `/push-consumers`, а `scripts/sync-doctor.sh` даёт read-only healthcheck install'а. Консьюмеры не запускают adoption-команды сами.

---

## Шаг 1 — Inventory (Способность A: SYSTEM-MAP)

*Пропустить если Способность A не активна.*

1. Загрузить текущий граф из SYSTEM-MAP.md
2. Загрузить services-registry.yaml (или эквивалент) — active компоненты
3. Для каждого активного компонента inventory связей:
   - HTTP клиенты к другим компонентам
   - Event publishers (поиск по pattern conventions)
   - Event subscribers
   - External API integrations

---

## Шаг 2 — Построить граф из кода (Способность A)

Из inventory собрать реальный граф.

**Error handling:**
- Inaccessible repo → list "skipped (inaccessible)"
- Unparseable patterns → "investigation needed: path:line"
- Malformed registry → fail с clear error
- Always produce partial report — partial info > no report

---

## Шаг 3 — Drift comparison (Способность A)

- В карте, не в коде → **stale edge** (удалить?)
- В коде, не в карте → **undocumented edge** (добавить?)
- В карте active, не в registry → **phantom service**
- В registry active, не в карте → **missing service**

**⛔ Исключение: узлы класса `affordance` (closes P-002 false-drift).**

Узлы со стилем `classDef affordance` (навигационные/контекстные anchor'ы — например `📋 Отложенный scope → /scope-out`, Workflow-Cycle, Legend, repo-context) — это **не модельные компоненты системы**, а навигационные affordance: они говорят о месте карты в workflow, не утверждают что компонент существует в коде. По определению у них нет code-counterpart.

- При phantom/stale сравнении **исключай все узлы класса `affordance`** — у них нет и не должно быть кода. Флаг их как «phantom» = ложный позитив, который приучает владельца игнорировать вывод аудита.
- Это **class-правило, НЕ ID-whitelist**: не перечисляй конкретные node-ID (`scopeOutAnchor` и т.п.) — это slope (каждый новый affordance потребует своего литерала). Исключай **по классу** `affordance` — одно правило закрывает весь класс non-architectural узлов.
- Узел без `classDef affordance`, но фактически навигационный → это сигнал что карта нарушает конвенцию: рекомендовать пометить его `:::affordance` (см. CLAUDE.md Maps Standard §3), не молча игнорировать.

---

## Шаг 3.5 — Diagram semantic review (Способность D, ADR-015)

*Пропустить если Способность D не активна (нет living-карт с mermaid).*

> **Зачем отдельно от Шага 3:** Шаг 3 (drift) сравнивает **граф связей SYSTEM-MAP** с **кодом** — детерминированно-ish, привязан к code-counterpart. Шаг 3.5 проверяет **семантику узлов и labels ВСЕХ живых карт** (включая USER-MAP/ARTIFACT-MAP/ROADMAP, у которых нет code-графа) против реальности системы. Это LLM-review (presence ≠ semantics — grep сюда не достаёт), закрывает P-009 / BS-2 / BS-5. Регулятор L3 — не 100%-гарантия, periodic safety-net поверх per-PR couple (`/code`+`/review`, ADR-015 слой 1).

**Scope: ВСЕ living-карты с mermaid-блоком.** Для two-repo — в `doc_repo_path`. Набор: `SYSTEM-MAP.md`, `USER-MAP.md`, `ARTIFACT-MAP.md`, `ROADMAP.md` (+ любая другая living-карта с mermaid).

**Для каждой карты — прочитать mermaid-блок целиком и сверить три оси семантики с реальностью:**

1. **Узлы (существование):** каждый компонентный узел (НЕ класса `affordance`, НЕ deferred-кластер) — соответствует реально существующей сущности (файл / команда / сервис / артефакт)? Узел есть, сущности нет → **stale node** (удалена/переименована).
2. **Связи (направление + наличие):** каждая стрелка `A → B` — отражает реальное отношение (читает/пишет/вызывает/git)? Тип стрелки соответствует факту (`-.->` read vs `==>` write — не перепутаны)? Связь на карте есть, в реальности нет → **stale edge**; в реальности есть, на карте нет → **missing edge**.
3. **Описания (labels / node-format):** строка «Зачем» / «Без него» (CLAUDE.md §3) ещё описывает текущее назначение? Назначение компонента сменилось, label остался старым → **stale label**.

**Метод (честно — это LLM-review, не grep):**
- Для каждого узла — найти реальную сущность (Read файла / grep команды / проверка артефакта). Подтвердить или флагнуть.
- Для каждой связи — проверить что отношение существует в коде/контракте (grep вызова, чтение sync-loop, контракт чтения артефакта).
- ⛔ **Не выдумывать связи** (Constraints): флагать только то, что подтверждено чтением, не «кажется устаревшим».
- ⛔ Узлы класса `affordance` и deferred-кластер — **исключить** (как в Шаге 3): у них нет code-counterpart by design.

**Confidence на каждый флаг:** stale/missing с пометкой `confirmed` (прочитал, сущности точно нет / связь точно есть) vs `suspected` (выглядит устаревшим, нужна проверка владельцем). Только `confirmed` идут в структурные рекомендации; `suspected` — в секцию «требует решения PM».

**Вывод Способности D** (в отчёт Шага 10):
```
## 🗺 Diagram semantic review (Способность D)
Карт проверено: N (SYSTEM-MAP, USER-MAP, ARTIFACT-MAP, ROADMAP)

### <карта> — M узлов, K связей проверено
- 🔴 stale node: `NodeX` — сущность не найдена (confirmed: grep/Read пусто)
- 🟡 stale edge: `A -.-> B` — связь чтения не подтверждена в коде (suspected)
- 🟡 stale label: `NodeY` «Зачем: …» — назначение сменилось (см. file:line)
- ✅ остальное соответствует

### Сводка
- Карт чисто: X/N | с drift: Y/N | confirmed флагов: P | suspected: Q
```

**Если все карты чисты** → `## 🗺 Diagram semantic review: все N карт семантически актуальны — drift не найден.`

---

## Шаг 4 — Gap inventory (Способность B)

*Пропустить если Способность B не активна.*

1. Прочитать `AGENT-GAPS.md` — **все записи**, включая `addressed` и `wont-fix`
   - **Важно:** resolved gaps включаются. Паттерн "категория повторяется после фикса" = главный сигнал blind spot.
2. Для каждой записи извлечь: `Категория`, `Контекст`, `Гипотеза`, `Potential fix`, `Статус`, `Дата`
3. Сформировать список `local_gaps[]`

---

## Шаг 5 — Cross-project aggregation (Способность C)

*Пропустить если Способность C не активна.*

> **Версия v4.3.0:** инфраструктура подготовлена, тело — упрощённое. Активная агрегация раскрывается когда у консьюмеров появится `AGENT-GAPS.md` с реальными данными.

**⛔ Scope boundary:** агрегируются **только `AGENT-GAPS.md`** консьюмеров — AI failure modes и сигналы для методологии. `OPEN-QUESTIONS.md` консьюмера **НЕ агрегируется** — содержит продуктовые PM-решения бизнеса консьюмера (выбор стандартов, scope фич, domain defaults), которые методология не вправе судить и которые не являются AI failure modes. Если ты видишь `OPEN-QUESTIONS.md` в репо консьюмера — игнорируй его здесь; он корректно используется в `/retro` per-project hygiene, но не здесь.

1. Прочитать `consumers/*.yaml` registry
2. Для каждого consumer reference:
   - Существует ли `consumers/repos/<name>/AGENT-GAPS.md` локально?
   - Да → прочитать, добавить записи в `cross_project_gaps[]` с тегом `[consumer:<name>]`
   - Нет → отметить в отчёте «consumer N не имеет AGENT-GAPS — данных нет» (surfacing, не блок)
3. Объединить с `local_gaps[]` → итоговый `all_gaps[]`

**Если все консьюмеры пустые** → секция отчёта пометится `[TODO: активируется когда хотя бы 1 consumer имеет AGENT-GAPS]`, продолжать только с local_gaps.

---

## Шаг 6 — Pattern detection (Способность B + C)

*Из массива `all_gaps[]`.*

### 6.1 — Категорийная сводка

```
Категория          | Total | Open | Addressed | Wont-fix | Проектов | Distinct topics
context-gap        |   12  |   5  |     6     |    1     |    3     | ARTIFACT-MAP (8), CLAUDE.md (3), data-map (1)
completeness-gap   |    4  |   2  |     2     |    0     |    2     | edge cases (3), regressions (1)
...
```

### 6.2 — Cross-project flag

Категория встречается в **≥ 2 проектах** → 🌐 systemic across projects (приоритет на методологическое решение).

### 6.3 — Recurrence after fix (FMEA Detection logic)

Категория с **≥ 3 addressed** И **≥ 2 open** → ⚠️ critical blind spot: фиксы не работают структурно, паттерн возвращается.

**Recurrence rate (число, не интуиция):**
```
recurrence_rate = open / (open + addressed)
```
- **≥ 0.4** (40%+ всё ещё открыто после фиксов) → 🔴 фиксы не держат → Level 4+ **обязателен** (текущий regulator-level слишком слабый, паттерн пробивает его).
- **0.2–0.4** → 🟡 паттерн под контролем но не закрыт структурно → рассмотреть Level 4+.
- **< 0.2** → 🟢 фиксы работают, мониторинг.

Это самый сильный сигнал необходимости Level 4+ решения — аналог FMEA Detection: высокий recurrence = текущий detection/prevention не ловит класс до рецидива.

### 6.4 — Минимальные пороги

- Паттерн = категория с **N ≥ 3 записей**. Меньше — единичные случаи, идут в отчёт без эскалации.
- Если ни одного паттерна (все категории < 3) → секция «Patterns: none ≥ threshold. Продолжай мониторинг.»

---

## Шаг 7 — Regulator-Level mapping (Способность B, центральный шаг)

*Для каждого паттерна с N ≥ 3 — обязательно заполнить.*

| Паттерн | Текущий L (1-6) | Прошлые fix-попытки | Level 4+ альтернатива | Scope | Cost | Уверенность |
|---|---|---|---|---|---|---|
| `context-gap × 8 / ARTIFACT-MAP` 🌐⚠️ | L1-2 (prompt-rules) | G-001, G-004, G-005 | **L4:** расширить `validate-artifact-map.sh` — language + completeness check | methodology | низкая | высокая |
| `completeness-gap × 4 / edge cases` 🌐 | L1 (prompt в /code Шаг 4) | G-XXX | **L3:** добавить few-shot examples в /code Шаг 4; **L4:** не вижу schema-level решения | mixed (project + methodology) | средняя | средняя |
| ... | ... | ... | ... | ... | ... | ... |

**Жёсткое правило:** колонка «Level 4+ альтернатива» должна быть заполнена для каждой строки. Если альтернативы нет — явно записать **«L4+ невозможен, потому что [архитектурная причина]»** и оставить на L1-3.

**Scope определяет где fix:**
- `project` — fix в коде/правилах текущего проекта (schema constraint в БД, lint rule, тип, validation middleware, CLAUDE.local.md rule)
- `methodology` — fix в commands/templates методологии
- `mixed` — комбинированно

Если запущен в консьюмере и scope=methodology → отдельная секция отчёта «Сигнал в methodology-platform: эти паттерны системные, передай upstream».

---

## Шаг 8 — Decommission candidates (Способность B)

*Для каждого предлагаемого Level 4+ structural fix из Шага 7.*

Найти правила-предшественники в `commands/`, `templates/`, `CLAUDE.md`, `CLAUDE.local.md`, `.claude/rules/` которые становятся избыточны:

| Structural fix (Level 4+) | Замещает (кандидат на удаление) | Scope | Обоснование |
|---|---|---|---|
| `validate-artifact-map.sh` language check (L4) | `/code` Шаг 1 пункт "проверь язык labels" (L1, если будет добавлен) | methodology | Schema check работает всегда |
| ... | ... | ... | ... |

**Правило безопасности:** decommission **только если** новый fix:
- Работает на Level 4+ (структурно)
- Прошёл хотя бы 1 реальный цикл (был запущен в /code/PR без bypass)

Иначе → пометить «proposed, не decommission пока не валидирован».

---

## Шаг 9 — Self-evaluation (accountability)

Прочитать `last_architecture_audit.recommendations[]` из `triggers.json` (если поле существует).

```
Прошлый /architecture-audit (дата: X) выдал N рекомендаций:
- R-001 [drift]: <stale edge fix> — статус: implemented | rejected | pending
- R-002 [gap-structural]: <Level 4+ proposal> — статус: ...
- R-003 [decommission]: <rule to remove> — статус: ...

Implementation rate: M/N (X%)
- ≥ 80% → 🟢 здоровый цикл
- 30-80% → 🟡 нормально, отдельные рекомендации застряли
- < 30% → 🔴 выясни root cause прежде чем добавлять новые
```

⛔ Если прошлый аудит был и <30% реализовано — **сначала разобраться** почему предыдущие рекомендации не внедрены (нереалистичные? scope большой? приоритет?), а не добавлять новые.

---

## Шаг 10 — Отчёт (комбинированный, секции по способностям)

```markdown
# Architecture Audit Report — YYYY-MM-DD

## Detected capabilities
A: ✓/✗ | B: ✓/✗ | C: ✓/✗

## 🏗 SYSTEM-MAP drift (Способность A)
*Если активна*

### Stale edges (in map, not in code)
- source → target [type] — pattern not found in: path

### Undocumented edges (in code, not in map)
- source → target [type] — found in path:line

### Phantom / Missing services
- ...

### Summary
- Edges in map: X | Edges in code: Y | Drift: Z (W%)

## 🗺 Diagram semantic review (Способность D)
*Если активна — из Шага 3.5*

{per-карта stale node / stale edge / stale label с confirmed|suspected + сводка}

## 🔬 Gap pattern analysis (Способность B)
*Если активна*

### Категорийная сводка
{таблица из Шага 6.1}

### Critical patterns
- {pattern с 🌐 или ⚠️ — приоритет}

### Regulator-Level mapping
{таблица из Шага 7}

### Decommission candidates
{таблица из Шага 8}

## 🌐 Cross-project signals (Способность C)
*Если активна*

{из Шага 5/6.2 — паттерны через 2+ проекта}

ИЛИ: `[TODO: активируется когда консьюмеры наполнят AGENT-GAPS]`

## 📊 Self-evaluation
{из Шага 9}

## 🏛 Структурные предложения (Level 4+)
*Главная секция — что делать архитектурно*

### S-1: <название>
- Что: <изменение>
- Уровень регулятора: 4 | 5 | 6
- Scope: project | methodology | mixed
- Замещает: <список L1-3 правил из decommission>
- Cost: <оценка>
- PR draft: см. ниже
- **Confidence:** Root cause confirmed: __% (N recurring, M addressed) | L4+ feasible: __% | Scope accurate: __% | Overall: __%
- ⛔ Overall < 70% → status: `proposed-speculative` (не `proposed`)

### S-2: ...

## 🛠 Тактические наблюдения
*Локальные drift fix-ы, не требующие L4+ переосмысления*

- Stale edge X → закрыть в коммите Y
- ...

## 📦 PR drafts
*Опционально — если PM явно подтвердил готовность к diff*

### PR-1: <тема S-1>
**Files to change:** ...
**Estimated diff:** ...
**Validation plan:** ...

## ❓ Требует решения PM
*Каждый вопрос сопровождается рекомендацией и обоснованием.*
- [Вопрос]? → Рекомендация: [что] — [почему в одну строку]
- Прошлые рекомендации с <30% implementation — root cause?

<!-- POSITION: must be last section inside the report code block -->
## ➡️ Следующий шаг

**Для каждого структурного предложения** (`proposed` или `proposed-speculative`) — отдельный цикл:
```
/plan → /code → /review → /deploy
```

Список к обработке:
- S-1: <название> — `/plan` для реализации
- S-2: <название> — `/plan` для реализации
- *(если список пуст → audit завершён без action items; обновить `triggers.json.recommendations[].status`)*
- *(если все proposals отклонены → обновить `triggers.json.recommendations[].status = rejected`; следующий `/plan` обычный)*

⚠️ `/architecture-audit` **никогда** не merge сам — только анализ. Реализация — через циклы выше.
```

---

## Constraints

- No invented edges / no invented gaps — только что в SYSTEM-MAP / AGENT-GAPS / коде
- No architectural opinions без обоснования из данных
- Ambiguous patterns (dual HTTP+event) → report as inconsistency, not decision
- Resolved gaps включаются в pattern detection — паттерн живёт в исторических данных

---

## После завершения

1. Запись в DEVLOG:
   `[architecture-audit] Report YYYY-MM-DD: A=N drift, B=M patterns, C=K cross-project, D=R diagram-flags, structural=P, decommission=Q`
2. Обновить `triggers.json` (canonical path — closes дубль-ключи G-112b):
   - `global.last_architecture_audit = { "date": today, "plans_since": 0 }` (НЕ top-level)
   - `global.last_architecture_audit.recommendations = [...]` — массив для self-eval в следующем цикле:
     ```json
     [
       { "id": "R-NNN", "type": "drift" | "gap-structural" | "decommission",
         "summary": "...", "status": "proposed",
         "scope": "project" | "methodology" | "mixed",
         "implementation_pr": null }
     ]
     ```
3. Если найдены 🌐 или ⚠️ паттерны → предложить обновление RISKS.md (структурный риск повторения). Показать текст, не применять без подтверждения.

---

$ARGUMENTS
