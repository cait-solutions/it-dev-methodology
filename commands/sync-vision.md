# /sync-vision — Двусторонняя сверка vision ↔ реальность

> **Цель:** синхронизировать VISION/ADR с реальностью кода (inbox + OPEN-QUESTIONS + Type C конфликты). Two-way check: vision устарел? код drifts? Обновить VISION.md / RISKS.md / OPEN-QUESTIONS.md. Запускается по триггеру (10+ inbox, 5+ OQ, Type C обнаружен), не регулярно.

Запускается:
- 10+ inbox файлов накопилось
- 5+ записей OPEN-QUESTIONS со status Open
- VISION/ADR не обновлялся 90+ дней при активной разработке
- После большой интеграции inbox
- Триггер из /plan

**ЗАПРЕЩЕНО:** менять файлы автоматически. Только отчёт и рекомендации.

---

## Рекомендуемая модель

**Default tier:** Default tier (см. `.claude/model-tiers.md`)
**Upgrade to Capable tier if:** 10+ inbox файлов И 5+ открытых OQ одновременно; обнаружен Type C конфликт между vision и кодом (требует глубокого анализа)
**Downgrade to Fast tier if:** (не downgrade — конфликтный анализ требует reasoning)
**Mid-task escalation:** нет (single-pass classification A-E + report)
**Pre-flight model check:** **да** — спроси пользователя какая модель активна (или используй ранее подтверждённую в сессии). Если mismatch ≥ 2 ступени — пауза + рекомендация.

---

## Шаг 1 — Inventory источников

- Прочитать VISION.md
- Прочитать все ADR
- Прочитать SKILL.md модулей (если есть)
- Прочитать SYSTEM-MAP.md (если есть)
- Прочитать inbox/ необработанные файлы
- Grep по ключевым понятиям в коде

---

## Шаг 2 — Source validation

Для каждого источника:
- Когда последний раз обновлялся (git blame)
- Подтверждается реальным кодом?
- Источники старше 90 дней без активности — отдельно

---

## Шаг 3 — Cross-reference анализ

Найти расхождения по 5 типам:

**A** — Реальность кода богаче чем описана в vision
**B** — Vision описывает то чего нет в коде
**C** — Vision и код противоречат друг другу
**D** — Источник невалиден (устарел / гипотетический / галлюцинация)
**E** — Vision слишком расплывчат

---

## Шаг 4 — Создание отчёта

`docs/sync-vision-reports/YYYY-MM-DD.md`:

```markdown
# Sync Vision Report YYYY-MM-DD

## Контекст
- Триггер: [какой]
- Источников проверено: N

## Type A — Новое знание для vision (N)
[список с источниками и предложениями обновлений]

## Type B — Tech debt
**Блокирующие (N)**
**Неблокирующие (N)**

## Type C — Конфликты требующие решения PM
[список → ссылки на новые OQ-NNN]

## Type D — Отвергнутые источники
[список → причины отказа]

## Type E — Vision требует уточнения
[список → ссылки на OQ-NNN]

## Рекомендации
- Какие ADR обновить
- Какие новые ADR создать (supersedes pattern)
- Какие inbox файлы переместить в _processed/rejected/
- Что блокирует дальнейшую работу
```

---

## Шаг 5 — Действия

Автоматически (без вопроса):
- Type B блокирующие → запись в RISKS.md
- Type C → создать OQ записи
- Type D → переместить в `inbox/_processed/rejected/`
- Type E → OQ с пометкой "vision-clarification-needed"

Требует подтверждения пользователя:
- Type A → показать предложенные изменения VISION/ADR, спросить: "Применить обновления? (y/n/selective)"

⛔ НЕ меняй VISION/ADR файлы до ответа пользователя.

---

## После завершения

1. Запись в DEVLOG: `[sync-vision] Report YYYY-MM-DD: N type-A, N type-B, N type-C, N type-D, N type-E`
2. В triggers.json: `last_sync_vision = { date: today, plans_since: 0 }`

---

$ARGUMENTS
