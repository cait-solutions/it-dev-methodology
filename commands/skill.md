# /skill — Создание domain-specific skill из накопленных наработок

Цель: структурировать operational knowledge этого проекта в reusable SKILL.md, который Claude Code обнаруживает автоматически при следующей сессии в этом проекте.

Skill создаётся в `.claude/skills/<name>/SKILL.md` — выживает после sync by-construction: `sync-methodology.sh` итерирует только `skills/` (канон методологии), не удаляет consumer-local файлы в `.claude/skills/`.

**Чем `/skill` отличается от `/research`:**

| | `/research` | `/skill` |
|---|---|---|
| Output | Одна строка `[research:X]` в DEVLOG | Структурированный SKILL.md файл |
| Активация | Ручное чтение DEVLOG | Auto-activation Claude Code при следующей сессии |
| Гранулярность | Один вывод | Весь domain (собирает все [research:X] домена) |
| Когда | После открытия одного факта | После накопления ≥3 фактов одного домена |

---

## Рекомендуемая модель

**Extended (UI settings):** effort: **High** · thinking: **ON** — синтез накопленных [research:X] + структурирование domain knowledge требует reasoning. См. `.claude/model-tiers.md` § Effort & Thinking.

**Default tier (Sonnet):** синтез контекста + структурирование skill достаточно.
**Upgrade to Capable:** если domain очень широкий (≥10 research entries разных типов) и нужна сложная классификация.
**Fast tier:** ❌ — синтез требует reasoning.
**Mid-task escalation:** нет.
**Pre-flight model check:** не требуется — команда не критичная по модели.

---

## Аргументы

```
/skill <описание фокуса skill>
/skill <описание> --scope portfolio
```

| Аргумент | Описание |
|---|---|
| `<описание>` | Фокус skill: что упаковываем (e.g. «поиск контактов DE с учётом наших наработок и валидации email») |
| `--scope portfolio` | Skill предназначен для агрегации через `/pull-consumers` Ось 7 Layer 2 (дефолт: `local`). ⚠️ Layer 2 агрегация — планируется, пока не реализована. Сейчас `portfolio` только маркирует skill — поведение идентично `local`. |

---

## Шаг 0 — Pre-flight

1. **Определить doc_repo_path:** прочитать `CLAUDE.local.md → doc_repo_path`. Если `null` или отсутствует → DEVLOG в корне проекта.

2. **Проверить `.claude/skills/`:** если не существует → создать:
   ```bash
   mkdir -p .claude/skills/
   ```

3. **Scope:** если передан `--scope portfolio` → `SCOPE=portfolio`, иначе `SCOPE=local`.

4. **Project name:** определить из `basename $(pwd)` (без `-documentation` суффикса если есть).

---

## Шаг 1 — Чтение контекста проекта

Прочитать накопленный operational knowledge этого проекта из четырёх источников:

### 1.1 DEVLOG [research:X] записи (research-выводы)

Прочитать `<doc_repo_path>/DEVLOG.md` (или `DEVLOG.md` если single-repo). Найти все строки вида `[research:<slug>]`:

```
Извлечь из DEVLOG: slug, что изучалось, вывод, verdict, дату, source
Фокус: только выводы релевантные описанию из аргументов
```

Сформировать список findings с полями: `slug`, `что изучалось`, `вывод`, `verdict` (viable/not-viable/blocked/confirmed/conditional/unclear), `дата`, `source`.

### 1.1b DEVLOG [fix:X] / [infra:X] / [deploy] записи (project ground-truth)

⚠️ **Ground-truth ≠ research.** research = «что я изучил» (внешние факты). Ground-truth = **«как проект РЕАЛЬНО устроен»** — что построено vs что только план на бумаге, рабочие команды подключения/деплоя/проверки, verified endpoints/paths. Именно этот тип знания переоткрывают дороже всего (canonical: erp «как деплоить на ai.nexchance.de» — полдня; DevOps «изоляция ai-api никогда не строилась, всё через dev-api» — чуть не навесили лишнюю работу).

