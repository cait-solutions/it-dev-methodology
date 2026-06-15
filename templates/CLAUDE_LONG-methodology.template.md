# CLAUDE_LONG.md — {{Project Name}}

Полный контекст методологических правил с обоснованием. Парный файл к [CLAUDE.md](CLAUDE.md):
- CLAUDE.md = WHAT (rules, MUST/MUST NOT, scan-friendly, auto-loaded)
- CLAUDE_LONG.md = WHY (rationale, edge cases, examples)

---

## Обязательно перед началом работы

[Add rationale: зачем читать VISION.md/PRODUCT.md/SYSTEM-MAP.md перед каждым /plan]

---

## Архитектура

Методология состоит из 5 слоёв:

| Слой | Где живёт | Кто меняет |
|---|---|---|
| **Команды** (slash commands) | [commands/](commands/) | Только владелец методологии |
| **Шаблоны артефактов** | [templates/](templates/) | Только владелец методологии |
| **Хуки защиты** | [templates/.claude/hooks/](templates/.claude/hooks/) | Только владелец методологии |
| **Скелеты агентов** | [templates/.claude/agents/](templates/.claude/agents/) | Только владелец методологии |
| **Скрипты доставки** | [scripts/](scripts/) | Только владелец методологии |

Консьюмеры (другие проекты) получают банер-prefixed копии через `scripts/sync-methodology.sh`. Они **не редактируют** доставленные файлы — только PR в этот репо.

[Add: описание решения о разделении на канон и производные; historical context]

---

## Стек

[Add rationale: почему Bash 3.2+, почему Python 3.10+, почему ручной CI/CD]

---

## Карта данных (полная)

В отличие от обычных проектов, методология не имеет runtime БД. "Хранилища" — это слои репо.

| Слой | Что хранит | Источник правды | Кто пишет | Кто читает | Инвалидация |
|---|---|---|---|---|---|
| `commands/*.md` | Slash-команды (канон) | да | владелец методологии | bootstrap, sync, `/review` в консьюмерах | при правке + push |
| `templates/*.md` | Шаблоны артефактов | да | владелец | bootstrap | при правке + push |
| `templates/.claude/hooks/*.py` | Универсальные защитные хуки | да | владелец | bootstrap + sync | при правке + push |
| `templates/.claude/agents/*.template.md` | Скелеты sub-agents | да | владелец | bootstrap (только для новых проектов) | редко — body per-project |
| `VERSION` | Semver методологии | да | владелец | оба скрипта (для баннера и `.version` пойнтера) | при ручном bump |
| `.claude/` (этот репо) | Self-application копия | нет (производное) | `sync-methodology.sh .` | Claude Code | при `sync-methodology.sh .` |
| Консьюмер `.claude/commands/*.md` | Баннер-prefixed копия | нет (производное) | `sync-methodology.sh` | Claude Code в консьюмере | при следующем sync |

**Инварианты:**
- `commands/`, `templates/` — единственный источник правды. `.claude/` (и любая копия в консьюмере) — производное.
- Перед коммитом правок в `.claude/commands/*.md` — отверни: исходник в `commands/*.md`. Никогда не оставляй расхождение.
- Любая правка в синхронизируемом артефакте → bump VERSION (минорный для additive, мажорный для breaking).

[Add: исторические примеры trade-offs этой схемы]

---

## Сила регуляторов поведения (Level-4 framework) — расширенно

[Add rationale for the 6 levels; historical example of level-1 vs level-4 fix]

1. **Правило в командном тексте** — слабо, дрейфует.
2. **Description инструмента / агента** — учитывается слабо.
3. **Few-shot примеры в команде** — средне, дрейфуют.
4. **Структура шаблона** (что физически попадает в проект через bootstrap) — сильно.
5. **Отсутствие альтернативы** (одна команда для задачи, нет дубля) — очень сильно.
6. **Schema constraint** (валидация в скрипте, banner-check в sync) — гарантия.

