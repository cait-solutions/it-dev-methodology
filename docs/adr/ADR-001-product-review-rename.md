# ADR-001 — Rename /product-review → /ideas-review

| Поле | Значение |
|---|---|
| Статус | **Принят** |
| Дата | 2026-05-17 |
| Ответственные | methodology-platform владелец |
| Связано | [ARTIFACT-MAP](../product/ARTIFACT-MAP.md), [PRODUCT.md](../../PRODUCT.md) |

---

## Контекст

В методологии сосуществуют две команды с похожими именами:

| Команда | Реальная задача | Основной input | Порог |
|---|---|---|---|
| `/product-check` | Проверяет соответствие PRODUCT.md реальному поведению системы | PRODUCT.md + код | ≥5 планов |
| `/product-review` | Обрабатывает накопленные сигналы из IDEAS.md и превращает в решения | IDEAS.md | ≥10 планов |

Обе команды называются `product-*` — читатель вправе ожидать что обе работают с `PRODUCT.md` и проверяют продукт. На практике `/product-review` работает с `IDEAS.md`, а PRODUCT.md обновляет лишь как побочный результат.

Проблемы:
- Путаница при объяснении методологии новым участникам: "product check" vs "product review" — оба звучат как инспекция продукта
- В ARTIFACT-MAP обе команды указаны рядом → неочевидно зачем две похожие команды с разной частотой
- Консьюмеры пропускают `/product-review` полагая что `/product-check` уже покрывает "проверку продукта"

---

## Решения

### 1. Переименовать `/product-review` → `/ideas-review` — РЕШЕНО

**Правило:** команда называется по своему **основному input**, не по output. Основной input `/product-review` — это `IDEAS.md` (накопленные сигналы), не `PRODUCT.md`.

**Почему `/ideas-review`:**
- Точно описывает что команда делает: разбирает очередь IDEAS.md
- Устраняет путаницу с `/product-check`
- Симметрично с другими командами: `/architecture-audit` работает с архитектурой, `/product-check` работает с PRODUCT.md, `/ideas-review` работает с IDEAS.md

**Почему не `/product-review`:**
- "Review продукта" ≠ "разбор очереди IDEAS.md"
- Создаёт ложное ожидание что команда инспектирует продуктовую спецификацию

**Как применять:** при реализации — обновить имя команды во всех местах (см. последствия).

---

### 2. `/product-check` — не переименовывать — РЕШЕНО

**Правило:** `/product-check` остаётся без изменений. Имя точное: команда "проверяет" (check) соответствие spec продукта реальности.

**Почему:** после rename `/product-review` → `/ideas-review` путаница исчезает сама по себе. Дополнительный rename `product-check` увеличил бы migration scope без выгоды.

---

## Последствия

Реализация является **breaking change** — требует отдельного мажор-bump ≥ v4.0.0:

**Файлы к обновлению при реализации:**
- `commands/product-review.md` → переименовать файл + обновить заголовок
- `commands/plan.md` — триггер-секция: `last_product_review` → `last_ideas_review`; текст предложения
- `templates/ARTIFACT-MAP.template.md` — Command Reference, Artifact Reference (IDEAS.md строка: Закрывает)
- `docs/product/ARTIFACT-MAP.md` — те же таблицы
- `templates/triggers.json.template` — ключ `last_product_review` → `last_ideas_review`
- `templates/model-tiers.md` — строка `/product-review` в матрице
- `DEVLOG.md` тег `[product-review]` → `[ideas-review]` в шаблонах
- `PRODUCT.md` — если упоминается
- `docs/architecture/SYSTEM-MAP.md` — если упоминается
- `scripts/new-project-init.sh` — если копирует команду

**Для консьюмеров:**
- Существующие `triggers.json` с ключом `last_product_review` требуют однократной миграции (rename ключа или reset)
- DEVLOG-теги `[product-review]` в уже задеплоенных проектах остаются как есть — не трогать (история)
- Migration инструкция должна быть в DEVLOG и в отдельном `docs/migration/v4-rename-product-review.md`

---

## Влияние на SYSTEM-MAP.md

- [x] Карта будет обновлена в PR реализации (список команд изменится)

---

## Открытые вопросы

Нет. Решение принято, реализация деferred.
