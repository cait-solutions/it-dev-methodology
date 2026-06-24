# Model Tiers — methodology-platform

Centralized model recommendation registry. Команды читают этот файл когда нужно дать рекомендацию по выбору модели Claude для задачи.

> **Принцип:** методология не хардкодит конкретные названия моделей (они меняются — Sonnet 4.6 → 4.7 → 5.0). Команды ссылаются на **абстрактные tiers**. Маппинг tier → текущая модель — в одном месте (в конце этого файла).
>
> **При выходе новой модели:** обновить таблицу маппинга в этом файле. Команды не трогать.
>
> **Updated:** 2026-05-19

---

## Tiers (abstracted, not version-locked)

| Tier | Когда использовать |
|---|---|
| **Fast tier** | ТОЛЬКО для non-reasoning validation tasks: smoke tests, структурное сравнение кода/текста, простые чеклист-проверки. ❌ НЕ для /plan, /code, /review которые требуют reasoning и синтеза |
| **Default tier** | **PRIMARY CHOICE** для большинства work: /plan, /code, /review, /retro, /vision review, /vision sync, /onboard. Стандарт для Full mode. До ~50 файлов в контексте. Достаточна для reasoning, консистентности, архитектурного анализа |
| **Extended tier** | Refactor / scan большого количества файлов / монолит-обход. Та же интеллектуальность что Default, но больший контекст |
| **Capable tier** | Complex reasoning: `[contract]` + threat model, multi-service refactor, root-cause analysis в `/diagnose`, стратегическая работа в `/vision strategy`, обнаружение class-bug при review |

---

## Effort & Thinking (extended UI settings)

> **Зачем эта секция:** выбор модели (tier) — только **одно** из трёх измерений настройки. Claude Code UI экспонирует рядом с выбором модели ещё два регулятора: **Effort** (слайдер `Low / Medium / High`) и **Thinking** (toggle `ON / OFF`). Tier выбирает *какую модель*, effort+thinking настраивают *глубину рассуждения*. Рекомендация только по tier («Sonnet»/«Opus») оставляет пользователя настраивать effort/thinking вслепую — поэтому **любая** рекомендация модели в методологии обязана быть трёхмерной.

**Канонический формат рекомендации (везде где агент рекомендует модель):**

```
<Tier> (<current model>) · effort: <Low|Medium|High> · thinking: <ON|OFF>
```

Пример: `Default (Sonnet) · effort: High · thinking: ON` · `Fast (Haiku) · effort: Low · thinking: OFF`.

**Дефолты по классу команды:**

| Класс задачи | Effort | Thinking | Почему |
|---|---|---|---|
| **Reasoning / синтез** (план, код, ревью, диагностика, стратегия, исследование) | **High** | **ON** | архитектурный анализ, синтез решения, поиск побочных эффектов выигрывают от extended thinking |
| **Mixed / лёгкое суждение** (drift-таблицы, batch-операции с оценкой) | **Medium** | **ON** | есть суждение, но не глубокий синтез |
| **Mechanical / checklist** (git-операции, структурное сравнение, прогон валидаторов) | **Low** | **OFF** | детерминированные шаги — thinking не добавляет ценности, только cost/latency |

**Task-shape модификаторы (перекрывают дефолт класса — применять ПАРНО с tier-upgrade/downgrade):**

- **Deep-reasoning detector** → `effort: High · thinking: ON` (вместе с upgrade до Capable): visual/CSS-баг, race condition, нетривиальный алгоритм, баг не сошедшийся за N итераций, root-cause analysis, `[contract]` + нетривиальный threat-model. Задача маленькая по scope, глубокая по reasoning → High+ON обязательны.
- **Risk Tier `[critical]` / high-stakes** (auth / payment / data integrity / 3+ consumers / необратимое) → `effort: High · thinking: ON` независимо от tier.
- **Pure mechanical** (чек-лист, git push/pull, прогон готового валидатора) → `effort: Low · thinking: OFF` даже если сессия запущена на Capable-модели — thinking на детерминированном шаге = waste.

**Природа (как у tier):** effort+thinking — **advisory**, выставляются пользователем в UI. Агент **рекомендует**, не переключает (auto-switch невозможен — требует UI-действия, как и смена модели). Mismatch-детект (Pre-flight) остаётся tier-based; effort/thinking — тонкая настройка, не блок.

---

## Per-command recommendations

> Колонки **Effort** / **Thinking** = дефолт класса команды (task-shape модификаторы выше могут перекрыть).

