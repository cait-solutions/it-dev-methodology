<!-- AUTO-GENERATED from methodology-platform v3.0.0 -->
<!-- Synced: 2026-05-16 -->
<!-- DO NOT EDIT — changes will be overwritten on next sync -->
<!-- Modify via PR to https://github.com/cait-solutions/it-dev-methodology -->
<!-- Emergency override: edit locally + open PR within 48h -->

# /deploy — Деплой с safety checks

**ОБЯЗАТЕЛЬНО:** код в правильной ветке, PR создан/одобрен.

---

## Рекомендуемая модель

**Default tier:** **Fast tier** (см. `.claude/model-tiers.md`) — деплой это чек-листы, structured smoke test, обновление DEVLOG
**Upgrade to Default tier if:** smoke test failed → нужен диагностический анализ; regression detected at after-effects check
**Downgrade:** (всегда Fast — это минимально допустимый)
**Mid-task escalation:** нет (если failed → обычно прерывается и идёт в `/diagnose`)
**Pre-flight model check:** **да — при старте команды** спроси пользователя какая модель активна (или используй ранее подтверждённую в сессии). Если используется Capable (Opus) tier — это over-powered для deploy → пауза + рекомендация Fast/Default для cost-savings.

---

## Навигационная карта шагов

Оси: **project_type** (ai-agent / web-app / api-service / cli-tool / library / methodology-platform) × **наличие миграций** × **наличие selftest** × **затрагиваются ли хранилища**.

| Шаг | ai-agent | web-app | api-service | cli-tool | library | methodology |
|-----|----------|---------|-------------|----------|---------|-------------|
| 0 Review обязателен | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 0.5 Hard blocker на повторный деплой | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 0.7 Pre-flight warnings (triggers.json) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 1 Pre-flight check (ветка, коммиты, tests) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 2 DEVLOG.md запись | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 3 Деплой (procedure-specific) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ (git push) |
| 3.1 Selftest (если есть в проекте) | ✓ | ✓ | ✓ | ✓ | — | — |
| 3.5 Инвалидация после деплоя (если меняются данные) | ✓ | ✓ | ✓ | — | — | — |
| 4 Smoke test — happy path | ✓ | ✓ | ✓ | ✓ | — | — |
| 4 Smoke test — data smoke (если данные) | ✓ | ✓ | ✓ | — | — | — |
| 4 Smoke test — after-effects check (только ai-agent) | ✓ | — | — | — | — | — |
| 5 Обновить triggers.json (last_deploy) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

Прочитай таблицу ПЕРВЫМ. Пропускай шаги не отмеченные для project_type. Для methodology-platform "деплой" = `git push origin main`; smoke test = ручной запуск `new-project-init.sh` + `sync-methodology.sh` на тестовом target.

---

## Шаг 0 — Review обязателен

Запусти `/review` если не запускался в этой сессии. Деплой без review запрещён.

---

## Шаг 0.5 — Hard blocker на повторный деплой

`git log --oneline -5` — сколько деплоев одного компонента за 24 часа?

Если N ≥ 2 → ⛔ ПОЛНЫЙ СТОП. Чтобы разблокировать — явно:
> "Деплой №N по компоненту [X]. Новые диагностические данные: [конкретно что узнали]."

Без признания деплой не выполняется.

---

## Шаг 0.7 — Pre-flight warnings

Прочитать `.claude/state/triggers.json`:

1. `last_product_check.plans_since` ≥ 5 → 🟡 "PRODUCT.md мог разойтись"
2. Дней с `last_deploy.date` ≥ 7 → 🟡 "Накопились изменения с прошлого деплоя"

После успешного деплоя обновить `last_deploy.date`.

---

## Шаг 1 — Pre-flight check

- [ ] Текущая ветка корректна
- [ ] Все изменения закоммичены
- [ ] Self-review пройден
- [ ] Tests зелёные
- [ ] SYSTEM-MAP / data-map / ADR обновлены если применимо

---

## Шаг 2 — DEVLOG.md

Формат записи:

```
YYYY-MM-DD — [тип: deploy|milestone|risk-change] — [компонент]
Что: одна строка
Зачем: одна строка
Решение: одна строка (если архитектурное)
```

- Затрагивает карту данных → обновить в этом же коммите
- Не затрагивает → явно "карта данных не изменилась"

---

## Шаг 3 — Деплой

Покажи что улетит: `git diff HEAD --stat`

Выполни деплой согласно процедуре проекта (CI/CD pipeline или ручной).

---

## Шаг 3.1 — Selftest (если есть)

Если в проекте есть selftest — обязательно после перезапуска.
- Все [critical] должны быть ✅
- Если 🔴 — деплой failed, не продолжать

---

## Шаг 3.5 — Инвалидация после деплоя

- Изменился формат данных в хранилище? → миграция / реиндексация
- Изменилась структура состояния? → reset / cleanup
- Если ничего — явно "инвалидация не требуется"

---

## Шаг 4 — Smoke test (обязательно)

**Основной happy path:**
- [ ] Health check отвечает
- [ ] Основная функция работает согласно acceptance criteria
- [ ] Нет новых ошибок в логах (первые 5 минут)

**Data smoke test** (если менялась работа с хранилищами):
- [ ] Чтение данных работает корректно
- [ ] Запись работает корректно

**After-effects check** (только если `project_type: ai-agent` в CLAUDE.md):
После основного теста — запустить 3 несвязанных запроса:
1. Стандартный запрос
2. Простой вопрос
3. Любая команда не из теста

Что искать:
- Молчание / пустой ответ → ⚠️ возможна state pollution
- Ссылки на данные теста как актуальные → ⚠️ pollution подтверждена
- Странное поведение "из ниоткуда" → инвалидировать состояние

При обнаружении:
- Запись в DEVLOG `[regression:state-pollution]`
- Откатить если критично для UX
- Сценарий воспроизведения в HYPOTHESES.md

---

## После деплоя

Обновить triggers.json:
- `last_deploy.date = <today>`

---

⛔ Если в review были 🔴 CRITICAL — не деплоить.

$ARGUMENTS
