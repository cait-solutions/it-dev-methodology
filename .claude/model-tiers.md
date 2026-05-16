<!-- AUTO-GENERATED from methodology-platform v2.5.0 -->
<!-- Synced: 2026-05-16 -->
<!-- DO NOT EDIT — changes will be overwritten on next sync -->
<!-- Modify via PR to https://github.com/cait-solutions/it-dev-methodology -->
<!-- Emergency override: edit locally + open PR within 48h -->

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
| **Fast tier** | Lite mode, < 20 строк изменений, deterministic checklists (smoke tests, продуктовая проверка, простые подтверждения) |
| **Default tier** | Full mode стандарт — повседневные задачи. Большинство `[code]`, `[product]`, `[process]`. До ~50 файлов в контексте |
| **Extended tier** | Refactor / scan большого количества файлов / монолит-обход. Та же интеллектуальность что Default, но больший контекст |
| **Capable tier** | Complex reasoning: `[contract]` + threat model, multi-service refactor, root-cause analysis в `/diagnose`, стратегическая работа в `/product-vision` |

---

## Per-command recommendations

| Команда | Default tier | Upgrade to Capable if | Downgrade to Fast if |
|---|---|---|---|
| `/plan` | Default | `[contract]` + threat model; multi-service refactor; 50+ файлов в scope | Lite mode + < 20 строк |
| `/code` | inherits from `/plan` | new class bug discovered mid-task; 50+ файлов в scope обнаружено после верификации | scope сократился < 30 строк после уточнения |
| `/review` | one tier below `/code` | `[security]` + новый endpoint; обнаружен class-bug при review | Lite mode |
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

1. **Определить текущую модель** из system prompt (Anthropic identifier: `claude-opus-4-7`, `claude-sonnet-4-6`, `claude-haiku-4-5`, etc.).
2. **Сравнить с Default tier** для запускаемой команды (см. матрицу выше).
3. **Если mismatch — пауза + краткая рекомендация:**

```
⚠️ Mismatch текущей модели и рекомендации для этой команды.
   Текущая: <current model name> (<current tier>)
   Рекомендуется: <recommended tier> для /<command>
   Причина mismatch: over-powered (дорого) | under-powered (риск низкого качества)

Варианты:
  a) Продолжить на текущей модели (особенно если разница маленькая)
  b) Переключиться: закрыть сессию → выбрать <recommended model> → открыть новую сессию
  c) Прервать выполнение
```

4. **Не блокирует** — пользователь решает; auto-switch невозможен (требует UI action).

**Когда mismatch fires:**
- Текущий tier > recommended tier на 2 ступени (over-powered): например, Capable когда нужен Fast. Cost waste.
- Текущий tier < recommended tier (under-powered): например, Fast когда нужен Capable. Risk low quality.
- Разница в 1 ступень — ⚪ neutral, не fires (это normal headroom).

**Пример:**
- Запущен `/product-check` (Fast tier) на Opus 4.7 (Capable) → 🟡 over-powered by 2 tiers → recommend Sonnet (Default) or Haiku (Fast).
- Запущен `/product-vision` (Capable tier) на Haiku 4.5 (Fast) → 🔴 under-powered by 2 tiers → strongly recommend Opus.

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
