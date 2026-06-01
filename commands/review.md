# /review — Архитектурное ревью

> **Цель:** последняя проверка перед merge — архитектурные нарушения, регрессии adjacent paths, class-bugs, sync validators (PRODUCT/USER-MAP/SYSTEM-MAP/ARTIFACT-MAP/ADR), документация. НЕ стиль, НЕ форматирование, НЕ автор — независимый критик. Output: 🔴 fix now / 🔵 Suggestion (с disposition tag) / ✅ merge.

Ты — строгий критик кода, не автор. Ищешь нарушения архитектурных контрактов, не стилистические мелочи.

**ЗАПРЕЩЕНО:** изменять файлы во время ревью. Только анализ.

---

## Рекомендуемая модель

**Strategy:** Default (Sonnet) — основной выбор. Upgrade to Capable (Opus) при триггерах.

**Default tier (Sonnet):** Используется для большинства review. Достаточна для архитектурной проверки, консистентности, контрактов.

**Upgrade to Capable tier (Opus) if:**
- `[security]` новый endpoint с threat-моделем
- Обнаружен class-bug при review (требует grep по всему проекту)
- Шаг 3.5 reassessment найдёт системную проблему
- Нужен deeper analysis для контрактов

**❌ Downgrade to Fast tier:** ЗАПРЕЩЕНО
- Review требует reasoning для проверки консистентности
- Даже на простом bagfix < 20 строк нужна Default
- Риск: пропустить архитектурное нарушение (как в Phase H1 Extended)

**Rule:** `review_tier ≥ Default`, никогда не ниже

**Mid-task escalation:** **да — Шаг 3.5 Complexity reassessment** (если найден class-bug или security gap)

**Pre-flight model check:** **да — при старте команды** спроси пользователя какая модель активна (или используй ранее подтверждённую в сессии) и сравни с Default tier для review. Если mismatch ≥ 2 ступени — пауза + рекомендация перед началом review.

---

## Навигационная карта шагов

| Шаг | Lite | [code] | [product] | [data] | [security/infra] | [contract] |
|-----|------|--------|-----------|--------|------------------|------------|
| 0 Повторный фикс | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 1 Прочитать изменения | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 2 Прочитать правила контекста | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 3 Проверки — Архитектурные нарушения | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| 3 Проверки — Регрессии | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| 3 Проверки — Параллельные пути / Class-bug | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| 3 Проверки — Conversation state pollution (если ai-agent) | — | ✓ | ✓ | — | — | — |
| 3 Проверки — Контракты | — | — | — | — | — | ✓ |
| 3 Проверки — Breaking change list | — | — | — | — | — | ✓ |
| 3 Проверки — Безопасность (auth, PII) | — | — | — | ✓ | ✓ | ✓ |
| 3 Проверки — Тесты | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| 3 Проверки — Prompt engineering (если менялся промпт) | — | ✓ | — | — | — | — |
| 3 Проверки — Уровень регулятора (level-4 check) | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| 3 Проверки — Документация (SYSTEM-MAP/data-map/ADR) | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| 3 Проверки — Конкретный тест-сценарий | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 3 Проверки — Кросс-платформенные (если FS работа) | — | ✓ | ✓ | — | — | — |
| 3.5 Complexity reassessment | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| 4 Вывод | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

Прочитай таблицу ПЕРВЫМ. Пропускай шаги не отмеченные для типа задачи.

---

## Шаг 0 — Проверка на повторный фикс

- Открой DEVLOG.md
- Найди записи с тегом `[fix:X]` для того же компонента за 7 дней
- Если N ≥ 2 → 🔴 CRITICAL: "N-й деплой одной проблемы — деплой запрещён без новых диагностических данных"

---

## Шаг 1 — Прочитай изменения

**Шаг 1.0 — Branch scope (выполни ПЕРВЫМ):**

```bash
# Определить production_branch (читать из CLAUDE.local.md ## Branching, default: main)
git diff <production_branch>..HEAD --stat
git log <production_branch>..HEAD --oneline
```

Если `production_branch` не найден как ref → fallback: `git log HEAD~10..HEAD --oneline` с предупреждением.

**Классификация scope:**

