# /product-review — Продуктовый анализ сигналов

Запускается по триггеру из /plan или вручную раз в 14 дней.

---

## Рекомендуемая модель

**Default tier:** Default tier (см. `.claude/model-tiers.md`)
**Upgrade to Capable tier if:** 20+ unreviewed IDEAS за период (нужно искать паттерны через большой набор сигналов)
**Downgrade to Fast tier if:** < 5 IDEAS — короткий обзор, ничего глубокого
**Mid-task escalation:** нет (single pass: анализ IDEAS → 5-7 предложений)
**Pre-flight model check:** **да** — спроси пользователя какая модель активна (или используй ранее подтверждённую в сессии). Если mismatch ≥ 2 ступени — пауза + рекомендация.

---

## Подготовка

Прочитать:
1. **IDEAS.md** — raw signals (сырые сигналы, пользователь сказал «было бы удобно»)
2. **PRODUCT-GAPS.md** (если существует) — classified product gaps (P-NNN записи: feature/capability/ux/integration/edge-case с severity)
3. DEVLOG.md — записи за последние 14 дней
4. VISION.md — активные оси (если есть)

Два artefakta signal:
- **IDEAS** = raw → пользователь делает observation, нет structure
- **PRODUCT-GAPS** = classified → structured gap с severity / категорией / гипотезой почему не покрыто / potential fix

Workflow: reviewed IDEAS → если confirmed actionable gap → конвертируется в новую P-NNN запись в PRODUCT-GAPS.md → в `/product-review` сортируется по severity → попадает в ROADMAP.

Если оба пусты (IDEAS + PRODUCT-GAPS) → "IDEAS.md и PRODUCT-GAPS.md не заполнены. Анализ невозможен без данных."

---

## Четыре вопроса

**1. Friction patterns:** что пользователь делает руками что могло быть автоматическим?
- Сигнал: одна команда в IDEAS.md ≥ 3 раза за период

**2. Discovery gaps:** какие функции есть но пользователь не использует?
- Сигнал: фича в DEVLOG, не используется неделями после деплоя

**3. Visibility gaps:** что происходит внутри что пользователь не видит?
- Сигнал: записи "я не знал что..." в IDEAS.md

**4. Natural extensions:** какие 2-3 фичи естественно вырастают из паттернов использования?
- Привязка к конкретным сигналам, не абстракции

---

## Формат вывода

5-7 конкретных предложений. Каждое:

- **Приоритет:** High / Medium / Low
- **Тип:** friction / discovery / visibility / extension
- **Предложение:** конкретное действие (не "улучшить UX" — а "добавить подтверждение в /add с количеством сохранённых")
- **Обоснование:** привязка к данным ("в IDEAS.md 2026-04-24: пользователь спрашивал 'добавилось ли' после /add 4 раза")
- **Риски** (обязательно для High/Medium): 2-3 конкретных риска
- **Ось** (если применимо): на какую ось VISION работает

❌ Запрещено: предложения без привязки к конкретным данным
❌ Запрещено: High/Medium без блока "Риски"

---

## После анализа

Спросить: "Перенести High-приоритетные в ROADMAP.md → Considered? (y/n)"
Не переносить самостоятельно — ждать ответа пользователя.

**Дополнительно: IDEAS → PRODUCT-GAPS classification**

Если в этом /product-review были reviewed IDEAS которые описывают **product coverage gap** (а не workflow friction) — спросить:

```
📋 Reviewed IDEA [IDEA-описание] описывает product coverage gap.
   Конвертировать в PRODUCT-GAPS запись P-NNN? (y/n)
   - Категория: [feature-gap | capability-gap | ux-gap | integration-gap | edge-case-gap]
   - Severity: [🔴 High | 🟡 Medium | 🟢 Low]
   - Use case (затронут): [конкретный сценарий]
```

При `y` — создать P-NNN запись в PRODUCT-GAPS.md, в IDEAS пометить `[reviewed:converted-to-P-NNN]`.

Обновить triggers.json: `last_product_review = { date: today, plans_since: 0 }`

---

$ARGUMENTS
