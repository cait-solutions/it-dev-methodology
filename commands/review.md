# /review — Архитектурное ревью

> **Цель:** последняя проверка перед merge — архитектурные нарушения, регрессии adjacent paths, class-bugs, sync validators (PRODUCT/USER-MAP/SYSTEM-MAP/ARTIFACT-MAP/ADR), документация. НЕ стиль, НЕ форматирование, НЕ автор — независимый критик. Output: 🔴 fix now / 🔵 Suggestion (с disposition tag) / ✅ merge.

Ты — строгий критик кода, не автор. Ищешь нарушения архитектурных контрактов, не стилистические мелочи.

**ЗАПРЕЩЕНО:** изменять файлы во время ревью. Только анализ.

---

## Рекомендуемая модель

**Extended (UI settings):** effort: **High** · thinking: **ON** — ревью = проверка консистентности + поиск class-bug (deep reasoning). См. `.claude/model-tiers.md` § Effort & Thinking.

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

**Pre-flight model check:** **да — при старте команды** спроси пользователя какая модель активна (или используй ранее подтверждённую в сессии) и сравни с Default tier для review. При mismatch — пауза + рекомендация перед началом review (порог и формат: `.claude/model-tiers.md § Pre-flight model check`; under-powered — любая ступень вниз → громкий STOP-advisory).

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

> Легенда оси типов (`[code]`/`[product]`/…/`[contract]`, Lite/Full) — `.claude/task-types.md`.

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

**Completeness check — структурный аудит незакрытых вещей (industry best practice: FMEA Detection + Gawande discipline):**

> **Принцип:** «решение указывает что НЕ закрывается?» — aspirational (агент пишет «да, указал»). Ниже — **конкретные классы пропусков** которые исторически проходили мимо аудита. Для каждого — пройти явно, дать evidence (grep / file:line / «проверено — N/A»). Это Detection layer: ловит тихие провалы которые happy-path тестирование пропускает.

Для каждого класса — отметить ✅ проверено-чисто / 🔴 найдено-нарушение / `N/A — причина`. **Пустой ответ или «вроде всё» = аудит не выполнен.**

- [ ] **Plan commitments verification (plan→code→review traceability):** прочитать `.claude/state/triggers.json` → `last_plan_session.commitments` (lookup как `.get('commitments') or []` — отсутствие ключа / `null` / `[]` НЕ ошибка). Для **каждой** записи сверить `status` против реального diff (Шаг 1):
  - `status: "done"` — подтверждено ли изменением в diff? Если в diff нет следов выполнения → 🔴 (помечено done, но не сделано).
  - `status: "skipped"` — есть ли `skip_reason`? Без причины → 🔴.
  - `status: "pending"` без `skip_reason` → 🔴 **fix now**: «Обязательство плана не выполнено: "<text>"». Блокирует merge.
  - `carried_over: true` — зачтено из прошлого re-plan, не требует следов в текущем diff.
  - **Graceful:** `commitments` отсутствует / пустой → 🔵 «commitments не заданы (план на версии до schema-бампа, или Lite без обязательств) — sync-methodology.sh подтянет поле; сверка пропущена», НЕ 🔴. `triggers.json` невалидный JSON → 🔵 «commitments не прочитаны — triggers.json повреждён, проверь вручную», НЕ блок.
  - *Закрывает класс «/plan обещал X → /code забыл → /review не поймал» (mermaid-ссылки, обновление артефакта, etc).*