**Правило:** при добавлении правила в методологию — спросить "есть ли level-4+ структурный фикс?". Если есть — он primary. Правило — secondary документация.

---

## Don'ts (что НЕЛЬЗЯ) — расширенно

[Add: конкретные примеры нарушений каждого Don't и что произошло]

---

## Реализация через /code — расширенно

[Add: исторические примеры почему прямая правка опасна; когда исключения OK]

---

## Deploy rule — расширенно

[Add: исторические инциденты при нарушении deploy rule; почему ручной CI/CD — преднамеренное решение]

---

## Architecture decision rule — расширенно

[Add: примеры решений где architect sub-agent выявил non-obvious risks]

---

## Fix rule — расширенно

[Add: исторические примеры локальных фиксов ставших системными проблемами]

---

## Model tier rule — расширенно

Каждая команда методологии обязана содержать секцию `## Рекомендуемая модель` с 5 полями: Default tier / Upgrade to Capable / Downgrade to Fast / Mid-task escalation / Pre-flight model check.

Канонический реестр tier-mapping и per-command матрица — в [.claude/model-tiers.md](.claude/model-tiers.md) (методологический источник: [templates/model-tiers.md](templates/model-tiers.md)).

При добавлении новой команды — обязательно (1) добавить строку в per-command матрицу `model-tiers.md`, (2) включить секцию "Рекомендуемая модель" в начало command-файла. Без этого команда **не принимается** в методологию (`/review` блокирует merge).

[Add: rationale for pre-flight check asking user vs self-detect; examples of model mismatch incidents]

---

## DEVLOG теги — расширенно

[Add: полный список тегов с примерами; правило semantic tagging с примерами surface name vs semantic indicator]

---

## Реальные угрозы безопасности — расширенно

**Утечка GitHub PAT:**
[Add: mitigation scenario and monitoring approach]

**Прямой push в main:**
[Add: concrete scenario when this caused problems; planned branch protection setup]

**Drift между методологией и консьюмерами:**
[Add: example of drift impact on consumer projects; planned auto version-drift check]

**Sync overwrites local fills (Mitigated v6.4.1 — managed-block):**
`docs_reminder.py` имеет per-project fill — `LIBS: dict` заполняется консьюмером (URLs на документацию библиотек). До v6.4.1 `sync-methodology.sh` перезаписывал файл целиком (OVERWRITE-режим), молча уничтожая fill консьюмера.

**Фикс — MANAGED-BLOCK (4-й режим taxonomy в `sync-methodology.sh`):**
Методология пишет только между markers `# >>> methodology managed >>>` … `# <<< methodology managed <<<`. Fill-зона (`LIBS = {}`) находится ВНЕ markers и физически не трогается на sync.

**Fail-safe:** если dest существует без markers (pre-managed-block fill) → sync НЕ перезаписывает файл, выводит предупреждение и направляет в `/sync-audit` Gap 18. Gap 18 показывает текущий fill и предлагает безопасно добавить markers (аналог Gap 14 write-only паттерна).

**Marker-синтаксис (Python):**
```
# >>> methodology managed >>>
# DO NOT EDIT inside these markers — overwritten on sync.
import sys
...
# <<< methodology managed <<<
```

**Распространение режима:** добавить файл в список `MANAGED_BLOCK_HOOKS` в `sync-methodology.sh` + разметить template markers — расширяется одной строкой без переписывания helper-а.

---

## Ключевые файлы / точки входа — расширенно

- [scripts/new-project-init.sh](scripts/new-project-init.sh) — bootstrap нового проекта
- [scripts/sync-methodology.sh](scripts/sync-methodology.sh) — обновление существующего проекта
- [commands/plan.md](commands/plan.md) — entry point всего workflow для консьюмеров
- [templates/triggers.json.template](templates/triggers.json.template) — каноническая схема state
- [VERSION](VERSION) — semver методологии

---

## Внешние ссылки

- GitHub: {{github-url}}
- Консьюмер-проекты:
  - [Add: список проектов использующих эту методологию]
