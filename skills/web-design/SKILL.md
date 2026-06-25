---
name: web-design
description: "Knowledge-domain skill для создания web-интерфейсов — задаёт bold aesthetic direction, избегает generic решений. Активируй когда: создаётся новый UI, страница, лендинг или компонент с нуля; пользователь спрашивает о дизайне, стиле, теме, цветовой схеме или типографике; начинается переработка существующего интерфейса; цель — сделать интерфейс лучше конкурентов или непревзойдённым по UX (product-quality goal). НЕ активируй при: баг-фикс в одном CSS-свойстве; backend-задача без UI; изменение одного класса в существующем дизайне."
metadata:
  version: 1.1.0
  type: knowledge-skill
  auto_generated: false
  methodology_version: v7.19.6
  synced_at: "{{SYNCED_AT}}"
  source: https://github.com/cait-solutions/it-dev-methodology
  banner: "Synced from methodology-platform v7.19.6 — DO NOT EDIT skill logic directly. Modify via PR to methodology repo."
---
# web-design — Bold Aesthetic Direction для Web-интерфейсов

Этот skill задаёт **aesthetic direction** ПЕРЕД написанием первой строки HTML/CSS. Generic — это ошибка по умолчанию. Каждый интерфейс должен иметь характер.

---

## Шаг 0 — Brand context check (обязательный первый шаг)

**Перед любыми design-решениями** — проверить наличие brand constraints:

```
Проверить (в порядке приоритета):
1. MARKETING.md → секция ## Visual Identity / ## Brand Guidelines / ## Design
2. brand.md (если есть в проекте)
3. PRODUCT.md → секция с описанием стиля/visual tone
```

- **Brand constraints найдены** → design-решения ДОЛЖНЫ соответствовать им. Используй skill как систему координат внутри brand constraints.
- **Ничего не найдено** → полная свобода. Применяй разделы ниже как primary guide.
- **Частичные guidelines** → соблюдай явные constraints; для незаполненных областей — применяй skill.

---

## Шаг 1 — Три вопроса до кода (Pre-code aesthetic definition)

Перед первым CSS-классом задай три вопроса и зафикси ответы. Без этого — generic шаблон, не дизайн.

**Q1. Какую эмоцию должен вызвать этот интерфейс у пользователя за первые 3 секунды?**
> Не "хороший" или "профессиональный" — это нули. Конкретная эмоция: любопытство, уверенность, желание купить, страх упустить, чувство премиума, игривость.

**Q2. Если бы этот продукт был брендом одежды — что это?**
> Massimo Dutti (строгий, тёмный, минималистичный) · Supreme (агрессивный, limited, дефицит) · Gentle Monster (avant-garde, художественный) · Hermès (ультра-премиум, сдержанный) · Glossier (нежный, пастельный, gen-Z).
> Этот вопрос вытаскивает tone-of-voice когда слова заканчиваются.

**Q3. Что ТОЧНО не должен делать этот интерфейс?**
> "Не выглядеть как SaaS-шаблон с Tailwind" · "Не быть скучным корпоративным синим" · "Не выглядеть как из 2015" · "Не быть агрессивно-продающим". Negative constraint — часто более точный компас, чем positive direction.

---

## Шаг 2 — Выбор aesthetic direction

Выбрать ONE dominant direction (не смешивать два — это размывает характер).

### Примеры directions (открытый список — не закрытый enum):