- [ ] **CRUD-симметрия:** добавлен `add`/`create`/`set` → есть ли парный `delete`/`undo`/`rollback`? Если нет — это design decision или пропуск? *(класс G-061: secrets имел add/show/edit но не delete)*
- [ ] **Downstream consumers:** изменён формат/контракт артефакта A → `grep` кто читает A? Получили ли они обновление? *(класс G-066/G-068: формат ссылок изменён, consumers/templates не обновлены)*
- [ ] **Content vs existence:** валидируется **наличие** файла/поля, но не его **содержимое/актуальность**? Валидатор скажет OK на stale-контенте? *(класс G-073: FMEA D=9 тихий провал)*
- [ ] **Template / source-of-truth sync:** изменён instance (карта, команда) → обновлён ли соответствующий `templates/*.template.md`? *(класс G-068, закрыт hard-rule в /code Шаг 4 п.11 — здесь финальная сверка)*
- [ ] **Trigger chain integration:** добавлен скрипт/механизм X → встроен ли в команду/hook где он нужен, ИЛИ требует ручного отдельного запуска (который пользователь забудет)? *(класс G-067/G-074: скрипт предложен отдельно вместо интеграции)*
- [ ] **Sustainment gate** (closes G-099 class — «план создаёт механизм, но не проектирует его жизнеобеспечение»): прочитать `.claude/state/triggers.json` → `last_plan_session.sustainment` (defensive: `.get('sustainment') or []`; отсутствие поля = старый план до schema-бампа → 🔵 info, не блок). Затем проверить diff (Шаг 1):
  - Новый механизм/артефакт в diff (hook / script / команда / карта / ссылка / config / registry / счётчик / manifest) → есть ли строка для него в `sustainment[]`?
    - Строка есть → ✅ (декларирован lifecycle).
    - Строки нет И `sustainment` непустой (план знал о механизмах, но этот пропущен) → 🔴 **fix now**: «Новый механизм `<имя>` в diff без Sustainment Declaration — добавить строку в таблицу Шага 97 плана».
    - `sustainment` пуст ИЛИ поле отсутствует (старый план / Lite mode / doc-only) → 🔵 info: «Sustainment не проверен (старый план без поля или Lite mode) — при следующем Full /plan заполнить Шаг 97».
  - **LAR cross-check:** если в diff есть новый механизм (hook / script / command / map / config / registry / template) — проверить наличие строки для него в `docs/architecture/LIVING-ARTIFACTS.md` (или consumer-эквиваленте):
    - Строка есть → ✅ lifecycle задокументирован.
    - Строки нет, LIVING-ARTIFACTS.md существует → 🔴 **fix now**: «Новый механизм `<имя>` в diff без строки в LIVING-ARTIFACTS.md — добавить запись (из Шаг 97 таблицы)».
    - LIVING-ARTIFACTS.md отсутствует → 🟡 info: «LIVING-ARTIFACTS.md не создан — lifecycle-реестр недоступен; создать из `templates/LIVING-ARTIFACTS.template.md`».
  - **Анти-дубль правило:** если уже есть 🔴 от «Trigger chain integration» на тот же механизм — не дублировать; достаточно первого 🔴.
  - *Disposition для 🔴:* fix now — вернуться к плану, добавить Sustainment Declaration для пропущенного механизма, перезапустить /review.
- [ ] **Deferred-field presence check** (closes P-013 detection): прочитать `last_plan_session` → убедиться что ключ `deferred` присутствует (defensive: `.get('deferred') or []`; отсутствие у old consumer = 🔵 info «merge_triggers_json дозальёт поле — не блок»). Если ключ есть и непустой → убедиться что `/scope-out` источник `triggers.json last_plan_session.deferred[]` читает его (косвенная сверка: наличие `parse_deferred` в `scripts/scope-view.sh`). Только для diff содержащего изменение `scope-view.sh` или `triggers.json` — иначе пропустить.
- [ ] **Error / empty / absent path:** happy path работает → что при failure внешнего вызова / пустом входе / отсутствующем файле / wrong type? Названа ли реакция на каждую ветку?
- [ ] **Node readability (v5.57.0, G-121):** diff содержит mermaid-блоки → компонентные ноды в формате «Имя + Зачем + Без него» (≥ 2 `<br/>`)? Запустить `bash scripts/validate-maps-coverage.sh --report` (вывод `node-readability: WARN` = 🔵 Suggestion, не fix-now; но perfunctory «Зачем: нужно / Без него: плохо» = 🔵 с пометкой «переформулировать»). Affordance-ноды освобождены.
- [ ] **Новый validator без negative-fixture (closes G-112 class):** diff добавляет `scripts/validate-*.sh` → есть ли: (a) negative-fixture в `scripts/fixtures/validators/` + dual-copy в `templates/scripts/`; (b) `assert_exit` строка в `scripts/test-validators.sh`; (c) строка в `scripts/fixtures/validators/README.md`? Нет хотя бы одного → 🔴 **fix now**: validator без proof-of-rejection = потенциальный G-112 false-green.
- [ ] **No-gate-weakening (anti-cheat):** трогает ли diff сам квалити-гейт или измеряемый артефакт способом, который **ослабляет** проверку вместо её удовлетворения? Конкретно grep diff на: удалённый/`skip`-нутый тест, удалённую обязательную секцию артефакта, ослабленный acceptance-критерий, удалённый узел карты/строку реестра, расширенный `try/except`/null-swallow вокруг падающей проверки. Для каждого hit — **named обоснование** (гейт был неверным → исправлен легитимно) или 🔴.
- [ ] **Что ещё специфично для этого изменения** (open-ended — список выше не исчерпывающий): какой класс пропуска уникален для этой задачи?

