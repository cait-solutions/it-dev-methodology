# /retro — Тактическая ретроспектива проекта

> **Цель:** гигиена проекта за период — skip rates, stale Open Questions, reminder health, продуктовый поток, повторяющиеся проблемы в DEVLOG, AGENT-GAPS / PRODUCT-GAPS signals. НЕ для архитектурных решений (это /architecture-audit) и НЕ для стратегии (это /vision strategy).

**Применимо к любому проекту** (консьюмер или methodology-platform).

**НЕ для:**
- Структурных архитектурных решений → `/architecture-audit`
- Pattern analysis AGENT-GAPS с Level 4+ ladder → `/architecture-audit`
- Decommission устаревших правил → `/architecture-audit`
- Стратегических осей продукта → `/vision strategy`

`/retro` **сигнализирует** когда нужен структурный взгляд (например `[fix:X] × 3` или ≥3 gaps одной категории) и **рекомендует** запуск `/architecture-audit`. Сам не делает.

Запускается при `last_retro.plans_since` ≥ 15 или вручную раз в 30 дней.

**ЗАПРЕЩЕНО:** менять команды / CLAUDE.md / triggers.json автоматически. Только анализ и рекомендации.

---

## Рекомендуемая модель

**Extended (UI settings):** effort: **High** · thinking: **ON** — ретроспективный анализ паттернов = reasoning. См. `.claude/model-tiers.md` § Effort & Thinking.

**Default tier:** Default tier (см. `.claude/model-tiers.md`) — тактический анализ.
**Upgrade to Capable tier if:** 60+ DEVLOG entries за период; множественные skip-rate alerts (≥3 триггеров с skip > 50%)
**Downgrade to Fast tier if:** < 10 DEVLOG entries за период (мало данных)
**Mid-task escalation:** нет (single-pass analysis)
**Pre-flight model check:** **да** — спроси какая модель активна или используй подтверждённую в сессии. При mismatch — пауза + рекомендация (порог и формат: `.claude/model-tiers.md § Pre-flight model check`; under-powered — любая ступень вниз).

---

## Шаг 1 — Загрузка данных

1. Прочитать `.claude/state/triggers.json`
   - Запустить `bash scripts/validate-triggers.sh` (если доступен) — нарушения (дубль-ключи global.X vs X) → показать до анализа
2. Прочитать DEVLOG.md (записи с `global.last_retro.date` или последние 30 дней)
3. Прочитать OPEN-QUESTIONS.md (если есть)
4. Прочитать HYPOTHESES.md (если есть)
5. Зафиксировать метрики:
   - Планов с прошлого retro
   - `skipped_warnings.*` — сколько warnings игнорировано
   - `agent_gaps_open_count` — для сигнала в Шаге 2а

**Decision-review skip-rate (Ось 1 data-driven hardening, opinion:mandatory-council 2026-06-20):** прочитать `skipped_warnings.opinion_skipped` (backward compat) + `decision_review` блок (defensive: `.get(...) or {}` — старые проекты до schema-бампа не имеют; graceful). Это число high-stakes планов, где агент пропустил `/opinion` decision-review (council 7/7, soft-триггер /plan Шаг -3).

**Метрики (split counters, closes framing-bias instrument, 2026-06-26):**
- `decision_review.opinion_skipped_single` — планы с одним high-stakes критерием, где opinion пропущен
- `decision_review.opinion_skipped_compound` — планы с ≥2 критериями (выше риск), где opinion пропущен
- `decision_review.opinion_ran_caught` — планы где council запущен и поймал реальный дефект
- `decision_review.opinion_ran_clean` — планы где council запущен, дефектов не найдено
- `decision_review.review_caught_after_skip` — планы где /review поймал проблему после opinion-skip