Прочитать те же DEVLOG-строки, но с тегами `[fix:<slug>]`, `[infra:<slug>]`, `[deploy]`. Извлечь **операционные факты** релевантные домену из аргументов:
- **Рабочие команды** — как подключиться / задеплоить / проверить (verified, не предположение).
- **Что построено vs миф** — какие компоненты/пути реально существуют, а какие «план на бумаге который не построили».
- **Verified endpoints / paths** — рабочий путь (напр. `dev-api`), НЕ рабочий/мёртвый (напр. `ai-api` если оказался мёртвым).

Сформировать список ground-truth фактов с полями: `факт`, `verified?` (да/нет + как проверено), `дата`, `source` (`[deploy]`/`[fix:slug]`). Фокус: только релевантное описанию из аргументов.

### 1.2 project-context.md (если существует)

Проверить и прочитать `.claude/rules/project-context.md` — секции `## Domain knowledge` и `## Operational constraints` (если есть).

### 1.3 Memory файлы (опционально)

Memory файлы machine-local (`C:\Users\...\memory\` или аналог). Если пользователь упомянул specific memory file — прочитать как дополнительный контекст. Агент НЕ ищет memory автоматически (пути машинно-специфичны).

**После чтения:** показать пользователю краткий список найденных findings (research + ground-truth раздельно) перед Шагом 2.

---

## Шаг 2 — Уточнение с пользователем

### 2.1 Показать найденные findings

```
📋 Найдено N operational findings релевантных «<описание>»:
  1. [research:ddg-scraping] DDG банит при bulk-запросах — not-viable (2026-06-XX)
  2. [research:iproyal-smtp] iproyal не работает для SMTP — not-viable (2026-06-XX)
  3. [research:gelbeseiten-yield] gelbeseiten ~58% email yield — confirmed (2026-06-XX)
  ...

Включить все? (y / укажи номера через пробел / исключи через -N)
```

### 2.2 Предложить имя skill (slug)

Из описания аргумента — предложить kebab-case slug. Пример: «поиск контактов DE и валидация email» → `de-email-enrichment` **(рекомендуется)**.

```
Имя skill (slug, kebab-case): de-email-enrichment ← рекомендуется
Другое имя: ___
```

### 2.3 Проверить существование

Если `.claude/skills/<slug>/SKILL.md` уже существует:
```
⚠️ .claude/skills/<slug>/SKILL.md уже существует.
   (y = перезаписать / n = ввести другое имя / u = обновить — добавить новые findings)
```

---

## Шаг 3 — Структурирование knowledge

Агент формирует содержимое SKILL.md на основе выбранных findings:

### Frontmatter (обязательный формат для local skills)

```yaml
---
name: <slug>
description: >
  Domain knowledge для <краткое описание области>.
  Активируй когда: <trigger keywords через запятую — ключевые слова задачи>.
  НЕ активируй при: <anti-triggers — задачи где skill не нужен>.
metadata:
  type: domain-knowledge-local
  scope: <local|portfolio>
  created: <YYYY-MM-DD>
  project: <project-name>
---
```

⛔ **Не добавлять** `banner:`, `synced_at:`, `methodology_version:` — эти поля только у синкаемых skills.

### Body (структурированное)

```markdown
# <Название> — Operational Playbook

> Создан `/skill` <дата>. **Freshness:** перечитать при изменении pipeline / инфраструктуры / рабочих команд. Ground-truth ниже — снимок на дату создания: если endpoint/путь/команда изменились — обнови (иначе skill станет тем же «планом на бумаге», который призван развеять). Проверяй перед доверием фактам старше ~90 дней.
> Источник: [research:X] + [fix/infra/deploy] записи в DEVLOG + сессионные наработки.

## Что работает

| Источник / Подход | Результат | Примечание | Дата |
|---|---|---|---|
| <name> | <yield/%/verdict> | <из [research:slug]> | <YYYY-MM-DD> |

## Что НЕ работает / Ограничения

- **<ограничение>** — <механизм почему не работает>. `[Source: <url|direct-experience> <дата>]`

## Ground truth — что реально построено (из [fix/infra/deploy])

> Заполнять ТОЛЬКО verified-фактами. Если факт не проверен — пометь `⚠️ не verified` или не включай. Этот раздел закрывает дорогой класс «новая сессия переоткрывает как устроен проект».

**Рабочие команды (verified):**
```
<подключение / деплой / проверка — реальная команда, verified <дата>>
```

**Что построено vs план на бумаге:**
- ✅ **Построено:** <компонент/путь который реально существует и работает>
- ❌ **Миф / не построено:** <«план на бумаге который не построили» — напр. изоляция X никогда не существовала>
- 🔀 **Рабочий путь:** <verified endpoint/path, напр. dev-api> · **Мёртвый:** <напр. ai-api>

## Архитектура (если pipeline)

<описание из наработок если применимо>

## Когда использовать этот skill

- <конкретный пример задачи 1>
- <конкретный пример задачи 2>

## Связанные записи в DEVLOG

- `[research:<slug>]` — <краткий summary>
- `[fix:<slug>]` / `[infra:<slug>]` / `[deploy]` — <ground-truth факт>
```

---

## Шаг 4 — Запись файла

```bash
mkdir -p .claude/skills/<slug>
```

Записать через Write tool: `.claude/skills/<slug>/SKILL.md` с финальным содержимым из Шага 3.

> ⚠️ **Skill = исполняемый код, не только текст.** Если skill несёт **bundled-скрипты** (`.py` / `.sh` / бинарь рядом с SKILL.md) — они выполняются с правами агента. Такой код проходит **ту же проверку, что обычный код** (`/review` + secrets-guard hook), не пропускается как «просто инструкция». У нас skills **внутренние** (вводит только мейнтейнер — нет установки внешних skills), поэтому это **напоминание-осознанность**, не аудит-гейт: при добавлении bundled-исполняемого — отнестись к нему как к коду.

---

## Шаг 5 — Confirmation

После записи показать:

```
✅ Skill создан: .claude/skills/<slug>/SKILL.md

   Auto-activation: Claude Code обнаружит skill автоматически при следующей сессии.
   Путь .claude/skills/ — стандартный путь загрузки skills платформой.

   scope: <local|portfolio>
```
Если `local`:
```
   Только этот проект. Не синкается другим консьюмерам.
   Sync-safe: sync-methodology.sh не затронет этот файл.
```
Если `portfolio`:
```
   Маркирован scope: portfolio — будет агрегирован через /pull-consumers при Ось 7 Layer 2.
   ⚠️ Агрегация пока не реализована (Layer 2 = planned). Сейчас поведение = local.
```
```
   Activation triggers (из description): <список ключевых слов из frontmatter>

   Рекомендуется: если появятся новые [research:X] по этому домену —
   запусти /skill снова с флагом update чтобы обновить skill.
```

---

## Когда использовать /skill

- После длинной execution-сессии с pipeline (lead-gen, data enrichment, scraping, multi-step workflow)
- Когда накопилось ≥3 `[research:X]` выводов в DEVLOG по одному домену
- Когда накопились ground-truth факты (`[fix/infra/deploy]`): рабочие команды, «что построено vs план», verified paths — чтобы новая сессия не переоткрывала устройство проекта
- Перед длительным перерывом в работе над проектом или передачей задачи
- Когда другой разработчик начинает работу в этом же проекте
- После обнаружения что новая сессия не знает о важных ограничениях (повторное открытие = сигнал)

> **Авто-напоминание:** `auto-update-watchdog.py` (SessionStart hook) детектирует домены с ≥3 накопленными DEVLOG-находками без покрывающего skill и печатает `💡 Capture-сигнал` в начале сессии — до того как агент начнёт переоткрывать. Ты не обязан помнить сам: хук напомнит. `/code` дополнительно ловит in-session переоткрытие факта (Шаг 7).