**Disposition:**
- Любой 🔴 в **plan commitments** / CRUD / downstream / content-vs-existence / template-sync → 🔴 **fix now** (это классы с историей реальных провалов, не cosmetic). Невыполненное plan-обязательство (`pending` без причины) блокирует merge — но финальное merge/no-merge остаётся явным выбором пользователя (Disposition обязательна, не авто-abort).
- 🔴 в **no-gate-weakening** (артефакт/критерий ослаблен ради прохождения без named обоснования) → 🔴 **fix now**: восстановить артефакт/критерий, удовлетворить гейт по существу. Блокирует merge.
- Trigger-chain 🔴 → минимум 🔵 Recommendation «механизм требует ручного запуска — встроить в <команда>?».
- Если ни один класс не проверен явно (агент написал общее «completeness OK») → 🔵 Recommendation "Completeness audit не выполнен по классам — пройти 7 пунктов".

**Decision-review gate (closes «high-stakes план пропустил council», opinion:mandatory-council 2026-06-20) — objective diff-signal, independent pass:**

Это **реальные зубы** decision-validation: /review — отдельный проход (не тот же flow, что /plan), и судит по **самому diff** (объективно), а не по самооценке планирующего агента → ломает циркулярность self-gate в /plan.

- Сработал если diff **объективно** вводит хотя бы одно: новый hook (`templates/.claude/hooks/*` добавлен) · новый `scripts/*` механизм · блокирующее поведение (PreToolUse `exit 2` / hard-block) · breaking-change схемы (удаление/переименование поля в `*.template` / `triggers.json`) · смена core-инварианта (parallel-safety / security / branching-contract) · ≥3 затронутых компонента.
- Если сработал → проверить наличие decision-review record:
  - `triggers.json → last_plan_session.opinion_done == true` (council запущен), ИЛИ
  - `[opinion:*]` запись в DEVLOG за период этой задачи, ИЛИ
  - `skipped_warnings.opinion_skipped` инкрементирован (осознанный skip с named-причиной).
  - **Любое из трёх есть** → ✅ (запущен либо осознанно пропущен — не тихо).
  - **Ничего нет** → 🔴 **fix now**: «High-stakes изменение (<какой diff-признак>) без decision-review и без зафиксированного skip. Запусти `/opinion` (council 7/7, Capable) ДО merge ЛИБО зафиксируй явный skip с причиной (`skipped_warnings.opinion_skipped`). Технические гейты (Self-Lint/Confidence) не покрывают decision-level «тот ли механизм/слой» — framing-bias single-agent.» Блокирует merge.
- Diff не вводит ничего из списка → `decision-review: N/A — нет high-stakes сигнала в diff`.

⛔ Уровень честно: **L3** (procedural, /review — отдельный проход; нет хука физически блокирующего merge). Не 100%-гарантия, но **независимый объективный** cross-check сильнее self-gate в /plan. Skip-rate (`skipped_warnings.opinion_skipped`) мониторит `/retro` → Ось 1 data-driven hardening если пропуски накопятся. **Соответствует Граница 8** (срабатывает на узкий high-stakes subset, не blanket).