- **Компактный scope** (≤ 5 commits, все с `/plan`): продолжить стандартный review.
- **Большой scope** (> 5 commits ИЛИ есть commits без `/plan`):

```
⚠️ Branch содержит N commits с момента {production_branch}.
   Commits без предшествующего /plan:
   - {hash} {message}  ← нет /plan перед этим
   - ...

   Весь diff охватывает: {список файлов из git diff main..HEAD --name-only}

   Рекомендую:
     a) Review всего branch scope (полный — рекомендуется)
     b) Фокус на последних N commits (укажи N)
     c) Фокус на конкретных файлах (укажи список)

   Жду выбора (a/b/c):
```

После выбора — формировать scope review из соответствующего diff.

⚠️ **"Commits без /plan" detection:** grep в commit messages за `feat(` / `fix(` / `docs(` / `chore(` которым **не предшествует** commit с `"plan"` / `/plan` в message. Эвристика, не точный алгоритм — но достаточно для сигнала.

---

1. `git diff HEAD` и `git diff --staged` ← только uncommitted changes (дополнительно к branch scope выше)
2. Определи тип изменения: Feature / Bug Fix / Migration / Refactor
3. Определи затронутые домены на основе **полного branch scope** (не только HEAD)

---

## Шаг 2 — Прочитай правила контекста

Всегда:
- `CLAUDE.md` — операционные правила проекта
- `.claude/rules/*.md` — технологические правила

По домену:
- Релевантные ADR (если есть)
- data-map.md / SYSTEM-MAP.md (если применимо)

---

## Шаг 3 — Проверки

### КРИТИЧНО — блокируют merge

**Архитектурные нарушения:**
- [ ] Нет ли прямых вызовов внешних API минуя единый интерфейс?
- [ ] Нет ли запросов к данным чужого модуля?
- [ ] Нет ли хардкода секретов / токенов / путей?

**Регрессии (обязательная проверка):**
Для каждого изменённого хендлера — пройди ВСЕ ветки (happy + error + unknown input).

**Completeness check (новое):**
- [ ] Решение явно указывает что закрывается и что НЕ закрывается?
- [ ] Список gaps назван явно (не "вроде всё")?
- [ ] Обоснование почему gaps OK или требуют action?
- Если < 90% покрыто И no justification → 🔵 Recommendation "High-risk gaps not mitigated"
- Если без явного анализа → 🔵 Recommendation "Completeness analysis missing"

**Параллельные пути — grep:**
- Если изменён компонент → grep по аналогичным паттернам в проекте
- **Class bug rule:** если изменён код отправки/обработки данных → grep по аналогичным паттернам без защитных обёрток

**Conversation state pollution check** (только если `project_type: ai-agent` в CLAUDE.md):
- Tool возвращает > 5 строк текста на error path? → 🔵 Recommendation
- Возвращает список (задачи, файлы) как error response? → 🔴 CRITICAL
- Тест: что увидит пользователь в следующих 2-3 запросах после этого error?

**Контракты:**
- [ ] Breaking change в API/событиях? → перечислить consumers
- [ ] Идемпотентность сохранена для retry-able операций?

**Безопасность:**
- [ ] Авторизация на новых endpoints?
- [ ] PII защищена в логах/responses?

---

### ПРЕДУПРЕЖДЕНИЯ

**Тесты:**
- [ ] Есть тест на главный инвариант изменения?
- [ ] Negative test (что при невалидных данных)?
- [ ] Regression test для bugfix?

**Prompt engineering (если менялся промпт):**
- Доменное ограничение или кейс-ограничение?
- Кейс → 🔵 Recommendation — не закрывает класс проблем

**Вопросы с вариантами без рекомендации (closes G-063):**
- [ ] Если PR добавляет или изменяет блок "Варианты:" в command-файле — есть ли `(рекомендуется)` хотя бы у одного варианта?
- Нет метки И варианты не равнозначны → 🔵 Recommendation "Варианты: без (рекомендуется) — пользователь не видит рекомендацию агента"

**Out-of-scope findings:**
- Замечены паттерны или возможные улучшения вне scope текущего fix? → добавить в IDEAS.md

**Уровень регулятора предложенных фиксов:**
Если review предлагает изменения в командах — обязательно рассмотреть Level 4+ альтернативу:
- [ ] Можно ли закрыть через schema constraint?
- [ ] Можно ли закрыть через структуру данных?
- [ ] Если Level 4 невозможен — явно указать почему

