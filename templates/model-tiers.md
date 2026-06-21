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

## Per-command recommendations

| Команда | Recommended tier | Upgrade to Capable if | Notes |
|---|---|---|---|
| `/plan` | **Default** | `[contract]` + threat model; multi-service refactor; 50+ файлов в scope | ❌ Не downgrade to Fast — требуется reasoning и синтез |
| `/code` | **Default** (inherits from `/plan`) | new class bug discovered mid-task; 50+ файлов в scope обнаружено после верификации | ❌ Не downgrade to Fast — даже на < 20 строк |
| `/review` | **Default** (никогда не ниже) | `[security]` + новый endpoint; обнаружен class-bug при review | ✅ Rule: review_tier ≥ Default всегда. Требуется reasoning для консистентности |
| `/deploy` | Fast | smoke test failed; regression detected at after-effects | (always Fast — это чек-листы) |
| `/retro` | Default | 60+ DEVLOG entries за период; multiple skip-rate alerts | < 10 entries — тактическая ретроспектива проекта; pattern analysis делегируется /architecture-audit |
| `/architecture-audit` | **Default** (только Способность A) или **Capable** (если Способность B/D активна) | gap pattern analysis (≥ 3 AGENT-GAPS, Способность B) активирует Capable обязательно; cross-project aggregation (C) — Capable; diagram semantic review (D — сравнение узлов/связей всех карт с реальностью) — Capable обязательно; multi-service + 10+ сервисов; 30%+ drift detected | Capability matrix в самой команде. Только drift detection (A) — Default. AGENT-GAPS / Level 4+ ladder (B) ИЛИ semantic diagram review (D) — Capable hard-block |
| `/vision strategy` | **Capable** | (always Capable — стратегическая работа требует deep reasoning) | (никогда не downgrade) |
| `/vision review` | Default | 20+ unreviewed IDEAS за период | < 5 IDEAS |
| `/vision sync` | Default | 10+ inbox файлов И 5+ открытых OQ; Type C конфликт обнаружен | (always Default) |
| `/product-check` | Fast | (always Fast — структурное сравнение текста с кодом) | (always Fast) |
| `/diagnose` | **Capable** | 3+ failed hypotheses (нужно искать unusual root cause) | (никогда — диагностика всегда сложна) |
| `/onboard` | Default | legacy domain handover с risk map для AI | new developer mode (читает только) → Fast |
| `/sync-audit` | **Default** | (никогда — это checklist + grep + report) | Fast допустим только для read-only mode без disposition (rare); `--doctor` режим — Default всегда достаточен (read-only снимок, no reasoning) |
| `/pull-consumers` | **Fast** | (никогда — git fetch + diff parsing + report, no reasoning) | LOCAL-ONLY команда (lives в `commands-local/`, не sync'ится консьюмерам). Запускается вручную перед /retro или анализом методологии |
| `/marketing` | **Fast** | Первый запуск (нет MARKETING.md) → Default (autodraft требует чтения PRODUCT/VISION + генерацию) | Навигация + прогресс state — no reasoning. Только если объясняет skill → Default |
| `/roadmap` | **Default** | 15+ кандидатов одновременно; enabling-проект с нетривиальным leverage через несколько growth-проектов | Value-ranked приоритизация по North Star (RICE: (Impact×Confidence)/Effort). Аналитическая — оценка Impact/Effort + синтез ранжирования. ❌ Не downgrade to Fast |
| `/test` | **Default** | Логический/visual баг не сходится (reasoning-depth, N≥3 итераций); property-based для нетривиальной логики; L2 regression на большом приложении | Генерация E2E/contract/visual тестов требует понимания acceptance criteria. Fast допустим только для запуска готового suite без генерации |
| `/push-merge` | **Fast** | (никогда — это git-операция + чек-листы) | Consumer-only команда. Push ai-dev → develop/main с platform detection (GitHub/GitLab). Solo = push напрямую; team = URL для MR/PR |
| `/push` | **Fast** | (никогда — это git push без merge) | Consumer-only команда. Push ai-dev → origin/ai-dev без merge, без MR/PR, без вопросов |
| `/pull` | **Fast** | (никогда — это git fetch + ff-only pull) | Consumer-only команда. Pull всех workspace repos (кроме it-dev-methodology) ff-only. Показывает preview входящих коммитов. Skip если history diverged |
| `/scope-out` | **Fast** | Пользователь просит интерпретировать backlog (приоритизация / кластеризация по темам) → Default | Запуск `scope-view.sh` + показ URL — no reasoning. Эфемерная Mermaid-визуализация отложенного scope (PRODUCT-GAPS/AGENT-GAPS/ROADMAP/recommendations). Не пишет файлы |
| `/doc-audit` | **Fast** | Интерпретация результатов (приоритизация WARN-долга) или диагностика FAIL-причин → Default; системная причина → отдельный /diagnose (Capable) | Запуск `doc-audit.sh` + представление Summary — детерминированный прогон валидаторов, no reasoning. `--fix` обновляет только mermaid-ссылки |
| `/research` | **Default** | Conflicting sources requiring deep reasoning; стратегический вопрос с нетривиальным trade-off анализом | Interactive structured research (≤3 checkpoints). Фиксирует вывод в DEVLOG `[research:X]`. Fast НЕ рекомендуется — synthesis требует reasoning |
| `/scan-sources` | **Default** | ≥3 источника с conflicting сигналами требуют cross-source reasoning; стратегический вывод с нетривиальным trade-off | Скан реестра `external-sources.md` (WebFetch/WebSearch + verdict). Анализ «что нового decision-relevant» → `[research:X]` + IDEAS. Fast НЕ рекомендуется — synthesis требует reasoning |
| `/push-consumers` | **Default** | (никогда — drift-таблица + batch sync. Fast если ≤2 консьюмера) | LOCAL-ONLY команда (lives в `commands-local/`, не sync'ится консьюмерам). Доставка обновлений методологии консьюмерам. Запускается вручную после релизов |
| `/opinion` | **Capable** | (always Capable — council 7/7 дефолт: 7 независимых external советников + синтез требуют deep reasoning) | Council-7 по умолчанию: 7 независимых external sub-agents (5 Council ролей + Альтернативщик + Complexity tax), каждый в своём чистом контексте → structural independence. `/opinion+` = legacy-алиас. Лёгкий inline `[?]` (5 симулируемых в контексте) не запускает команду → pre-flight не триггерит, исполняется на текущей модели сессии. Fast/Default ❌ — синтез 7 вердиктов требует reasoning |

---

## Pre-flight model check (обязательно для каждой команды)

При старте **любой** команды агент обязан выполнить:

### Шаг 1: спросить пользователя о текущей модели

⛔ **Не полагаться на self-identification** через system prompt — он может быть stale (например, если пользователь переключил модель в UI mid-session, system prompt не обновится).

Агент задаёт **один короткий вопрос** в начале команды:

```
Pre-flight check: на какой модели сейчас работаешь?
  (нужно для рекомендации tier для /<command>; см. .claude/model-tiers.md)

  a) Haiku 4.5 (Fast tier)
  b) Sonnet 4.6 — Default или 1M context (Default или Extended tier)
  c) Opus 4.7 — 1M context (Capable tier)
  d) другая — укажи
```

**Если пользователь явно подтвердил модель в этой сессии ранее** — можно использовать его ответ; повторно не спрашивать.

### Шаг 2: сравнить с Default tier команды

См. per-command матрицу выше.

### Шаг 3: пауза + рекомендация если mismatch

```
⚠️ Mismatch текущей модели и рекомендации для этой команды.
   Текущая: <user-confirmed model> (<current tier>)
   Рекомендуется: <recommended tier> для /<command>
   Причина mismatch: over-powered (cost waste) | under-powered (quality risk)

Варианты:
  a) Продолжить на текущей модели (зафиксируется как accepted risk в DEVLOG)
  b) Переключиться: смени модель в UI Claude Code → новая сессия для чистого контекста
  c) Прервать выполнение
```

### Не блокирует

Pre-flight check — advisory. Пользователь решает. Auto-switch невозможен (требует UI action).

### Когда mismatch fires

- Текущий tier > recommended на ≥2 ступени (over-powered): например Capable на /product-check. Cost waste.
- Текущий tier < recommended на ≥2 ступени (under-powered): например Fast на /diagnose. Quality risk.
- Разница в 1 ступень — ⚪ neutral, не fires.

### Почему "спрашивать", а не "детектировать"

Агент **не может надёжно идентифицировать свою модель**:
- system prompt описывает модель при старте сессии, но не обновляется при UI-переключении
- API routing может расходиться с UI-выбором в некоторых конфигурациях
- Между разными surfaces (CLI / IDE extension / web) поведение может отличаться

Единственный надёжный источник — пользователь. Поэтому спрашиваем явно. Это **раз за сессию** (не на каждую команду — если пользователь уже подтвердил модель ранее в той же сессии, агент использует confirmed value).

### Пример

- Пользователь подтверждает "Opus 4.7", запускает `/product-check` → match: Capable vs Fast = 2 tiers over → 🟡 пауза, рекомендация Sonnet/Haiku.
- Пользователь подтверждает "Haiku 4.5", запускает `/vision strategy` → match: Fast vs Capable = 2 tiers under → 🔴 strong recommendation Opus.

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

`/plan` Шаг 3 (План реализации) обязан включать блок:

```markdown
## Recommended models

**For /code (immediate next):** <tier> — <reasoning из конкретной задачи>
**For /review after /code:** <tier>
**For triggered commands** (если были предложены в Шаге -3.2):
  - /<command-name>: <tier> — <typical для этой команды + override если задача нетипичная>

**Mid-task escalation signals для /code:**
  - <конкретные условия из этой задачи которые сигнализируют upgrade>
```

---

## Mapping current model names → tiers

Обновлять при выпуске новых моделей Anthropic. Только эту секцию — таблицы выше остаются stable.

| Tier | Current Anthropic model | Anthropic identifier |
|---|---|---|
| Fast tier | Haiku 4.5 | `claude-haiku-4-5` |
| Default tier | Sonnet 4.6 (Default) | `claude-sonnet-4-6` |
| Extended tier | Sonnet 4.6 (1M context) | `claude-sonnet-4-6` with `extended-context` option |
| Capable tier | Opus 4.7 (1M context) | `claude-opus-4-7` |

**Last review:** 2026-05-16

---

## Принципы

1. **Tier-абстракция, не модель-абстракция.** Команды ссылаются на "Default tier", не на "Sonnet 4.6". Когда модель меняется — правка в одной таблице.

2. **Mid-task escalation важнее initial recommendation.** Рекомендация в начале — оценка; реальность может быть сложнее. Системные команды (`/code`, `/review`, `/diagnose`) обязаны переоценивать.

3. **Override фиксируется.** Если developer выбрал модель отличную от рекомендации — это фиксируется в DEVLOG как accepted risk. Cost-conscious решение или conscious upgrade — оба valid, но трекаются.

4. **Не блокирующее.** Рекомендации — advisory. Developer всегда может проигнорировать. Цель — guidance, не enforcement.

5. **Cost awareness как Quality bar.** Если 50% решений систематически идут на Capable когда хватает Default — это сигнал methodology-проблемы (плохие триггеры) или developer-проблемы (over-engineering). Cost-awareness — это **design value**, а не measured metric: он surface-ится через **Pre-flight model check** (mismatch detection: over-powered = cost waste, см. секцию «Pre-flight model check») и через **DEVLOG accepted-risk записи** (Принцип 3 — каждый override от рекомендации фиксируется). Автоматический анализ распределения tier'ов (model-cost-distribution) **намеренно вне scope методологии**: она не runtime и не имеет источника фактических token/cost-данных — agent-estimated числа были бы недетерминированной телеметрией (theater), а не evidence. Сигнал об over-use ловится качественно: developer видит свои Pre-flight mismatch'и и accepted-risk DEVLOG-записи и сам калибрует.