**Consumer-reach gate (SYS-006, closes Кластер E):** если diff трогает `commands/` или `templates/`:
- Прочитать `.claude/state/triggers.json` → `last_plan_session.consumer_reach_declared` (defensive: `.get(...)`).
- Поле `true` → ✅ consumer-reach был явно задекларирован в /plan.
- Поле отсутствует / `false` → 🟡 **WARN**: «Consumer-reach не задекларирован в last_plan_session — убедись что /plan Шаг -1.3 ответил на "Consumer-охват" для этого PR. Если задача была без предшествующего /plan — добавь явный ответ про охват консьюмеров в описание PR.» (не блок, но видимый сигнал)

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

**Тесты / верификация (discipline-creating — назвать конкретный способ, не «протестировано»):**
- [ ] **Главный инвариант:** каким **конкретным** способом проверено что изменение делает что обещано? (тест-кейс / выполненный grep с ожидаемым output / запуск скрипта с показанным результатом). «Проверил» без названного способа = не зачтено.
- [ ] **Negative / edge:** что происходит при невалидном входе — назван **конкретный** edge (пустой / wrong-type / отсутствует) и его реакция? Связь с Pre-Mortem сценарием 3 из /plan — те же edge-входы протестированы?
- [ ] **Regression для bugfix:** воспроизведён ли исходный баг ДО фикса (доказательство что фикс адресует реальную причину, не симптом)?
- [ ] **methodology-platform smoke-test:** изменение в команде/скрипте → есть ли дешёвый способ верифицировать без полного /deploy? (`grep` что новый пункт виден в файле; запуск bash-скрипта с показом expected output; `validate-*.sh` прошёл). Если изменение чисто текстовое в команде — `N/A — prompt-rule, верифицируется применением`.

**Actor-burden / забота о пользователе (eyes-check, closes G-121):**
- [ ] Вводит ли PR (текст плана/команды/доки/рекомендация) **remembered-обязанность для человека** — «не забывай делать X каждый раз / при ≥N» — при том что существует агентский/структурный актор (хук / команда / git-механизм / валидатор)? → 🟡 Warning: нарушение Ось 1, переназначить на структурный/агентский актор ИЛИ обосновать почему его нет.
- Освобождены: one-time setup, решения принципиально требующие человека (бизнес/security), осознанный opt-in.
- ⚠️ Это **eyes-check** (семантическая оценка, не token-grep) — читай глазами, не полагайся на автоматику. Не L3-structural.

**Prompt engineering (если менялся промпт):**
- Доменное ограничение или кейс-ограничение?
- Кейс → 🔵 Recommendation — не закрывает класс проблем

**Вопросы с вариантами без рекомендации (closes G-063):**
- [ ] Если PR добавляет или изменяет блок "Варианты:" в command-файле — есть ли `(рекомендуется)` хотя бы у одного варианта?
- Нет метки И варианты не равнозначны → 🔵 Recommendation "Варианты: без (рекомендуется) — пользователь не видит рекомендацию агента"

**Out-of-scope findings (capture для visibility — closes P-002 empty-room):**
- Замечены паттерны или возможные улучшения вне scope текущего fix? → классифицировать:
  - **Raw сигнал / идея** (ещё не оформленный gap) → `IDEAS.md` `[reviewed:suggestion]`.
  - **Product coverage gap** (продукт чего-то не умеет / use case не покрыт, есть severity) → `PRODUCT-GAPS.md` (P-NNN). Это то что `/scope-out` визуализирует — без записи отложенный scope невидим в backlog-view.
  - **Чисто тактический скоуп-кат** одного PR без продуктового значения → достаточно DEVLOG/обоснования, не плодить запись.