🔵 Recommendation если предложены только методологические правила без code-level альтернативы.

**Документация — Sync validators framework (config-driven L3):**

Прочитать `CLAUDE.local.md` секцию `## Sync validators`. Если секция отсутствует → пропустить sync validators (нет config = нет validation), продолжить existing subjective checks ниже.

Если секция есть — выполнить `git diff main..HEAD --name-only` → получить список изменённых файлов (`diff_files`). Для **каждого** validator в config:

1. **Match trigger_paths:** есть ли в `diff_files` файлы совпадающие с `trigger_paths` (glob patterns)?
   - Нет → validator не triggered, пропустить
   - Да → запомнить совпавшие файлы
2. **Optional flag:** если `optional: true` — проверить условие активации (напр. для `ADR-status` — упоминается ли `ADR-NNN` в commit message). Если не активирован → пропустить
3. **Check required_artifact:** есть ли `required_artifact` в `diff_files`?
   - Если задан `required_section` → проверить что секция упомянута в diff артефакта (`git diff main..HEAD -- <required_artifact>` содержит `<required_section>`)
   - Да → silent (sync OK)
   - Нет → 🔵 **Recommendation** (формат ниже)

**Формат Recommendation:**

```
🔵 Recommendation: <name из config>
Причина: <reason из config>
Затронутые файлы: <список совпавших с trigger_paths>
Не обновлено: <required_artifact>
Disposition: [fix now / deferred + DEVLOG entry / backlog → IDEAS.md / irrelevant + явное обоснование]
```

**Disposition обязательна** — пользователь выбирает явно, не игнорирует. "irrelevant" требует обоснование (например, "refactor без поведенческих изменений", "test-only change").

**Закрывает класс** «agent забыл обновить doc артефакт при изменении кода» для всех артефактов Категории А единым механизмом (PRODUCT-whole / PRODUCT-components / USER-MAP / SYSTEM-MAP / ARTIFACT-MAP / ADR-status). PRODUCT components check (v4.19.0) рефакторен в этот framework — L3 в `/plan` -1.3 (превентивно) + L4 здесь (финальная сверка).

**Subjective checks (остаются — ловят nuance что обновить, не "обновлено ли вообще"):**
- Поведение изменилось — PRODUCT.md обновлён?
- Изменилось количество шагов, точек или числовые параметры команды → PRODUCT.md числовые данные актуальны?

- Изменились пользовательские возможности (`/code` добавил/изменил/убрал команды или UX) → USER-MAP.md обновлён?
- PRODUCT.md изменён — USER-MAP.md всё ещё консистентен? (capabilities, data flow)
- Архитектурные изменения — SYSTEM-MAP.md / data-map.md / ADR обновлены?
- Добавлена/изменена зависимость между компонентами или интеграция с внешним сервисом → SYSTEM-MAP.md edges актуальны?
- SYSTEM-MAP или USER-MAP изменены → Mermaid-диаграмма сохранена? (замена на ASCII = 🔴 CRITICAL)
- Mermaid изменён → **hybrid language check** (CLAUDE.md гибридный язык): labels nodes и edges используют RU для описаний поведения / названий слоёв + EN для технических identifiers (имена файлов, команд)? Полностью EN labels (кроме identifiers) = 🔵 Recommendation "Mermaid language: пройти по labels, перевести описания на RU. ❌ `Hooks Layer` / `reads config` / `writes state` → ✅ `Слой хуков` / `читает config` / `пишет state`". Closes G-049 «agent assumed hybrid rule only applies to existing maps, not new Mermaid drafts».
- [methodology] Mermaid изменён → ссылки авто-обновлены и валидны? (run update then validate):
  `bash scripts/update-mermaid-links.sh --root ../it-dev-methodology-documentation && bash scripts/update-mermaid-links.sh`
  `bash scripts/validate-mermaid-links.sh --root ../it-dev-methodology-documentation && bash scripts/validate-mermaid-links.sh`
  После update: STALE/MISSING = 🔴 CRITICAL (ручной фикс).
