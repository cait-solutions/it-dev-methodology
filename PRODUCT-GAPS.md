# PRODUCT-GAPS — methodology-platform

Лог **product / feature / capability gaps** — что продукт **не покрывает**, edge cases, non-obvious use cases обнаруженные при разработке или использовании.

> **Отличие от AGENT-GAPS:**
> - AGENT-GAPS = agent's **reasoning** failure (я как агент пропустил, проигнорировал правило, принял ложное assumption)
> - PRODUCT-GAPS = product's **coverage** gap (продукт не имеет функции / use case / edge case)
>
> При сомнении:
> - «причина в том что **Я** не подумал» → AGENT-GAPS
> - «причина в том что **продукт** не умеет» → PRODUCT-GAPS

> **Отличие от IDEAS.md:**
> - IDEAS = raw signal (пользователь сказал «было бы удобно X»)
> - PRODUCT-GAPS = classified gap (с категорией, severity, гипотезой почему не покрыто, предложением fix)
> - Workflow: reviewed IDEAS → если confirmed actionable gap → конвертируется в P-NNN запись

---

## Категории

| Код | Когда применять |
|---|---|
| `feature-gap` | Продукт не имеет функции которая логично должна быть |
| `capability-gap` | Функция есть но не поддерживает определённый use case / data type / scale |
| `ux-gap` | Функциональность есть, но discoverability / readability / flow проблема |
| `integration-gap` | Не интегрируется с tools/services которые типичный пользователь использует |
| `edge-case-gap` | Happy path покрыт, edge case не покрыт (по design / по упущению) |

---

## Severity

| Уровень | Когда |
|---|---|
| 🔴 **High** | блокирует основной use case / часто встречается |
| 🟡 **Medium** | улучшает UX / редкий но известный кейс |
| 🟢 **Low** | edge case / nice-to-have |

---

## Формат записи

```
---
Gap-ID: P-NNN
Дата: YYYY-MM-DD
Контекст: [где обнаружен gap — какая команда / workflow / use case]
Что не покрывает: [конкретно что продукт НЕ делает]
Severity: 🔴 High | 🟡 Medium | 🟢 Low
Категория: feature-gap | capability-gap | ux-gap | integration-gap | edge-case-gap
Use case (затронут): [конкретный сценарий пользователя который страдает]
Сигнал источник: agent observation | user feedback (IDEAS-NNN) | retro pattern | production incident
Гипотеза почему не покрыто: [одна строка — выбор scope / приоритет / архитектурное ограничение]
Potential fix: [предложение что нужно построить чтобы закрыть]
Связано с: [P-NNN другие gap'ы / IDEAS-NNN / ROADMAP-entry / ADR-NNN]
Статус: open | in-roadmap | wont-fix | resolved
---
```

---

## Записи

<!-- Новые сверху -->

### P-001 — `/skill` не имеет авто-триггера: capture проектных наработок опирается на память человека

- **Дата:** 2026-07-02
- **Категория:** `ux-gap` (discoverability самой capability) + `feature-gap` (нет пост-`/code` prompt)
- **Severity:** 🔴 High
- **Контекст:** /plan
- **Симптом (2 инцидента, оба на скриншотах):** (1) erp Party — агент полдня переоткрывал «как подключаться/деплоить/проверять» на ai.nexchance.de, знание не было зафиксировано в skill → вручную зафиксировали в `/how`. (2) DevOps — агент переоткрыл ground-truth «изоляция ai (своя база/api) никогда не существовала, всё через dev-api», чуть не навесил лишнюю работу (паттерн G-045 консьюмера).
- **Что продукт не умеет:** `/skill` существует и корректно создаёт `.claude/skills/<name>/SKILL.md`, но запускается **только если человек вспомнил**. Нет механизма который после `/code`/сессии предложил бы «стоит создать/обновить skill». Actor-burden: капитализация знания зависит от памяти человека — нарушение Оси 1. Плюс `/skill` тянет только `[research:X]` из DEVLOG — не покрывает project ground-truth факты (что реально построено vs миф на бумаге).
- **Гипотеза почему не покрыто:** `/skill` спроектирован как manual synthesis-команда (аналог `/research`), auto-trigger не закладывался; предполагалось что пользователь сам заметит накопление.
- **Предложение fix:** авто-detector после `/code` (Шаг 7) + `/how` при inventory → предлагает `/skill` (create/update) по структурным сигналам (повторное открытие факта, ≥3 [research:X] домена, накопленный ops-flow). Расширить `/skill` на ground-truth facts, не только [research:X]. См. текущий /plan.

(bootstrapped 2026-06-01 — namespace split v4.24.0 применён к methodology-platform)