- ⛔ Эвристика: «появится ли как самостоятельная будущая задача / страдает ли use case?» да → PRODUCT-GAPS; нет → IDEAS или ничего. Симметрично `/plan` Шаг 99.3 write-path — оба наполняют источники `scope-view.sh`.

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
- Mermaid изменён → **hybrid language check** (CLAUDE.md гибридный язык): labels nodes и edges используют RU для описаний поведения / названий слоёв + EN для технических identifiers (имена файлов, команд)? Полностью EN labels (кроме identifiers) = 🔵 Recommendation "Mermaid language: пройти по labels, перевести описания на RU. ❌ `Hooks Layer` / `reads config` / `writes state` → ✅ `Слой хуков` / `читает config` / `пишет state`". ❌ Транслитерация кириллицы латиницей (`"Stanet"`, `"Zapuskaet"`, `"dobavlen"`) = 🔴 нарушение (НЕ является RU). Closes G-049, G-069.
- Mermaid изменён → ссылки авто-обновлены и валидны? Структура из `CLAUDE.local.md ## Auto-update → doc_repo_path` (closes G-076):
  - **single-repo (`doc_repo_path: null`):** `bash scripts/update-mermaid-links.sh && bash scripts/validate-mermaid-links.sh`
  - **two-repo (`doc_repo_path` задан):** также `--root <doc_repo_path>` для doc-репо + локально
  После update: STALE/MISSING = 🔴 CRITICAL (ручной фикс).
- **Maps coverage surfacing (closes BS-1 / P-009)** → запустить `bash scripts/validate-maps-coverage.sh --report` (non-blocking, exit 0). Дублирует surfacing из `/code` Шаг 4 п.9.5 как финальная сверка перед merge. `[WARN]`/`[ERROR]` (команда/skill/компонент отсутствует в карте, или диаграмма stale по `diagram-sources`) = 🔵 Recommendation: «добавить недостающие строки карт». **НЕ блок** — жёсткий gate стоит на `deploy-push.sh` (последний рубеж); дублировать exit-1 блок в /review избыточно и рискует ложными блоками на in-progress картах. Скрипт отсутствует → graceful skip.
- **Semantic diagram couple (BS-2/BS-5, ADR-015 слой 1)** → `--report` выше ловит **presence**, не **семантику**. Финальная сверка перед merge: для каждого компонента из diff чьё имя/ID есть узлом в живых картах — стрелки и label («Зачем»/«Без него») узла ещё отражают то, что изменил PR? Связь добавилась/исчезла, назначение сместилось, компонент удалён → 🔵 Recommendation «обнови узел/связь карты в этом PR» (PR-coupling). Diff не трогает закартированные компоненты → N/A. ⛔ L3, не 100% — periodic safety-net = `/architecture-audit` Способность D. Дублирует `/code` Шаг 4 п.9.5 semantic-couple как последняя сверка.
- **Internal link-check (Docs-as-Code)** → изменены .md артефакты со ссылками? Запустить `bash scripts/validate-links.sh` (если доступен). `BROKEN_LINK` = 🔴 CRITICAL: ссылка `[...](path)` на несуществующий файл (typo / перемещённый файл / two-repo артефакт указан локально вместо `../<doc-repo>/`). Closes класс G-076 (code-repo ссылается на doc-repo артефакты локальным путём).
- USER-MAP изменён → repo/setup контекст всё ещё актуален? (subgraph repos, sync-стрелки)
- Изменился рекомендуемый порядок действий или prerequisites для существующих возможностей → USER-MAP.md потоки актуальны?
- Новая команда или тип артефакта добавлены → `docs/product/ARTIFACT-MAP.md` обновлён?
- **Model-rec 3-измерения (closes blind-effort/thinking класс):** diff трогает `commands/*.md` / `commands-local/*.md` (новая команда ИЛИ правка секции `## Рекомендуемая модель`)? → секция ОБЯЗАНА содержать строку `**Extended (UI settings):** effort: … · thinking: …`. Нет строки → 🔵 Recommendation «секция модели без effort+thinking — рекомендация одномерна, пользователь настраивает UI вслепую; добавь `tier · effort · thinking`». Новая команда без строки в матрице `model-tiers.md` (включая колонки Effort/Thinking) → 🔴 (как существующий matrix-gate). Динамическая точка вывода рекомендации модели (proposal `/plan`/`/code`, trigger-вопрос) в diff без `effort`/`thinking` → 🔵. **Free-chat coverage (G-123, eyes-check):** если diff трогает `CLAUDE.md` секцию `## Model tier rule` («Рекомендации трёхмерны») — убедиться глазами что правило явно называет свободный чат + содержит free-chat few-shot (❌/✅). Нет explicit coverage → 🔵 Suggestion.
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