- USER-MAP изменён → repo/setup контекст всё ещё актуален? (subgraph repos, sync-стрелки)
- Изменился рекомендуемый порядок действий или prerequisites для существующих возможностей → USER-MAP.md потоки актуальны?
- Новая команда или тип артефакта добавлены → `docs/product/ARTIFACT-MAP.md` обновлён?
- Изменился порог триггера → ARTIFACT-MAP.md колонка "Частота" актуальна?
- Изменилось поведение существующей команды по отношению к артефактам (новый read/write, новое поле triggers.json) → ARTIFACT-MAP.md стрелки актуальны?
- ARTIFACT-MAP изменён → table↔Mermaid консистентность: каждая **команда** в "Читает" имеет `-.->` или `===` стрелку (human actors не требуют); нода без единой стрелки → 🔵 Recommendation "ARTIFACT-MAP node island"

**Actor discovery-path check** (для любого проекта):
- Добавлен новый механизм (скрипт, команда, webhook, автоматизация, cron)? → есть ли описание trigger-point в файле который читается автоматически (CLAUDE.md или README.md)?
- Нет → 🔵 Recommendation "actor discovery-path missing — агент в новой сессии не найдёт как запустить этот механизм"

**Artifact size & prompt bloat check** (если изменён артефакт-инструкция: CLAUDE.md, карты, или runtime-промпт продукта — системный промпт бота/агента):
- Запустить `bash scripts/validate-artifact-size.sh` (для methodology-platform — также `--root ../<doc-repo>`). Меряет две оси против budget из `CLAUDE.local.md ## Artifact budgets`:
  - `SIZE_EXCEEDED` — артефакт раздут по размеру → агент скимит, теряется сигнал
  - `PROMPT_BLOAT` — высокая плотность запретов (`ЗАПРЕЩЕНО/СТОП/NEVER/❌`) → **подавление tool invocation** (модель тонет в ограничениях, перестаёт звать инструменты)
- **L3 разбор каждого WARNING** (размер ≠ автоматический приговор):
  - `SIZE_EXCEEDED` → раздутие (структурно сжать, вынести в LONG-файл) ИЛИ контент оправдан (обосновать почему)?
  - `PROMPT_BLOAT` → **душит ли обилие запретов вызов инструментов?** Проверить на реальном поведении: модель зовёт tools при таком промпте? Если нет → сократить/реструктурировать запреты (не усиливать descriptions — это не поможет поверх перегруженного промпта)
- Скрипт не запускался при изменении артефакта-инструкции → 🔵 Recommendation "size/bloat не проверен"

**Bootstrap-command contract** (только для methodology-platform tasks):
- [ ] Изменена команда: ссылается на новые файлы? → `new-project-init.sh` создаёт их?
- [ ] Изменён bootstrap: новый файл создаётся? → хотя бы одна команда на него ссылается?
- Несоответствие → 🔴 CRITICAL (команда сломана на свежем проекте)

**Cut-not-add — net-zero gate** (только methodology-platform; PR меняет `commands/*.md`) *(VISION Ось 5 Enforcement):*
- Сигнал направления: `git diff --stat HEAD commands/` — на сколько ±строк выросла/уменьшилась команда этим PR.
- `validate-artifact-size.sh` → `SIZE_EXCEEDED` на `commands/*.md` = команда раздута (агент скимит, ценные шаги тонут).
- **Если PR добавляет шаг/правило в команду** → обязательный вопрос: **«что убрал или слил для net-zero?»**
  - Назвать КОНКРЕТНО что удалено/консолидировано (не «оптимизировал формулировки» — какой шаг/правило).
  - Если убрать нечего → обосновать почему рост оправдан: новый **подтверждённый класс** проблем (G-NNN), не дубль существующего шага.
- 🔵 Recommendation если добавлен шаг без named removal И без обоснования класса. Цель — дисциплина cut-not-add, не запрет роста.
- *NB:* это policy layer поверх `/retro` Шаг 4.5 (тот измеряет ценность шагов HIT/SILENT; этот ловит разрастание в момент добавления). Комплементарны, не дубль.

**Конкретный тест-сценарий (обязательно):**
- Не "система отвечает", а "пользователь делает X → код делает Y → результат Z"
- Если не можешь описать конкретный сценарий → фикс не верифицирован