**Интерпретация:**
- `skipped_compound = 0-1` → 🟢 норма. `≥2` → 🟡 сигнал: compound-планы пропускают council систематически.
- `opinion_ran_caught ≥ 2` при `skipped_compound ≥ 3` → сигнал к рассмотрению hard-block для compound-tier (Ось 1: enforce по данным, не преждевременно).
- `review_caught_after_skip ≥ 2` → /review gate работает как backstop, но это дорогой сигнал (поздно в цикле).
- `opinion_ran_clean ≫ opinion_ran_caught` → low signal/noise — рассмотреть сужение compound-критерия (Complexity tax).
- Любой счётчик `0-1` → 🟢 норма (данных недостаточно для hardening-решения).
- ⛔ Без этих данных hardening был бы преждевременным (dead-rule риск, урок v4.7.1). Split counters — то измеримое, что разблокирует решение «твердеть или нет».
- ⛔ `decision_review` блок отсутствует → старый проект до sync; не ошибка, прочитать только `opinion_skipped`.

---

## Шаг 2 — Повторяющиеся проблемы в DEVLOG

⛔ Discipline-creating: «найди паттерны» = aspirational (агент пишет «паттернов нет» не считая). Сначала **посчитай**, потом интерпретируй.

**Обязательный frequency-замер (выполнить, показать вывод).** Путь к DEVLOG (closes G-076): single-repo → `DEVLOG.md` локально; two-repo → `<doc_repo_path>/DEVLOG.md` (из `CLAUDE.local.md ## Auto-update`). Ниже `<DEVLOG>` = этот путь:
```bash
# Частота fix-тегов за период:
grep -oE "\[fix:[a-z-]+\]" <DEVLOG> | sort | uniq -c | sort -rn | head
# Все semantic-теги failure-классов:
grep -oE "\[(fix|regression|async-failure|state-pollution):[a-z-]+\]" <DEVLOG> | sort | uniq -c | sort -rn
```

Из вывода построй таблицу (число — из grep, не из памяти):

| Тег | Кол-во за период | Сигнал |
|---|---|---|
| `[fix:X]` | N | ≥3 → 🔬 системный → /architecture-audit |

Затем интерпретируй:
- `[fix:X]` ≥ 3 → системная проблема (см. структурный сигнал ниже)
- Одни и те же модули в OQ? (grep компонент)
- Одни и те же типы конфликтов (Type C)?
- Семантические дубли — один баг под разными тегами (нарушение semantic tagging rule): подозрительно если 2+ тега описывают один симптом.

⛔ Таблица без выполненного grep (числа «на глаз») = Шаг 2 не зачтён.

### Структурный сигнал → /architecture-audit

Если найден паттерн `[fix:X] ≥ 3` за 7-30 дней:

```
🔬 Обнаружен структурный сигнал: [fix:X] встречается N раз за период.
   Это указывает на нерешённую коренную причину (Level 1-2 фиксы не работают).
   Рекомендация: запустить /architecture-audit — он сделает Level 4+ анализ
   и предложит структурное решение (schema constraint, validator, middleware).
```

`/retro` сам **не пытается** придумать Level 4+ фикс — это работа `/architecture-audit`.

---

## Шаг 2а — Gaps signal (lightweight, два класса)

Два namespace gap'ов — два signal раздельно. AGENT-GAPS = methodology signal, PRODUCT-GAPS = product roadmap signal.

### 2а.1 — AGENT-GAPS signal (methodology)

Прочитать `AGENT-GAPS.md` (если существует).

**Если файл отсутствует:**
```
⚠️ AGENT-GAPS.md не найден. Создайте: скопируйте templates/AGENT-GAPS.md.template
   или запустите sync-methodology.sh для шаблона. Пропускаю signal.
```

**Если файл существует:**

1. Посчитать total / open / addressed / wont-fix
2. Группировать open по `Категория` (prompt-gap / context-gap / assumption-gap / logic-gap / state-stale)
3. Сравнить с прошлым `/retro` — выросло / упало / стабильно?

Вывод (короткий, без анализа паттернов):