**[methodology] Template-drift check** (только для methodology-platform tasks):
- Задача меняла формат артефакта (новый стиль ссылок / placeholder'ов / секций / Mermaid URL pattern)?
  ```bash
  git diff main..HEAD --name-only | grep -E "^(commands|templates)/"
  ```
- Если да: проверить соответствующие `templates/*.template.md` на тот же формат. Несоответствие → 🔴 **CRITICAL**: шаблон не обновлён, consumer получит stale format при следующем sync.
  ```bash
  grep -r "<изменённый паттерн>" templates/
  ```
- Disposition: fix now (templates/*.template.md исправить в этом PR).

**Bootstrap-command contract** (только для methodology-platform tasks):
- [ ] Изменена команда: ссылается на новые файлы? → `new-project-init.sh` создаёт их?
- [ ] Изменён bootstrap: новый файл создаётся? → хотя бы одна команда на него ссылается?
- Несоответствие → 🔴 CRITICAL (команда сломана на свежем проекте)

**Schema↔skill parity** (только methodology-platform; PR трогает consumer-facing schema-template):

> **Класс G-120** «механизм заведён в data-слой schema-template, но не зеркалирован в парный knowledge-skill (SKILL.md) → невидим агенту в runtime, агент re-derive'ит с нуля» (type:file v6.4.7 доставлен в validator+template+.gitignore, но `secrets-management/SKILL.md` молчал). Дополняет deploy-time detector (`validate-schema-skill-parity.sh`, WARN) pre-merge осью.

- PR трогает `templates/secrets-manifest.yaml.template` (или иной schema-template из declarative-карты в `validate-schema-skill-parity.sh`)? Нет → `N/A — schema-template не тронут`.
- Если да → **ОБЯЗАТЕЛЬНО исполнить** (реальный запуск, не prose):
  ```bash
  bash scripts/validate-schema-skill-parity.sh
  ```
- Новое capability-поле в schema-template **без** упоминания в парном SKILL.md → 🔴 **fix now**: опиши поле в skill в этом же PR (CLAUDE.md MUST «Schema→skill parity»). Pure-config / non-agent-knowledge поле → допустимо оставить (detector WARN, не блок). ⛔ **Detection-guard:** скрипт отсутствует (migration window) → check невалиден, НЕ PASS: 🔵 «schema↔skill parity не проверен — `validate-schema-skill-parity.sh` отсутствует».

**Hook-wiring parity** (только для methodology-platform tasks; PR трогает `templates/.claude/hooks/`):

> **Класс** «fix есть в методологии, но не активировался у консьюмера — тихий fail» (erp 2026-06-06: hook-файл добавлен, но не wired в settings → hook мёртв у всех консьюмеров, ничто не ловило на dev-стороне). **Прямое направление:** file → нет wiring. Комплементарно `check_hook_health` в `auto-update-watchdog.py` (runtime у консьюмера, обратное направление settings→missing file) и sync G-075 — здесь dev-time gate на источнике.

- PR трогает `templates/.claude/hooks/*` (`git diff main..HEAD --name-only | grep "templates/.claude/hooks/"`)? Нет → `N/A — хуки не тронуты`.
- Если да: каждый hook-файл (`templates/.claude/hooks/*.py`, **после strip `.template`** — напр. `auto-update-watchdog.template.py` → `auto-update-watchdog.py`) ОБЯЗАН вызываться через `run-hook.sh <name>.py` в `templates/settings.template.json`:
  ```bash
  # список entry-point хуков (strip .template):
  for f in templates/.claude/hooks/*.py; do basename "$f" | sed 's/\.template//'; done | sort -u
  # список wired в settings:
  grep -oE 'run-hook\.sh [A-Za-z0-9_-]+\.py' templates/settings.template.json | sed 's/run-hook\.sh //' | sort -u
  ```
- Hook-файл присутствует, но НЕ в списке wired → 🔴 **CRITICAL fix now**: «`<name>.py` не wired в settings.template.json → hook мёртв у всех консьюмеров (тихий fail)». Блокирует merge. Disposition: добавить wiring в settings.template.json в этом PR.
- **Helper-исключение:** hook не самостоятельный entry-point (импортируется другим хуком) → допускается отсутствие wiring ТОЛЬКО при маркере `# NOT-WIRED: <причина>` в первых 5 строках файла. Без маркера — 🔴.
- ⛔ **Detection-guard (closes класс G-073):** если `grep run-hook.sh` вернул **0 совпадений** в settings.template.json (формат сменился на multiline / файл пуст) → check **невалиден, НЕ PASS**: 🔵 «hook-wiring parity не проверен — 0 run-hook.sh совпадений, проверь settings.template.json формат вручную».

**Delivery-consistency gate (только methodology-platform; PR трогает `templates/.claude/hooks/`, `templates/settings.template.json`, или `scripts/sync-methodology.sh`) — closes R-029 / review-blindness:**

> **Класс «фикс не доезжает молча» (G-087→G-088→v5.12.0 ×3).** Hook-wiring parity (выше) проверяет «hook wired в template». Этот gate проверяет следующий слой — **доставит ли `sync-methodology.sh` это wiring консьюмеру**. v5.12.0: `hook-liveness.sh` был wired в template, но `merge_settings_json hook_name()` распознавал только `.py` → `.sh`-вызов НЕ доставлялся. /review дал «0 critical», delivery-баг поймал только /deploy dogfood (post-merge) → re-release v5.12.1. Этот gate ловит тот класс **pre-merge**.

- PR трогает `templates/.claude/hooks/*`, `templates/settings.template.json`, или `scripts/sync-methodology.sh`? Нет → `N/A — delivery-поверхность не тронута`.
- Если да → **ОБЯЗАТЕЛЬНО исполнить** (не prose-проверка, реальный запуск):
  ```bash
  bash scripts/validate-delivery.sh
  ```
  Это сверяет: каждый hook-ref в settings.template.json (а) существует в `templates/.claude/hooks/` (б) распознаётся sync-парсером (`hook_name()` дуальный regex) → значит реально доедет до консьюмера.
- `FAIL` (exit 1) → 🔴 **CRITICAL fix now**: «hook-ref не доедет до консьюмера через sync — рассогласование template↔sync-parser (класс v5.12.0)». Блокирует merge.
- ⛔ **N/A escape ЗАПРЕЩЁН для этого класса.** Для изменений hooks/settings-template/sync — нельзя писать `N/A — prompt-rule, верифицируется применением`. Delivery — исполнимая проверка, не «верится на слово» (L3-escape провалился 3 раза, поэтому L4-gate). Verification-секция выше (Тесты/верификация) допускает N/A только для **prose-команд**, не для delivery-класса.
- **NB:** `validate-delivery.sh` уже встроен в `validate-template-format.sh` Check 6 (который /code Шаг 11 запускает обязательно) — этот /review gate — вторичный явный сигнал на случай если /code-прогон был пропущен.

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

**Опционально — делегирование role-суб-агента (on-demand, НЕ обязательно):**

Если триггер выше — `[security]` gap (deep threat-model) или class-level `[quality]`/инвариант-нарушение
(multi-file) — ты **МОЖЕШЬ** делегировать соответствующий role-суб-агент для глубокого прохода:
- `security` суб-агент (`.claude/agents/security.md`) — для security-поверхности (если у домена она есть).
- `qa` суб-агент (`.claude/agents/qa.md`) — для инвариант/класс-баг анализа против правил `.claude/rules/`.

Это **prompt-уровневый указатель, не mandatory phase**: если домен воркспейса не имеет
security/quality-поверхности (напр. маркетинг/доки/legal-контент) — пропусти. Делегирование уместно
только когда статический чеклист выше недостаточен. Фиксированного конвейера нет (VISION Граница 8).

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
