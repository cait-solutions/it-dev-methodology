# /onboard — Адаптация нового разработчика

Для новых разработчиков и для передачи легаси домена под Claude Code.

---

## Рекомендуемая модель

**Default tier:** Default tier (см. `.claude/model-tiers.md`)
**Upgrade to Capable tier if:** legacy domain handover с risk map для AI-агента (требует глубокого анализа существующего кода чтобы определить Forbidden / Approval-required операции)
**Downgrade to Fast tier if:** new developer mode — pure reading walkthrough, без анализа
**Mid-task escalation:** нет (single-pass — либо подготовка onboarding документации, либо создание SKILL.md из кода)
**Pre-flight model check:** **да** — спроси пользователя какая модель активна (или используй ранее подтверждённую в сессии). Если mismatch ≥ 2 ступени — пауза + рекомендация.

---

## Шаг 0 — Контекст запуска

Эта команда работает в **двух типах проектов**:

- **Consumer-проект** (ERP, бот, сервис) — онбординг разработчика на конкретный продукт
- **it-dev-methodology** — онбординг в саму методологию разработки

В обоих случаях шаги одинаковые — разница только в содержимом артефактов.

**Workspace check (для new-developer):**
Прежде чем читать README — убедись в правильной настройке:
- [ ] Открыт `<project>-documentation/` как workspace root в Claude Code (не родительская папка, не `it-dev-methodology`)?
- [ ] Команды доступны? (в Claude Code должно работать `/plan`)
- [ ] Если команд нет → запусти `sync-methodology.sh` из `it-dev-methodology` (см. README.md раздел "После git clone")

**USER-MAP check:**
- [ ] Открыть `docs/product/USER-MAP.md`
  - Файл отсутствует → ⚠️ USER-MAP не создан. Запусти `new-project-init.sh` или создай вручную из шаблона.
  - Найдены `[TODO: ...]` маркеры → ⚠️ USER-MAP не заполнен. Заполни перед началом работы (шаблон: `templates/USER-MAP.template.md`).

**Branching check:**
- [ ] Открыть `CLAUDE.local.md` → секция `## Branching`
  - Секция отсутствует → ⚠️ branching mode не задан, используются defaults (`mode: solo`, `agent_branch: ai-dev`). OK для solo-проектов.
  - `mode: team` — убедись что `integration_branch` заполнен И branch protection настроен в GitHub/GitLab на `production_branch`
  - Разъясни новому разработчику: он работает в `feature/*` ветках; AI-агент работает в `agent_branch` (default `ai-dev`); PR review — его задача

---

## Навигационная карта шагов

Два режима — выбирается по контексту запроса.

| Шаг | new-developer | legacy-handover |
|-----|---------------|------------------|
| Чтение README.md | ✓ | — |
| Чтение CLAUDE.md | ✓ | ✓ (для контекста инвариантов проекта) |
| Чтение docs/glossary.md | ✓ | ✓ |
| Чтение docs/VISION.md (или AGENT_VISION) | ✓ | ✓ |
| Чтение SYSTEM-MAP.md | ✓ | ✓ (для понимания где домен в графе) |
| Чтение одной команды (plan.md) | ✓ | — |
| Чтение фундаментальных ADR | ✓ | ✓ (релевантных домену) |
| Реальный код домена (entry points → services → models → events) | — | ✓ |
| Создание SKILL.md из реального кода | — | ✓ |
| Создание .ownership файла | — | ✓ |
| Risk map для AI-агента (3 уровня: requires-approve / forbidden / safe-autonomous) | — | ✓ |
| Параллельные пути в коде (для class-bug awareness) | — | ✓ |
| Финальный тикет — /plan → /code → /review (для new-developer) | ✓ | — |

Прочитай таблицу ПЕРВЫМ. Выбери режим:
- **new-developer:** первый день, ~2 часа. Знакомство с проектом и workflow.
- **legacy-handover:** передача существующего домена под AI-агента. Создание SKILL.md.

---

## Для нового разработчика (первый день, ~2 часа)

0. **Workspace setup** (если ещё не сделано — см. Шаг 0 выше) — 5 мин
1. Прочитай README.md (структура, три репозитория, workflow) — 15 мин
2. Прочитай CLAUDE.md (операционные правила) — 15 мин
3. Прочитай docs/glossary.md (термины) — 10 мин
4. Прочитай docs/VISION.md (куда идём) — 10 мин
5. Прочитай docs/architecture/SYSTEM-MAP.md (как компоненты связаны) — 10 мин
6. Посмотри одну команду целиком: `.claude/commands/plan.md` — 20 мин
7. Прочитай фундаментальные ADR (ADR-001, ADR-002 или аналоги проекта) — 30 мин

После — взять простой тикет и пройти `/plan` → `/code` → `/review`.

Если читается > 2 часов — что-то слишком длинное, упростить.

---

## Для передачи легаси домена

Цель — создать SKILL.md из реального кода, не из vision.

1. **Прочитай реальный код:**
   - Точки входа (routes, controllers)
   - Бизнес-логика (services)
   - Модели данных (schema, tables)
   - События / интеграции

2. **Создай SKILL.md:**
   - Что делает домен (1 абзац)
   - Источник правды для каких данных
   - Какие события публикует
   - Какие события слушает
   - Внешние интеграции
   - Известные ограничения / tech debt

3. **Создай .ownership файл** (из шаблона `templates/.ownership.template`)**:**
   - Кто владелец домена
   - Кто контрибьюторы
   - Контакт для вопросов

4. **Risk map:**
   - Где агент может навредить (миграции, удаления)
   - Что НЕ делать без явного approve
   - Где есть параллельные пути в коде

---

$ARGUMENTS