```
## AGENT-GAPS signal (methodology)
Total: N  | Open: K  | Addressed: M  | Wont-fix: L
Изменение с прошлого /retro: +ΔN (или = / -ΔN)

Топ-3 открытых категорий:
- context-gap × 3
- prompt-gap × 1
- ...
```

**Структурный сигнал → /architecture-audit:**
- `open + addressed` любой одной категории **≥ 3** → 🔬 «достаточно данных для pattern analysis, запусти /architecture-audit для Level 4+ ladder»
- `agent_gaps_open_count` **≥ 10** → 🔬 «накопилась критическая масса, /architecture-audit обязателен в ближайший /plan»

### 2а.2 — PRODUCT-GAPS signal (product roadmap)

Прочитать `PRODUCT-GAPS.md` (если существует).

**Если файл отсутствует:**
```
⚠️ PRODUCT-GAPS.md не найден. Если у тебя реальный продукт — создай из templates/PRODUCT-GAPS.md.template
   или запусти sync-methodology.sh. Пропускаю signal.
```

**Если файл существует:**

1. Посчитать total / open / in-roadmap / wont-fix / resolved
2. Группировать open по **Severity** (🔴 High / 🟡 Medium / 🟢 Low) + по **Категория** (feature/capability/ux/integration/edge-case)
3. Сравнить с прошлым `/retro` — выросло / упало?

Вывод:

```
## PRODUCT-GAPS signal (product roadmap)
Total: P  | Open: K  | In-roadmap: M  | Wont-fix: L  | Resolved: R

Severity distribution (open):
- 🔴 High × N
- 🟡 Medium × M
- 🟢 Low × K

Топ-3 категорий:
- feature-gap × X
- edge-case-gap × Y
- ux-gap × Z
```

**Структурный сигнал → /vision review:**
- 🔴 High **≥ 3** open → 🔬 «накопились High-severity gap'ы, запусти /vision review для приоритизации в ROADMAP»
- `product_gaps_open_count` **≥ 5** → 🔬 «product backlog растёт, /vision review для batch обработки»
- /vision review должен учитывать PRODUCT-GAPS вместе с IDEAS (IDEAS = raw signal, PRODUCT-GAPS = classified)

`/retro` **не анализирует** паттерны сам — это работа `/architecture-audit` Шаг 4-9.

---

## Шаг 3 — Статистика триггеров

| Триггер | Показов | Проигнорировано | Skip rate | Оценка |
|---|---|---|---|---|
| ... | ... | ... | X% | ... |

**Интерпретация:**
- Skip rate > 50% → 🟡 триггер шумный, повысить порог (тактика)
- Skip rate ≈ 0% + проблем не найдено → 🟡 триггер избыточный, рассмотреть удаление
- Trigger игнорирован > 3 раз но запущенный потом находил проблему → 🔴 систематическое откладывание, рассмотреть hard-block

---

## Шаг 4 — Анализ команд: Guardrail vs Frequency

**Guardrail-правила** (защищают от дорогих ошибок, срабатывают редко):
- Не удалять даже если не срабатывали — это deterrent.

**Frequency-правила** (должны срабатывать часто):
- Кандидаты на ВНИМАНИЕ: не применялись 60+ дней И ни одного случая когда были бы нужны.

> **NB:** систематический decommission устаревших правил (когда есть Level 4+ заменитель) — это работа `/architecture-audit` Шаг 8, не `/retro`. Здесь только сигналим о frequency-проблемных правилах.

---

## Шаг 4.5 — Methodology step audit (cut-not-add механизм)

**Цель:** выявить какие шаги команд (`/plan`, `/code`, `/review`, `/deploy`) за период реально находили проблемы vs молчали — для информированных решений о консолидации/удалении.

**Источники:** `.claude/commands/*.md` (структура шагов) + DEVLOG + AGENT-GAPS за период.

