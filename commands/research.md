# /research — Структурированное исследование

> **Цель:** структурированно исследовать конкретный вопрос (маркетплейс, технология, конкурент, регуляторика, API — любая тема) и гарантированно зафиксировать вывод в DEVLOG. Команда для planned research перед decision. Не замена `/deep-research` (широкий многоисточниковый анализ) — `/research` это lightweight structured investigation с bounded depth.

**Отличие от deep-research:**

| | `/research` | `deep-research` skill |
|---|---|---|
| Scope | Один конкретный вопрос | Широкий тематический анализ |
| Режим | Interactive, ≤3 чекпоинта | Multi-agent параллельный |
| Output | `[research:X]` строка в DEVLOG | Comprehensive report |
| Токены | Низкие | Высокие |

---

## Рекомендуемая модель

**Extended (UI settings):** effort: **High** · thinking: **ON** — synthesis выводов из источников = reasoning. См. `.claude/model-tiers.md` § Effort & Thinking.

**Default tier:** **Default** (Sonnet) — WebSearch + synthesis + structured output достаточно.
**Upgrade to Capable if:** Conflicting sources requiring deep reasoning; стратегический вопрос с нетривиальным trade-off анализом.
**Downgrade to Fast:** НЕ рекомендуется — synthesis требует reasoning.
**Mid-task escalation:** если найдены ≥3 conflicting sources → предложить Capable.
**Pre-flight model check:** да — спроси пользователя какая модель активна при старте.

---

## Шаг 1 — Pre-flight: decision context

Задай пользователю **один вопрос** перед тем как начать исследование:

> «Что это исследование должно решить? Какое решение ты примешь на основе вывода?»

Зачем: без decision context нельзя знать что считать «достаточным» ответом. Без него любой WebSearch → over-research (ищем всё) или under-research (ищем не то).

**Примеры хорошего decision context:**
- «Решаем подключать ли OTTO Market как канал продаж для refurbished товаров»
- «Выбираем между Stripe и PayPal для немецкого рынка — по комиссиям»
- «Проверяем GDPR-ограничения перед сбором email в Германии»

❌ «Просто хочу знать о X» → не decision context → попросить уточнить: «К какому решению приведёт этот вывод?»

---

## Шаг 2 — Исследование

Выполни WebSearch с фокусом на decision context из Шага 1.

**Приоритет источников:**
1. Официальные источники (policy pages, docs, TOS, gov.де)
2. Актуальность ≤12 месяцев (если тема меняется — проверить дату)
3. Конкретные факты с verdictом, а не общие описания

**Depth rule:** stop when decision context answered. Не уходи в смежные темы если они не влияют на решение.

---

## Шаг 3 — Mid-research checkpoint (если нужен)

Выполняется только если обнаружен **fork** — когда найдено A (отвечает на вопрос) И B (меняет саму рамку вопроса).

```
«Нашёл [A] — достаточно для решения по [decision context].
 Попутно обнаружил [B] — это меняет сам вопрос.
 Продолжаем с [A], или хочешь исследовать [B]? (a / b / оба)»
```

Если fork отсутствует → пропустить шаг 3, перейти к шагу 4 сразу.

---

## Шаг 4 — Вердикт + DEVLOG entry proposal

Сформулируй вывод и предложи готовую строку для DEVLOG.

**Формат строки (строго):**

```
[research:<topic-slug>] → <что изучали>: <вывод>. <impact>. Source: <url или "knowledge (verify)">
```

Поля:
- `<topic-slug>` — kebab-case slug темы (`otto.de`, `stripe-fees-de`, `gdpr-email-de`, `react-perf-2026`)
- `<что изучали>` — кратко (≤40 символов)
- `<вывод>` — конкретный факт или решение
- `<impact>` — одно слово-verdict: `viable` / `not-viable` / `blocked` / `confirmed` / `conditional` / `unclear`
- `Source:` — реальный URL или `"knowledge (verify)"` если из памяти модели

**Примеры:**
```
✅ [research:otto.de] → refurbished policy: OTTO Market запрещает. not-viable для нашего SKU. Source: https://sell.otto.de/restrictions
✅ [research:stripe-fees-de] → комиссия Германия: 1.5% + €0.25 EU карты. viable. Source: https://stripe.com/de/pricing
✅ [research:gdpr-email-collect] → согласие на email: double opt-in обязателен в DE. blocked без формы подтверждения. Source: https://datenschutz.org/...
❌ [research:otto] → смотрели OTTO, не подходит (нет slug/verdict/source)
```

Показать пользователю:

```
📋 Предлагаю запись в DEVLOG:
[research:<slug>] → <вывод одной строкой>

(y — добавить / edit — отредактировать / skip — не добавлять)
```

---

## Шаг 5 — Запись в DEVLOG

При ответе `y` или отредактированном варианте:

**1. Определить путь к DEVLOG:**
- Прочитать `CLAUDE.local.md` → `doc_repo_path`
- Если `doc_repo_path` задан → DEVLOG в `<doc_repo_path>/DEVLOG.md`
- Если `doc_repo_path: null` или отсутствует → DEVLOG в текущем repo root (`DEVLOG.md`)

**2. Добавить строку в DEVLOG:**
- Найти секцию текущей даты `## YYYY-MM-DD` (или создать если нет)
- Добавить строку `[research:<slug>] → ...` в конец секции дня

**3. Вывести подтверждение:**
```
✅ Записано в DEVLOG: [research:<slug>]
```

**❌ НЕ делать:**
- Не писать полный транскрипт исследования в DEVLOG
- Не создавать `docs/research/` файлы (DEVLOG one-liner достаточен)
- Не добавлять несколько строк для одного вопроса
- Не пропускать Source (даже если `"knowledge (verify)"`)

При ответе `skip` → не записывать, сообщить:
```
⏭ Запись пропущена. Вывод: [краткая сводка одним предложением]
```

---

## Связь с [research:X] тегом

`/research` — структурированный путь. `[research:X]` тег используется и без команды — при incidental findings во время любой сессии: агент предлагает DEVLOG запись через Stop hook reminder (WebSearch + verdict detection).

Разница: `/research` = planned (пользователь открывает команду осознанно). Тег = incidental (finding возникает попутно).
---

## Вывод простым языком (обязательно — Plain-language output rule)

Заверши вывод этой команды коротким блоком `## Простыми словами` (2-5 строк): что это значит для пользователя + конкретная committed-рекомендация / следующий шаг («Рекомендую X»), а НЕ открытый вопрос — понятным языком, без жаргона/меток. Вопрос допустим только после явной рекомендации. Остальной вывод (разбор, метки, детали) оставь как есть — резюме добавляется в конце. См. CLAUDE.md → Plain-language output rule.