**Dark & Editorial**
Тёмный фон (#0a0a0a → #1a1a1a), крупная bold-типографика на первом экране, большие негативные пространства. Читается как журнал Vogue или лукбук luxury-бренда. Применимо: premium SaaS, portfolio, fashion e-commerce, crypto/web3.

**Geometric Brutalism**
Жёсткие сетки, острые углы, высококонтрастные чёрно-белые блоки с одним цветным акцентом. Текст как архитектурный элемент. Применимо: архитектурные студии, design agencies, NFT, developer tools.

**Warm Minimal**
Кремовые/бежевые тона (#f5f0e8, #ede8df), serif-типографика с засечками, натуральные текстуры. Ощущение осязаемости, ручной работы, аутентичности. Применимо: food/beverage, wellness, handmade/craft, organic beauty.

**Neon Cyberpunk**
Тёмный (#080808) + неоновые акценты (lime #39ff14, cyan #00ffff, hot pink #ff006e), monospace-шрифты, glitch-эффекты, scanlines. Применимо: gaming, tech startups, esports, crypto degen.

**Swiss / International**
Чистая типографическая сетка, sans-serif с идеальным кернингом, минимум декора, функциональность = эстетика. Применимо: B2B SaaS, финтех, медицина, enterprise.

**Surreal / Dreamlike**
Gradient meshes с неожиданными цветами, overlapping elements, organic shapes, почти иллюстративный стиль. Применимо: creative agencies, AI/ML products, generative art, NFT drops.

**High-Contrast Editorial**
Белый + чёрный + один яркий цвет-акцент (flame orange, electric blue, acid green). Крупный headline на весь экран, минимум элементов. Применимо: magazines, events, launches, одностраничные лендинги.

> Новые directions добавляй по аналогии — список намеренно открытый (тренды меняются каждые 18 месяцев).

---

## Шаг 3 — Типографика

**Правило первое: избегай по умолчанию**

❌ Inter — слишком нейтральный, стал default для любого SaaS
❌ Roboto — корпоративный Google-стиль
❌ Arial — legacy, нет character
❌ Space Grotesk — перекопирован в 2022-2024

**Вместо этого — выбирай по character:**

| Если direction... | Шрифты для рассмотрения |
|---|---|
| Dark Editorial | Cormorant Garamond, Playfair Display, Canela, Editorial New |
| Geometric Brutalism | Neue Haas Grotesk, ABC Monument Grotesk, DM Sans Bold |
| Warm Minimal | Lora, Freight Text, Instrument Serif, Tiempos Text |
| Swiss / Technical | Aktiv Grotesk, Geist, IBM Plex Sans, Söhne |
| Neon / Tech | JetBrains Mono, Fira Code, Fragment Mono |
| Surreal / Creative | Clash Display, Syne, Satoshi, General Sans |

**Правило второе: 2 шрифта максимум**
1 семейство для заголовков (характер), 1 для body (читаемость). Смешивать 3+ = хаос без причины.

**Правило третье: типографический контраст**
Разрыв между h1 и body должен быть заметным: h1 = 72px+, body = 16-18px. Промежуточные размеры (h2-h4) — с шагом ≥ 1.4x.

---

## Шаг 4 — Цвет и тема

**Доминирующая палитра: максимум 3 роли**

- 1 основной (60% площади) — фон или primary surface
- 1 вторичный (30%) — текст или secondary surface
- 1 акцентный (10%) — CTA, highlights, hover states

**Правило акцента:**
Акцент должен быть ОСТРЫМ — не тот же оттенок основного, а контрастный. Если основной тёмный → акцент яркий и тёплый (amber, lime, hot pink). Если основной светлый/кремовый → акцент тёмный и насыщенный (deep navy, charcoal, forest green).

**Никогда:**
❌ Синий (#4f46e5 или similar) по умолчанию без обоснования — SaaS cliché
❌ Серый фон (#f9fafb, #f3f4f6) + синяя кнопка — это шаблон, не дизайн
❌ Множество оттенков серого — визуальная каша без hierarchy

---

## Шаг 5 — Пространство и композиция

**Asymmetry как инструмент:**
Симметричные лэйауты безопасны, но скучны. Сдвинь заголовок влево с большим правым margin. Overlapping элементов (текст на изображении, карточка поверх блока) создаёт глубину.

**Diagonal rhythm:**
Небольшой наклон секций (-3deg или clip-path) делает страницу живой и break из прямоугольного паттерна.

**Negative space как элемент дизайна:**
Большой пустой white/dark space вокруг ключевого элемента = сигнал "это важно". Не заполняй каждый пиксель.

**Правило первого экрана (hero):**
1 доминирующий элемент (заголовок ИЛИ изображение) + максимум 2 поддерживающих. Если их 5+ — ни один не доминирует.

---

## Шаг 6 — Texture и Depth

**Subtle texture = жизнь:**
Абсолютно flat и однородные поверхности выглядят как wireframe. Добавь:
- Grain overlay (opacity 3-8%) — аналоговое ощущение
- Gradient mesh (2-3 мягких цвета) — вместо flat-color фона
- Micro-shadow (0 2px 4px rgba(0,0,0,0.08)) — карточки с жизнью

**Hover states с character:**
Hover — это не просто opacity или cursor change. Это момент "интерфейс живой":
- scale(1.02) + subtle shadow elevation
- Underline animation (width 0% → 100%)
- Background color wash с transition 200ms

---

## Никогда не создавай (Never-create list)

❌ **Generic hero с stock photo и синей кнопкой** — anti-pattern, не стартовая точка. Если нет оригинального визуала — используй типографику как визуальный hero.

❌ **Card grid с одинаковыми серыми карточками** — без visual hierarchy между ними. Хотя бы одна featured-card должна быть крупнее, другого цвета или с другим layout.

❌ **Цветовые схемы "взятые из Tailwind по умолчанию"** (gray-50 фон, indigo-600 кнопки) — выбирай custom palette под direction, не из utility-класса.

❌ **Typography без character** — если заголовок выглядит как системный шрифт браузера, дизайна нет. Шрифт — первое что замечают.

---

## Границы (что этот skill НЕ делает)

- Не заменяет UX-исследование и user testing
- Не принимает решения по функциональности (это /plan)
- Не работает с backend без UI — проверь наличие frontend-файлов перед активацией
- Не навязывает direction при CSS-баг-фиксе в одном свойстве — проверь: задача меняет одно свойство? Skill неактуален
- Не выбирает за пользователя когда brand constraints противоречат aesthetic direction — фиксируй конфликт явно и жди решения
