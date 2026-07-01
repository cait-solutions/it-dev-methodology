# /marketing — Навигатор маркетинговых skills

Показывает порядок запуска marketing skills и текущий прогресс заполнения `MARKETING.md`. Не запускает skills автоматически — рекомендует следующий шаг и даёт его активировать.

**Зачем нужна эта команда:** marketing skills auto-активируются по триггерам, но не знают друг о друге. `/marketing` — единственное место где зафиксирован правильный порядок и видно что уже сделано.

---

## Рекомендуемая модель

**Extended (UI settings):** effort: **Low** · thinking: **OFF** (навигация) / **High** · thinking: **ON** (autodraft — генерация из PRODUCT/VISION). См. `.claude/model-tiers.md` § Effort & Thinking.

**Default tier:** Fast (Haiku) — навигация и чтение state, без reasoning-heavy анализа.

**Upgrade to Default (Sonnet) if:**
- Первый запуск на проекте (нет MARKETING.md) — нужен autodraft через product-marketing skill
- Пользователь просит объяснить зачем нужен конкретный skill

**Pre-flight model check:** нет (навигационная команда, не аналитическая).

---

## Слоевая модель

```
VISION.md + PRODUCT.md       ← внутренний слой: что строим, инварианты
         ↓ читается как вход
MARKETING.md                  ← внешний слой: как продаём, кому, против кого
         ↑ пишется marketing skills (только в этом направлении)
```

Marketing skills **читают** PRODUCT.md и VISION.md как контекст, но **никогда не пишут** в них. Изменения идут только в MARKETING.md.

---

## Шаг 1 — Проверить наличие MARKETING.md

```
Если MARKETING.md не существует:
  ⚠️ MARKETING.md не найден.
  Это marketing-слой проекта. Чтобы начать:
    1. Убедись что проект инициализирован с: bash scripts/new-project-init.sh <name> --with-marketing
    2. Или создай MARKETING.md вручную из templates/MARKETING.template.md
    3. Затем запусти skill: product-marketing (первый шаг — autodraft из PRODUCT/VISION)

Если MARKETING.md существует:
  → Перейти к Шагу 2
```

---

## Шаг 2 — Прочитать MARKETING.md и определить прогресс

Прочитать `MARKETING.md`. Для каждой секции — определить статус:
- ✅ Заполнено — секция содержит реальный контент (не заглушку `_Не заполнено_` и не только комментарии `<!-- -->`)
- ⬜ Пусто — секция пустая или только шаблонный placeholder

---

## Шаг 3 — Вывести карту прогресса

Вывести в следующем формате:

```
## Прогресс MARKETING.md

### Foundation block (по порядку)
[статус] product-marketing    → ## Product Context    [breadth V1, autodraft из PRODUCT/VISION]
[статус] define-positioning   → ## Positioning         [углубляет: segment, differentiator, messaging]
[статус] customer-research    → ## ICP & Personas      [углубляет: персоны, JTBD, anti-ICP]
[статус] competitor-profiling → ## Competitor Profiles [углубляет: прямые / косвенные / substitute]

### Execution skills (по необходимости, после Foundation)
[статус] copywriting       → тексты страниц (homepage, лендинги, pricing)
[статус] content-strategy  → контент-план, topic clusters, editorial calendar
[статус] pricing           → тарифы, value metric, packaging
[статус] launch            → запуск продукта (ORB фреймворк, 5 фаз, Product Hunt)
[статус] emails            → email-последовательности, lifecycle emails
[статус] cro               → оптимизация конверсии страниц
[статус] seo-audit         → SEO аудит и диагностика

Execution skills читают Foundation секции как контекст.
Запускай их после заполнения хотя бы ## Positioning.
```

Для каждой Foundation skill — если секция ⬜ Пусто и предыдущие заполнены: пометить **→ рекомендуется следующим**.

---

## Шаг 4 — Рекомендация следующего шага

На основе прогресса определить и вывести:

**Если Product Context пусто (первый запуск):**
```
🚀 Рекомендую начать с: product-marketing
   Что делает: создаёт V1 черновик всего маркетингового контекста
   за один проход — autodraft из PRODUCT.md и VISION.md.
   Это breadth-старт: широкий но неглубокий. Следующие skills углубляют секции.

   Как запустить: напиши "product marketing context" или "маркетинговый контекст"
```

**Если Product Context заполнен, Positioning пусто:**
```
👉 Следующий шаг: define-positioning
   Что делает: углубляет ## Positioning — positioning statement,
   target segment, differentiator, messaging pillars, tagline candidates.

   Как запустить: напиши "позиционирование" или "value proposition"
```

**Если Positioning заполнен, ICP пусто:**
```
👉 Следующий шаг: customer-research
   Что делает: углубляет ## ICP & Personas — primary ICP, JTBD, anti-ICP, персоны.

   Как запустить: напиши "ICP" или "кто наш клиент"
```

**Если ICP заполнен, Competitor Profiles пусто:**
```
👉 Следующий шаг: competitor-profiling
   Что делает: углубляет ## Competitor Profiles — прямые конкуренты,
   косвенные, substitute, наш ответ каждому.

   Как запустить: напиши "конкуренты" или "competitor analysis"
```

**Если Foundation полностью заполнен:**
```
✅ Foundation block завершён. Execution skills доступны по необходимости.

   Наиболее актуальные (запускай когда нужны):
   - copywriting  — пишешь тексты страниц?
   - launch       — готовишься к запуску?
   - pricing      — определяешь тарифы?
   - content-strategy — планируешь контент?
```

---

## Важно: порядок Foundation skills

```
product-marketing  →  define-positioning  →  customer-research  →  competitor-profiling
      breadth V1          depth: positioning       depth: ICP              depth: конкуренты
```

**product-marketing** запускается **первым** и только на чистом/пустом MARKETING.md.
Если запустить после заполнения — спросит подтверждение перед перезаписью.

define-positioning, customer-research, competitor-profiling — углубляют конкретные секции.
Их порядок важен: каждый следующий читает предыдущую секцию как контекст.

Execution skills не зависят от порядка друг относительно друга,
но требуют как минимум заполненного ## Positioning.
---

## Вывод простым языком (обязательно — Plain-language output rule)

Заверши вывод этой команды коротким блоком `## Простыми словами` (2-5 строк): что это значит для пользователя + закрытый итог: либо следующий шаг («Рекомендую X»), либо — если выбор/совета нет — названная развилка с критерием («A если…, B если…»). ⛔ Не голый вопрос. Не выдумывай рекомендацию там где её нет (weakening = нарушение anti-cheat) — понятным языком, без жаргона/меток. Остальной вывод (разбор, метки, детали) оставь как есть — резюме добавляется в конце. См. CLAUDE.md → Plain-language output rule.