**Кросс-платформенные различия (если меняется FS работа):**
- Пути от агента → case-insensitive нормализация?
- Slashes нормализованы?

---

## Шаг 3.5 — Complexity reassessment

После прохождения checklist-ов — переоценка нужна ли upgrade модели для финализации review. Триггеры:

- [ ] Найден class-bug который требует grep по всему проекту (multi-file analysis)?
- [ ] Обнаружен `[security]` gap который требует deep threat-model analysis?
- [ ] Поведенческие нарушения в нескольких компонентах (системная проблема, не локальная)?

Если **любой** триггер сработал — СТОП. Вывести:

```
⚠️ Review нашёл системную проблему, требующую более глубокого анализа.
   Текущая модель: <current>
   Рекомендуемая: <upgrade tier — обычно Capable>
   Причина: <конкретно что найдено>

Варианты:
  a) Закрыть review на текущей модели — финальный отчёт может пропустить тонкости
  b) Прервать review, переключиться на upgrade tier, перезапустить (рекомендуется)
  c) Зафиксировать как 🔵 Recommendation "review incomplete due to model tier" в выводе

Жду ответа: (a/b/c)
```

---

## Шаг 4 — Вывод

**Правило: каждый finding требует явного disposition.**

| Тег | Когда использовать |
|---|---|
| `deploy action` | git-операция, DEVLOG-запись и т.п. — обработать при /deploy |
| `fix now` | блокирует merge — исправить до коммита |
| `quick win` | < 2 мин — исправляю в /code прямо сейчас |
| `backlog` | → IDEAS.md `[reviewed:suggestion]` |
| `deferred` | не исправляем сейчас, причина + DEVLOG / `[suggestion-deferred:reason]` |

Все findings ДОЛЖНЫ иметь disposition. Без disposition — review не завершён.

**Тон Suggestions:** каждый пункт — actionable рекомендация агента, не констатация проблемы. Формат: «Рекомендую [действие] чтобы / иначе [последствие]». ❌ «VERSION bump missing» → ✅ «Рекомендую добавить VERSION bump — иначе consumers не получат обновление».

```markdown
## Ревью: [файл / PR]

### Breaking changes (если есть)
- [изменение] → consumers: [список]
- Рекомендация: [versioning / migration / feature flag]

### 🔴 Критические нарушения

#### [Файл:строка] — [Название]
**Нарушение:** [что не так]
**Правило:** [ADR / CLAUDE.md правило]
**Рекомендация:** [конкретно что исправить]
**Если merge as-is:** [конкретный сценарий поломки]

### 🔵 Suggestions
- Рекомендую [конкретное действие] — иначе [последствие] — **deploy action**
- Рекомендую [конкретное действие] чтобы [цель] — **fix now**
- Рекомендую [конкретное действие] — **quick win**, исправляю в /code
- Рекомендую [конкретное действие] — **backlog**: IDEAS.md `[reviewed:suggestion]`
- Рекомендую [конкретное действие] — **deferred**: [причина]

### Архитектурные вопросы
- [вопрос требующий решения команды]
- Рекомендация: [предпочтительный вариант]

### ✅ Прошло проверку (не требует действий)
- [что проверено и соответствует правилам — информация, не чеклист]

### Автоматически пофиксено (если применимо)
- [список 🔵 которые уже исправлены — не требуют действий]

### Confidence Audit

Финальный синтез перед итогом. Одна строка с % и evidence-ссылкой на конкретный шаг плана:

- **Overall confidence:** __% — [что именно верифицировано: системность / регрессии / scope]
- **Главный риск остаётся:** [или "нет" если все критические закрыты]

⛔ Если < 80% — добавить в 🔴 (критическое) или 🔵 с тегом `fix now` с конкретным action before merge.

---

### Итог

**Статус:** [🔴 не merge / 🔵 merge с условиями (fix-now/deploy-action) / ✅ merge]

**Plan:** [N] fix-now · [N] deploy-action · [N] quick-win · [N] backlog · [N] deferred

[Если 🔴]: "Нужно исправить: [конкретно что]. После — перезапусти /review."
[Если ✅]: ничего — сразу следующий шаг

**Следующий шаг: /deploy?**
```

---

Код / PR для ревью:
$ARGUMENTS
