# Model Tiers — methodology-platform

Centralized model recommendation registry. Команды читают этот файл когда нужно дать рекомендацию по выбору модели Claude для задачи.

> **Принцип:** методология не хардкодит конкретные названия моделей (они меняются — Sonnet 4.6 → 4.7 → 5.0). Команды ссылаются на **абстрактные tiers**. Маппинг tier → текущая модель — в одном месте (в конце этого файла).
>
> **При выходе новой модели:** обновить таблицу маппинга в этом файле. Команды не трогать.
>
> **Updated:** 2026-05-16

---

## Tiers (abstracted, not version-locked)

| Tier | Когда использовать |
|---|---|
| **Fast tier** | ТОЛЬКО для non-reasoning validation tasks: smoke tests, структурное сравнение кода/текста, простые чеклист-проверки. ❌ НЕ для /plan, /code, /review которые требуют reasoning и синтеза |
| **Default tier** | **PRIMARY CHOICE** для большинства work: /plan, /code, /review, /retro, /sync-vision, /product-review, /onboard. Стандарт для Full mode. До ~50 файлов в контексте. Достаточна для reasoning, консистентности, архитектурного анализа |
| **Extended tier** | Refactor / scan большого количества файлов / монолит-обход. Та же интеллектуальность что Default, но больший контекст |
| **Capable tier** | Complex reasoning: `[contract]` + threat model, multi-service refactor, root-cause analysis в `/diagnose`, стратегическая работа в `/product-vision`, обнаружение class-bug при review |

---

## Per-command recommendations

| Команда | Recommended tier | Upgrade to Capable if | Notes |
|---|---|---|---|
| `/plan` | **Default** | `[contract]` + threat model; multi-service refactor; 50+ файлов в scope | ❌ Не downgrade to Fast — требуется reasoning и синтез |
| `/code` | **Default** (inherits from `/plan`) | new class bug discovered mid-task; 50+ файлов в scope обнаружено после верификации | ❌ Не downgrade to Fast — даже на < 20 строк |
| `/review` | **Default** (никогда не ниже) | `[security]` + новый endpoint; обнаружен class-bug при review | ✅ Rule: review_tier ≥ Default всегда. Требуется reasoning для консистентности |
| `/deploy` | Fast | smoke test failed; regression detected at after-effects | (always Fast — это чек-листы) |
| `/retro` | Default | 60+ DEVLOG entries за период; multiple skip-rate alerts | < 10 entries за период |
| `/architecture-audit` | Default | multi-service + 10+ сервисов; 30%+ drift detected | (always Default) |
| `/sync-vision` | Default | 10+ inbox файлов И 5+ открытых OQ; Type C конфликт обнаружен | (always Default) |
| `/product-vision` | **Capable** | (always Capable — стратегическая работа требует deep reasoning) | (никогда не downgrade) |
| `/product-review` | Default | 20+ unreviewed IDEAS за период | < 5 IDEAS |
| `/product-check` | Fast | (always Fast — структурное сравнение текста с кодом) | (always Fast) |
| `/diagnose` | **Capable** | 3+ failed hypotheses (нужно искать unusual root cause) | (никогда — диагностика всегда сложна) |
| `/onboard` | Default | legacy domain handover с risk map для AI | new developer mode (читает только) → Fast |

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
- Пользователь подтверждает "Haiku 4.5", запускает `/product-vision` → match: Fast vs Capable = 2 tiers under → 🔴 strong recommendation Opus.

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

5. **Cost awareness как Quality bar.** Если 50% решений идут на Capable когда хватает Default — methodology проблема (плохие триггеры) или developer проблема (over-engineering). `/retro` Шаг 4 включает анализ model-cost-distribution.