| Команда | Recommended tier | Effort | Thinking | Upgrade to Capable if | Notes |
|---|---|---|---|
| `/plan` | **Default** | High | ON | `[contract]` + threat model; multi-service refactor; 50+ файлов в scope | ❌ Не downgrade to Fast — требуется reasoning и синтез |
| `/code` | **Default** (inherits from `/plan`) | High | ON | new class bug discovered mid-task; 50+ файлов в scope обнаружено после верификации | ❌ Не downgrade to Fast — даже на < 20 строк |
| `/review` | **Default** (никогда не ниже) | High | ON | `[security]` + новый endpoint; обнаружен class-bug при review | ✅ Rule: review_tier ≥ Default всегда. Требуется reasoning для консистентности |
| `/deploy` | Fast | Low | OFF | smoke test failed; regression detected at after-effects | (always Fast — это чек-листы) |
| `/retro` | Default | High | ON | 60+ DEVLOG entries за период; multiple skip-rate alerts | < 10 entries — тактическая ретроспектива проекта; pattern analysis делегируется /architecture-audit |
| `/architecture-audit` | **Default** (только Способность A) или **Capable** (если Способность B/D активна) | High *(Medium если только A)* | ON | gap pattern analysis (≥ 3 AGENT-GAPS, Способность B) активирует Capable обязательно; cross-project aggregation (C) — Capable; diagram semantic review (D — сравнение узлов/связей всех карт с реальностью) — Capable обязательно; multi-service + 10+ сервисов; 30%+ drift detected | Capability matrix в самой команде. Только drift detection (A) — Default. AGENT-GAPS / Level 4+ ladder (B) ИЛИ semantic diagram review (D) — Capable hard-block |
| `/vision strategy` | **Capable** | High | ON | (always Capable — стратегическая работа требует deep reasoning) | (никогда не downgrade) |
| `/vision review` | Default | High | ON | 20+ unreviewed IDEAS за период | < 5 IDEAS |
| `/vision sync` | Default | High | ON | 10+ inbox файлов И 5+ открытых OQ; Type C конфликт обнаружен | (always Default) |
| `/product-check` | Fast | Low | OFF | (always Fast — структурное сравнение текста с кодом) | (always Fast) |
| `/diagnose` | **Capable** | High | ON | 3+ failed hypotheses (нужно искать unusual root cause) | (никогда — диагностика всегда сложна) |
| `/onboard` | Default | High *(handover)* / Low *(new-dev read → Fast)* | ON *(handover)* / OFF *(read)* | legacy domain handover с risk map для AI | new developer mode (читает только) → Fast |
| `/sync-audit` | **Default** | Low | OFF | (никогда — это checklist + grep + report) | Fast допустим только для read-only mode без disposition (rare); `--doctor` режим — Default всегда достаточен (read-only снимок, no reasoning) |
| `/pull-consumers` | **Fast** | Low | OFF | (никогда — git fetch + diff parsing + report, no reasoning) | LOCAL-ONLY команда (lives в `commands-local/`, не sync'ится консьюмерам). Запускается вручную перед /retro или анализом методологии |
| `/marketing` | **Fast** | Low *(навигация)* / High *(autodraft)* | OFF *(навигация)* / ON *(autodraft)* | Первый запуск (нет MARKETING.md) → Default (autodraft требует чтения PRODUCT/VISION + генерацию) | Навигация + прогресс state — no reasoning. Только если объясняет skill → Default |
| `/roadmap` | **Default** | High | ON | 15+ кандидатов одновременно; enabling-проект с нетривиальным leverage через несколько growth-проектов | Value-ranked приоритизация по North Star (RICE: (Impact×Confidence)/Effort). Аналитическая — оценка Impact/Effort + синтез ранжирования. ❌ Не downgrade to Fast |
| `/test` | **Default** | High | ON | Логический/visual баг не сходится (reasoning-depth, N≥3 итераций); property-based для нетривиальной логики; L2 regression на большом приложении | Генерация E2E/contract/visual тестов требует понимания acceptance criteria. Fast допустим только для запуска готового suite без генерации |
| `/push-merge` | **Fast** | Low | OFF | (никогда — это git-операция + чек-листы) | Consumer-only команда. Push ai-dev → develop/main с platform detection (GitHub/GitLab). Solo = push напрямую; team = URL для MR/PR |
| `/push` | **Fast** | Low | OFF | (никогда — это git push без merge) | Consumer-only команда. Push ai-dev → origin/ai-dev без merge, без MR/PR, без вопросов |
| `/pull` | **Fast** | Low | OFF | (никогда — это git fetch + ff-only pull) | Consumer-only команда. Pull всех workspace repos (кроме it-dev-methodology) ff-only. Показывает preview входящих коммитов. Skip если history diverged |
| `/scope-out` | **Fast** | Low *(High если интерпретация backlog)* | OFF *(ON если интерпретация)* | Пользователь просит интерпретировать backlog (приоритизация / кластеризация по темам) → Default | Запуск `scope-view.sh` + показ URL — no reasoning. Эфемерная Mermaid-визуализация отложенного scope (PRODUCT-GAPS/AGENT-GAPS/ROADMAP/recommendations). Не пишет файлы |
| `/doc-audit` | **Fast** | Low *(High если интерпретация/диагностика)* | OFF *(ON если интерпретация)* | Интерпретация результатов (приоритизация WARN-долга) или диагностика FAIL-причин → Default; системная причина → отдельный /diagnose (Capable) | Запуск `doc-audit.sh` + представление Summary — детерминированный прогон валидаторов, no reasoning. `--fix` обновляет только mermaid-ссылки |
| `/research` | **Default** | High | ON | Conflicting sources requiring deep reasoning; стратегический вопрос с нетривиальным trade-off анализом | Interactive structured research (≤3 checkpoints). Фиксирует вывод в DEVLOG `[research:X]`. Fast НЕ рекомендуется — synthesis требует reasoning |
| `/skill` | **Default** | High | ON | ≥10 разнотипных [research:X] entries (широкий домен) → Capable | Синтез накопленных `[research:X]` + сессионных наработок → domain SKILL.md в `.claude/skills/<name>/`. Auto-activation при следующей сессии. Fast ❌ — синтез требует reasoning |
| `/scan-sources` | **Default** | High | ON | ≥3 источника с conflicting сигналами требуют cross-source reasoning; стратегический вывод с нетривиальным trade-off | Скан реестра `external-sources.md` (WebFetch/WebSearch + verdict). Анализ «что нового decision-relevant» → `[research:X]` + IDEAS. Fast НЕ рекомендуется — synthesis требует reasoning |
| `/push-consumers` | **Default** | Medium | ON | (никогда — drift-таблица + batch sync. Fast если ≤2 консьюмера) | LOCAL-ONLY команда (lives в `commands-local/`, не sync'ится консьюмерам). Доставка обновлений методологии консьюмерам. Запускается вручную после релизов |
| `/opinion` | **Capable** | High | ON | (always Capable — council 7/7 дефолт: 7 независимых external советников + синтез требуют deep reasoning) | Council-7 по умолчанию: 7 независимых external sub-agents (5 Council ролей + Альтернативщик + Complexity tax), каждый в своём чистом контексте → structural independence. `/opinion+` = legacy-алиас. Лёгкий inline `[?]` (5 симулируемых в контексте) не запускает команду → pre-flight не триггерит, исполняется на текущей модели сессии. Fast/Default ❌ — синтез 7 вердиктов требует reasoning |

---

## Pre-flight model check (обязательно для каждой команды)

При старте **любой** команды агент обязан выполнить:

### Шаг 1: определить текущую модель (autodetect-first)

**Приоритет источников (waterfall):**

1. **Auto-detected (предпочтительно):** прочитать `.claude/state/session-model.json` → поле `tier`.
   - Файл пишется `model-detect.py` SessionStart хуком автоматически (v7.11.0+).
   - `stale: false` → использовать `tier` как confirmed; **НЕ** спрашивать пользователя.
   - `stale: true` (после /clear, resume, compact: `model` поле отсутствовало в payload) → использовать как hint → перейти к пункту 2.
   - Файл отсутствует (старый consumer без v7.11.0+) → перейти к пункту 2.

2. **Спросить пользователя (fallback):** если autodetect недоступен или stale.

⛔ **Не полагаться на self-identification** через system prompt — он может быть stale (пользователь мог переключить модель в UI mid-session, system prompt не обновится).

Агент задаёт **один короткий вопрос** в начале команды:

```
Pre-flight check: на какой модели сейчас работаешь?
  (нужно для рекомендации tier для /<command>; см. .claude/model-tiers.md)

  a) Haiku 4.5 (Fast tier)
  b) Sonnet 4.6 — Default или 1M context (Default или Extended tier)
  c) Opus 4.8 — 1M context (Capable tier)
  d) другая — укажи
```

**Если пользователь явно подтвердил модель в этой сессии ранее** — использовать его ответ; повторно не спрашивать.

### Шаг 2: сравнить с Default tier команды

См. per-command матрицу выше.

### Шаг 3: пауза + рекомендация если mismatch

Рекомендация **трёхмерна** (`tier · effort · thinking`). Поведение зависит от **направления** mismatch — это две разные ветки, не один порог:

| Направление | Когда | Реакция |
|---|---|---|
| **Under-powered** (текущий tier **НИЖЕ** рекомендованного) | **любая ступень вниз** (Haiku при Default/Capable; Sonnet при Capable) | 🛑 **громкий STOP-advisory + пауза** (см. шаблон ниже) — ждать `«продолжай»`/`«стоп»` |
| **Over-powered** (текущий tier **ВЫШЕ** рекомендованного) | ≥2 ступени (напр. Capable на `/product-check`) | ⚪ одна строка FYI про экономию, **без паузы** |
| Точное совпадение ИЛИ 1 ступень вверх | — | тихо, ничего не печатать |

> **Почему under-power = любая ступень, а over-power = ≥2:** под-power несёт **quality risk** (модель может упустить архитектурное нарушение / регрессию) — это асимметрично дороже, поэтому ловим даже 1 ступень вниз. Over-power несёт лишь **cost waste** — терпимо, заметка только при ощутимом (≥2) перерасходе. effort/thinking всегда сообщаются как тонкая настройка (не блок — пользователь выставляет слайдер Effort + toggle Thinking в UI рядом с моделью).

#### Шаблон сообщения — under-powered (КАНОН, всегда на русском)

При under-power агент печатает **дословно этот блок** (подставив значения), затем **останавливается и ждёт** ответа пользователя. ⛔ Формат фиксирован — не сокращать, не переводить на английский, не заменять своим: единый узнаваемый сигнал во всех командах.

```
─────────────────────────────────────────────
# 🛑 СТОП — МОДЕЛЬ СЛАБЕЕ, ЧЕМ НУЖНО
─────────────────────────────────────────────

**Сейчас:**  <модель> (<current tier>)
**Нужно:**   <recommended tier> · effort: <X> · thinking: <Y>

⚠️  Команда /<command> требует более глубокого reasoning.
    На текущей модели — риск упустить <конкретика: архитектурное
    нарушение / регрессию / пропущенный edge case>.

👉  Останови команду · переключи модель в UI · запусти заново.

Продолжить на текущей модели на свой риск?
→ напиши «продолжай»  или  «стоп»
─────────────────────────────────────────────
```

**Обработка ответа (advisory-пауза, НЕ программный блок):**
- `«стоп»` (или `n`/`нет`/тишина с явным намерением прервать) → **прекратить команду**; пользователь переключает модель в UI + запускает команду заново.
- `«продолжай»` (или `y`/`да`) → продолжить выполнение на текущей модели; зафиксировать **accepted risk** в DEVLOG (`[opinion]`/inline-заметка о сознательном выборе).
- Заполнить `<конкретика>` реальным риском этой команды (для `/plan` — «архитектурное нарушение»; для `/review` — «пропущенная регрессия»; для `/diagnose` — «неверный корень»).

#### Сообщение — over-powered (одна строка, без паузы)

```
⚪ FYI: текущая модель мощнее рекомендованной для /<command> (<current> vs <recommended>) — можно сэкономить (Default/Fast хватит). Не блок, продолжаю.
```

### Не блокирует (программно)

Это **advisory-пауза**, не hard-block: агент печатает блок и ждёт решения пользователя, но не падает и не стирает запрос. Программный stop (UserPromptSubmit hook) **намеренно отложен** — твердеет по данным skip-rate (Ось 1), не преждевременно. Auto-switch модели невозможен (требует UI action пользователя).

### Почему "спрашивать", а не "детектировать"

Агент **не может надёжно идентифицировать свою модель**:
- system prompt описывает модель при старте сессии, но не обновляется при UI-переключении
- API routing может расходиться с UI-выбором в некоторых конфигурациях
- Между разными surfaces (CLI / IDE extension / web) поведение может отличаться

Единственный надёжный источник — пользователь. Поэтому спрашиваем явно. Это **раз за сессию** (не на каждую команду — если пользователь уже подтвердил модель ранее в той же сессии, агент использует confirmed value).

### Пример

- Opus на `/product-check` → Capable vs Fast = 2 ступени **over** → ⚪ одна строка FYI про экономию, без паузы.
- Haiku на `/vision strategy` → Fast vs Capable = 2 ступени **under** → 🛑 громкий STOP-advisory + пауза.
- Sonnet на `/plan` (рекоменд. Default) → совпадение → тихо.
- **Sonnet на `/opinion`** (рекоменд. Capable) → 1 ступень **under** → 🛑 STOP-advisory + пауза (под-power ловится даже на 1 ступень, в отличие от over-power).
- Opus на `/plan` (рекоменд. Default) → 1 ступень **over** → тихо (1 ступень over не fires).

---

## Mid-task complexity escalation

Команды `/code`, `/review`, `/diagnose` имеют **обязательный шаг Complexity reassessment** после первой верификации. Если обнаружено условие из колонки "Upgrade to Capable if" соответствующей команды → команда **обязана** остановиться и спросить:

```
⚠️ Сложность задачи выше плановой оценки.
   Текущая модель: <current tier>
   Рекомендуемая: <upgrade tier>
   Причина: <конкретно что обнаружено>

Варианты:
  a) Продолжить на текущей модели (зафиксировать в DEVLOG как accepted risk)
  b) Переключиться (рестарт сессии после смены модели)
  c) Прервать и вернуться в /plan для пересмотра
```

---

## Output format в `/plan`

`/plan` Шаг 3 (План реализации) обязан включать блок. **Каждая рекомендация — трёхмерная** (`tier · effort · thinking`, см. § Effort & Thinking):

```markdown
## Recommended models

**For /code (immediate next):** <Tier> · effort: <Low|Medium|High> · thinking: <ON|OFF> — <reasoning из конкретной задачи>
**For /review after /code:** <Tier> · effort: <Low|Medium|High> · thinking: <ON|OFF>
**For triggered commands** (если были предложены в Шаге -3.2):
  - /<command-name>: <Tier> · effort: <X> · thinking: <Y> — <typical для команды + override если задача нетипичная>

**Mid-task escalation signals для /code:**
  - <конкретные условия из этой задачи которые сигнализируют upgrade tier + effort/thinking>
```

---

## Mapping current model names → tiers

Обновлять при выпуске новых моделей Anthropic. Только эту секцию — таблицы выше остаются stable.

| Tier | Current Anthropic model | Anthropic identifier |
|---|---|---|
| Fast tier | Haiku 4.5 | `claude-haiku-4-5` |
| Default tier | Sonnet 4.6 (Default) | `claude-sonnet-4-6` |
| Extended tier | Sonnet 4.6 (1M context) | `claude-sonnet-4-6` with `extended-context` option |
| Capable tier | Opus 4.8 (1M context) | `claude-opus-4-8` |

**Last review:** 2026-06-22

**Auto-detect (v7.11.0+):** `model-detect.py` SessionStart хук пишет `.claude/state/session-model.json`
с tier через substring-match (`opus`→Capable, `sonnet`→Default, `haiku`→Fast, `fable`→Capable).
Tier читается Pre-flight шагом 1 вместо вопроса пользователю (если `stale: false`).

---

## Принципы

1. **Tier-абстракция, не модель-абстракция.** Команды ссылаются на "Default tier", не на "Sonnet 4.6". Когда модель меняется — правка в одной таблице.

2. **Mid-task escalation важнее initial recommendation.** Рекомендация в начале — оценка; реальность может быть сложнее. Системные команды (`/code`, `/review`, `/diagnose`) обязаны переоценивать.

3. **Override фиксируется.** Если developer выбрал модель отличную от рекомендации — это фиксируется в DEVLOG как accepted risk. Cost-conscious решение или conscious upgrade — оба valid, но трекаются.

4. **Не блокирующее.** Рекомендации — advisory. Developer всегда может проигнорировать. Цель — guidance, не enforcement.

5. **Cost awareness как Quality bar.** Если 50% решений систематически идут на Capable когда хватает Default — это сигнал methodology-проблемы (плохие триггеры) или developer-проблемы (over-engineering). Cost-awareness — это **design value**, а не measured metric: он surface-ится через **Pre-flight model check** (mismatch detection: over-powered = cost waste, см. секцию «Pre-flight model check») и через **DEVLOG accepted-risk записи** (Принцип 3 — каждый override от рекомендации фиксируется). Автоматический анализ распределения tier'ов (model-cost-distribution) **намеренно вне scope методологии**: она не runtime и не имеет источника фактических token/cost-данных — agent-estimated числа были бы недетерминированной телеметрией (theater), а не evidence. Сигнал об over-use ловится качественно: developer видит свои Pre-flight mismatch'и и accepted-risk DEVLOG-записи и сам калибрует.