Для каждой из 4 команд — пройди её шаги и присвой каждому категорию за период:
- **HIT** — есть конкретное упоминание в DEVLOG/AGENT-GAPS/обсуждении что этот шаг поймал проблему (cite запись)
- **SILENT** — 0 упоминаний за период
- **AMBIGUOUS** — упоминание есть, но непонятно был ли причиной именно этот шаг

**Output — таблица:**
```
| Команда  | Шаг               | Status    | Cite / Note       |
|----------|-------------------|-----------|-------------------|
| /plan    | -1.3 Adjacent     | HIT       | G-014             |
| /plan    | 0.7 Source Conf.  | SILENT    | —                 |
| ...      | ...               | ...       | ...               |
```

**Кандидаты на действие:**
- SILENT ≥ 2 retro подряд → 🟡 `candidate-cut` (удалить или консолидировать в отдельном /plan)
- HIT ≥ 5 за период → 🟢 `high-value` (сохранить)
- AMBIGUOUS > 50% шагов команды → 🟡 спецификация туманная, уточнить

**Scope boundary:** audit сигналит, не действует. Удаление шагов — отдельный /plan с явным подтверждением человека. Структурный decommission (с Level 4+ заменителем) — работа `/architecture-audit`.

**Закрывает:** G-020 (methodology accretion без feedback loop'а о ценности шагов).

---

## Шаг 4.6 — Pre-Mortem calibration (VISION Ось 5)

**Цель:** калибровать шаблон Pre-Mortem (`/plan` Шаг 98, 7 категорий) на исторических промахах. Не «срабатывал ли шаг» (это 4.5), а «предвидел ли Pre-Mortem то что реально сломалось».

**Ограничение (honest):** предсказания Pre-Mortem не персистятся в файлы — они живут в conversation плана и теряются. Поэтому calibration работает **обратным ходом**: от реальных провалов в DEVLOG → к вопросу «должен ли был Pre-Mortem их поймать», а не от сохранённого предсказания → к проверке. Это даёт сигнал о слабых категориях шаблона без archival-механизма (anti-over-engineering).

**7 категорий Pre-Mortem** (из `/plan` Шаг 98, зеркало — менять синхронно): `Latency/Cost` · `Reuse` (раздражает при регулярном использовании) · `Edge-case в данных` · `Degradation` (внешний сервис недоступен) · `Docs` (непонятно через 3 месяца) · `Adjacent` (ломает смежную фичу / state pollution) · `Execution context` (Windows/cp1252, non-TTY hook, two-repo cwd, parallel-session lock, missing dependency — closes R-032, добавлен v5.41.0).

**Процедура:**
1. Собрать из DEVLOG за период все `[fix:X]`, `[regression:X]`, `[async-failure:X]`, `[state-pollution]` — реальные провалы _после_ деплоя.
2. Для каждого — отнести к одной из 7 категорий Pre-Mortem (или `вне-категорий` если это новый класс).
3. Классифицировать:
   - **PREDICTABLE** — провал из категории, которую Pre-Mortem ОБЯЗАН предвидеть, но (судя по тому что fix понадобился) не предотвратил → calibration miss.
   - **UNCATEGORIZED** — провал не ложится ни в одну из 7 категорий → кандидат на 8-ю категорию шаблона.
   - **GENUINELY-UNFORESEEABLE** — внешнее изменение которое нельзя было предвидеть (API провайдер сломал контракт без анонса) → не miss, не считать против шаблона.

**Output — таблица:**
```
| DEVLOG-запись      | Категория Pre-Mortem | Класс              |
|--------------------|----------------------|--------------------|
| [fix:mermaid-url]  | Edge-case в данных   | PREDICTABLE        |
| [regression:state] | Adjacent             | PREDICTABLE        |
| [fix:cp1252]       | вне-категорий        | UNCATEGORIZED      |
```

**Сигналы:**
- Одна категория ≥ 2 PREDICTABLE за период → 🟡 «Pre-Mortem категория `<имя>` слаба — формулировка не заставляет агента её всерьёз прорабатывать. Кандидат: усилить few-shot в `/plan` Шаг 98 (отдельный /plan)».
- ≥ 2 UNCATEGORIZED одного класса → 🟡 «класс провалов `<имя>` вне 6 категорий — кандидат на 7-ю категорию Pre-Mortem».
- 0 PREDICTABLE за период → 🟢 «Pre-Mortem калиброван: провалов из предвидимых категорий не было».

**Scope boundary:** сигналит, не правит шаблон. Изменение Pre-Mortem категорий — отдельный `/plan`. Накопление сигнала за 2+ /retro перед действием (одиночный miss = шум).

**Закрывает:** VISION Ось 5 Calibration block (feedback loop на точность Pre-Mortem предсказаний).

---

## Шаг 5 — Open Questions hygiene

*(объединяет age-based и reminder health — merged from former Шаг 5 + Шаг 5а в v4.8.0)*

**Stale questions:**
- 14-30 дней → показать список
- > 30 дней → эскалировать или явно закрыть
- > 60 дней → рекомендация закрыть как irrelevant

**Reminder health (из OPEN-QUESTIONS.md):**
Reminders READY: **N** | Обработано: **M** | Проигнорировано: **K** | Метрика: M/N
- ≥ 70% → 🟢  |  40-70% → 🟡  |  < 40% → 🔴 не работает

---

## Шаг 5.5 — Knowledge Index refresh (опциональный)

*(Пропустить если нет новых `[research:X]` или `[opinion:X]` записей с последнего `/retro`)*

Обновить `KNOWLEDGE.md` из DEVLOG:

```bash
# Methodology (two-repo):
bash scripts/build-knowledge-index.sh \
  ../it-dev-methodology-documentation/DEVLOG.md \
  ../it-dev-methodology-documentation/KNOWLEDGE.md

# Consumer (single-repo):
bash scripts/build-knowledge-index.sh DEVLOG.md KNOWLEDGE.md
```

Проверить что новые записи появились в индексе. Если `KNOWLEDGE.md` не существует — скрипт создаёт его.

---

## Шаг 5.6 — External source candidates (опциональный)

*(Пропустить если нет `[research:X]` тегов или AGENT-GAPS категорий с recurrence ≥ 2 за период)*

Агент анализирует сигналы за период и предлагает пополнение `external-sources.md`:

**1. Сигналы из DEVLOG:**
```bash
# Methodology (two-repo):
grep "\[research:" ../it-dev-methodology-documentation/DEVLOG.md | tail -20

# Consumer (single-repo):
grep "\[research:" DEVLOG.md | tail -20
```
Подсчитать уникальные slug'и. Slug встречается ≥ 2 раз → сигнал.

**2. Сигналы из AGENT-GAPS:**
Найти категории с `recurrence_rate` ≥ 2 или записи одной темы ≥ 2 раза. Категория с count ≥ 2 → сигнал недостающего знания.

**3. Формирование кандидатов (≤ 3):**
Для каждого сигнала — проверить есть ли уже покрывающий источник в `external-sources.md`.
Если нет → предложить конкретный source-кандидат с обоснованием.

```
📌 Предлагаю добавить в external-sources.md:
  - <название источника> (причина: <N× [research:slug] за период>)
  - <название источника> (причина: <N× AGENT-GAP про тему>)

Добавить? y (каждому отдельно) / skip / all
```

При **y** → дописать строку в таблицу `external-sources.md` в корне репо.
При **skip** → пропустить; сигнал остаётся в DEVLOG для следующего `/retro`.

**Где искать `external-sources.md`:**
- Methodology platform: `external-sources.md` в корне этого репо
- Consumer: `external-sources.md` в корне consumer-репо
- Файл отсутствует → пропустить шаг молча (consumer ещё не получил sync)

---

## Шаг 6 — Продуктовый поток и VISION (если применимо)

**IDEAS.md:** записи за период есть? Нет → "капчер сигналов не работает"
**Последний /vision review:** > 14 дней + IDEAS заполнен → рекомендация запустить
**Последний /vision strategy:** > 60 дней → рекомендация запустить

**VISION alignment:** распредели deploy за период по осям VISION.
- ≥ 50% feat-деплоев вне осей → "Дрейф обнаружен. Пересмотреть VISION или скорректировать курс."

*(объединяет former Шаги 6 и 7 в v4.8.0)*

---

## Шаг 8 — Аудит пропущенных сигналов

В DEVLOG искать:
- Жалобы / удивление / повторные ручные действия
- Записаны ли в IDEAS.md?

Для каждого пропущенного:
1. Добавить в IDEAS.md
2. Добавить в HYPOTHESES.md `[missed-signal]`:

```
Сигнал: [что]
Почему пропустил: [триггер не сработал / неверная классификация]
Как поймать: [конкретное изменение]
```

---

## Шаг 9 — Отчёт

```
/retro Report — {date}

Период: {N} планов, {M} деплоев

## Статистика триггеров
{таблица}

## Повторяющиеся проблемы в DEVLOG
{список или "паттернов не выявлено"}
{если найдено [fix:X]≥3 → 🔬 рекомендация /architecture-audit}

## Agent Gaps signal
{короткая сводка из Шага 2а}
{если категория ≥ 3 или total ≥ 10 → 🔬 рекомендация /architecture-audit}

## Stale Open Questions
{список с возрастом}

## Reminder health
{соотношение M/N + status}

## Inbox
{количество необработанных}

## VISION alignment
{распределение по осям}

## Methodology step audit (Шаг 4.5)
| Команда | Шаг | Status | Note |
|---|---|---|---|
| {команда} | {шаг} | HIT/SILENT/AMBIGUOUS | {cite или —} |

Candidates for cut: {список или "нет"}
High-value steps: {список}

## Pre-Mortem calibration (Шаг 4.6)
| DEVLOG-запись | Категория Pre-Mortem | Класс |
|---|---|---|
| {[fix:X]} | {категория или вне-категорий} | PREDICTABLE / UNCATEGORIZED / GENUINELY-UNFORESEEABLE |

Слабые категории: {список ≥2 PREDICTABLE или "нет — Pre-Mortem калиброван"}
Кандидаты на 7-ю категорию: {список ≥2 UNCATEGORIZED или "нет"}

## 🔬 Структурные сигналы для /architecture-audit
- {собранные сигналы из Шагов 2 и 2а — единым списком}
- {если 0 → "нет структурных сигналов в этом периоде"}

## Тактические рекомендации
- {изменение порога триггера}
- {закрытие OQ}
- {запуск /vision review / /vision strategy если применимо}

## Требует решения PM
- Повысить/понизить порог для {trigger}?
- Перевести {trigger} из soft в hard-block?
```

---

## После завершения

1. Запись в DEVLOG: `[retro] {date}: {N} планов, skip rates X/Y/Z, {K} stale OQ, signals to /architecture-audit: {N}`
2. Сбросить в triggers.json (canonical path — closes дубль-ключи G-112b):
   - `global.last_retro = { "date": today, "plans_since": 0 }` (НЕ top-level last_retro)
   - `skipped_warnings = { all zeros }`
3. Если в Шаге 2 обнаружены системные паттерны рисков → предложить обновление RISKS.md. Показать текст, не применять без подтверждения.
4. Если найдены 🔬 структурные сигналы → в финальном сообщении явно: «Следующий шаг: `/architecture-audit` для Level 4+ анализа найденных паттернов.»

---

$ARGUMENTS
---

## Вывод простым языком (обязательно — Plain-language output rule)

Заверши вывод этой команды коротким блоком `## Простыми словами` (2-5 строк): что это значит для пользователя и что делать дальше — понятным языком, без жаргона/меток/внутренних терминов. Остальной вывод (разбор, метки, детали) оставь как есть — резюме добавляется в конце. См. CLAUDE.md → Plain-language output rule.
