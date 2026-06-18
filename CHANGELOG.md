# CHANGELOG — methodology-platform

Consumer migration guide. Каждый milestone = что добавилось + что нужно запустить.

---

## v6.7.4 — feat: /vision review batch×16 + [research:mattpocock-skills] + P-011 + R-034/R-035/R-031 false-green confirmed (2026-06-19)

**Consumer-facing changes:** нет (methodology-internal — IDEAS/PRODUCT-GAPS/ROADMAP/triggers.json).

**Что сделано:**
- `IDEAS.md` — новая запись: engineering-discipline skill layer signal (mattpocock/skills, 135k★)
- `PRODUCT-GAPS.md` — P-011: capability-gap skills marketing-перекос (14/14 marketing, 0 engineering)
- `DEVLOG.md` — `[research:mattpocock-skills]`: adopt/adapt/reject классификация с номерами Границ; `[vision-review]`: batch×16 IDEAS
- `ROADMAP.md` — Now cleared (PLAN-H/C/G/I все ✅ done); Watch list добавлен (engineering-discipline); Done обновлён v6.7.4
- `triggers.json` — R-034/R-035/R-031 false-green исправлены: все три уже были реализованы (G-112 confirmed)

**Что делать consumers:** ничего — без изменений команд/шаблонов/хуков.

---

## v6.7.2 — fix: /opinion Council signal вшит в format template — G-119 (2026-06-19)

**Consumer-facing changes:**

- `commands/opinion.md` — `📊 Совет [5/5]:` теперь **первая строка обязательного формата ответа** в Шаге 2. Раньше сигнал был только в описании Шага 1.5 (переименован из 2.5) — LLM его пропускал. Теперь вшит в format template: выход без совета = невалидный ответ.
- Шаг 2.5 переименован в **Шаг 1.5** (нумерация отражает что council запускается ДО verdict).

**Что делать consumers:**
- 🟢 **Автоматически:** `sync-methodology.sh` обновит `.claude/commands/opinion.md`.
- 🟡 **Перезапусти Claude Code сессию** после sync — обновлённый format template должен быть загружен.

---

## v6.6.9 — fix: /opinion Council Protocol always-on — убран [council] маркер (2026-06-18)

**Consumer-facing changes:**

- `commands/opinion.md` — Council Protocol (Шаг 2.5) теперь запускается **автоматически при каждом вызове** `/opinion`. Явный `[council]` маркер больше не нужен и не требуется.
- Поведение для тех кто использовал `[council]`: результат тот же — маркер можно убрать из привычки, функция не изменилась.

**Что делать consumers:**
- 🟢 **Автоматически:** `sync-methodology.sh` обновит `.claude/commands/opinion.md`.
- 🟡 **Перезапусти Claude Code сессию** после sync чтобы обновлённая команда была в контексте.

---

## v6.6.7 — feat: /opinion Council Protocol — 5 advisors under the hood (2026-06-18)

**Consumer-facing changes:**

- `commands/opinion.md` → новый **Шаг 2.5 Council Protocol**: 5 советников «под капотом» (Ценность · North Star · Горизонт · Скептик · Деятель). Вывод: 2 строки сигнала (grid + главное расхождение). Enrichment правила: Скептик ❌ → «Что меня беспокоит» обязан включить находку; Деятель ⚠️/❌ → «Условия» обязан включить action gap.

**Что делать consumers:**
- 🟢 **Автоматически:** `sync-methodology.sh` обновит `.claude/commands/opinion.md`.
- 🟡 **Перезапусти Claude Code сессию** после sync чтобы обновлённая команда была в контексте.

---

## v6.6.2 — feat: mermaid URL rules — bare URL only + L2 agent mandate (2026-06-18)

**Consumer-facing changes:**

- `templates/CLAUDE.template.md` → `CLAUDE.md`: новое правило **bare URL only** в секции Правила диаграммы — запрет `[текст](url)` обёрток над mermaid-блоком.
- `templates/CLAUDE.template.md` → `CLAUDE.md`: новое правило **L2 agent-responsibility** — агент обязан явно запустить `bash scripts/update-mermaid-links.sh <file>` после любого edit файла с mermaid-блоком; hook остаётся страховкой.

**Что делать consumers:**
- 🟢 **Автоматически:** sync обновит `CLAUDE.md` у консьюмеров через `sync-methodology.sh`.
- 🟡 **Перезапусти Claude Code сессию** после sync чтобы обновлённый `CLAUDE.md` был в контексте.

---

## v6.6.1 — fix: sync atomicity (P-003 — auto-commit flag) (2026-06-18)

**Consumer-facing changes:**

- `scripts/sync-methodology.sh` + `templates/scripts/sync-methodology.sh`: новый флаг `--auto-commit` — после sync автоматически коммитит non-gitignored tracked файлы с explicit pathspec (closes P-003: dirty-tree class).
- `templates/.claude/hooks/auto-update-watchdog.template.py`: SessionStart sync теперь передаёт `--auto-commit` → sync output атомарно коммитится в consumer repo → устраняет orphaned dirty tree, которое блокировало `/push-consumers` rebase.

**Что делать consumers:**
- 🟢 **Автоматически:** sync обновит `auto-update-watchdog.py` + `scripts/sync-methodology.sh`.
- 🟢 **Backward-compatible:** `--auto-commit` — opt-in флаг; все существующие callers без флага поведение не меняется. Deploy-push.sh self-apply намеренно флаг не использует (он управляет коммитами сам).
- 🟡 **После sync:** перезапусти Claude Code сессию чтобы SessionStart hook подхватил обновлённый `--auto-commit`.

---

## v6.6.0 — feat: systemic gap fixes SYS-001..SYS-010 (2026-06-18)

**Consumer-facing changes:**

- `templates/AGENT-GAPS.md.template` + `templates/PRODUCT-GAPS.md.template`: новое поле `Methodology hint` (target/change/why) — консьюмер указывает предполагаемый fix; агент верифицирует перед применением (SYS-010). Backward-compatible (опционально).
- `templates/scripts/validate-*.sh` (×5): exit-code matrix — SKIP теперь exit 2, не exit 0; fix latent TypeError bug в validate-mermaid-links.sh (SYS-004).
- `templates/scripts/deploy-push.sh`: `_bump_version_monotonic` — предотвращает VERSION collision при parallel worktree deploys; callers validate scripts обновлены (exit 2 non-blocking) (SYS-007).
- `templates/.claude/hooks/post-edit-watchdog.py`: pako-inline detection — WARN в stderr при `](pako:` в edit output (SYS-001).
- Команды `/plan`, `/review`, `/code`, `/diagnose`: новые gates (data provenance, consumer-reach, multi-form grep, methodology_hint verification) (SYS-003/006/009/010).
- Skill `/design-spec`: Synth mode (skip interview if context known) + inline Source tagging (SYS-002).

**Что делать consumers:**
- 🟢 **Автоматически:** sync обновит `validate-*.sh` + `deploy-push.sh` + gap templates + `post-edit-watchdog.py`.
- 🟡 **Новые поля в gap шаблонах:** `Methodology hint` поле опционально — добавь к existing open gap'ам если хочешь предложить fix (агент верифицирует перед применением).
- 🟢 **Backward-compatible:** все изменения graceful для существующих consumers без изменений.

---

## v6.5.1 — fix: GITHUB_PAT rudiment removed from pull/clone path + gh_account in manifest (2026-06-17)

**Что добавлено:**
- `commands-local/pull-consumers.md` Prerequisite: заменён GITHUB_PAT check-secret на `gh api user -q .login` + `gh auth switch` (canonical GitHub auth).
- `commands-local/pull-consumers.md` Step 1: URL-prefix longest-match для gh_account lookup + SSH→HTTPS нормализация + CLAUDE.local.md fallback + `🟡 switch пропущен` warning.
- `scripts/clone-consumer.sh` + `templates/scripts/clone-consumer.sh`: error message теперь предлагает `gh auth switch` (GitHub) или `set-secret.sh <GITLAB_KEY>` (GitLab).
- `.claude/secrets-manifest.yaml`: `gh_account: "cait-solutions"` к GITHUB_PAT; `gh_account: "cait-deployer"` к GITHUB_URAI — Step 1 lookup теперь находит аккаунт.
- `templates/CLAUDE_LOCAL.template.md`: commented `gh_account` field в Branching section.

**Что делать consumers:**
- 🟢 **Автоматически:** sync обновит `templates/CLAUDE_LOCAL.template.md` и `templates/scripts/clone-consumer.sh`.
- 🟢 **Если используешь /pull-consumers:** добавь `gh_account: "<account>"` к нужным entries в `.claude/secrets-manifest.yaml` — Step 1 теперь использует его для switch.
- 🟢 **Backward-compatible:** manifest без `gh_account` продолжает работать (switch пропускается с `🟡` предупреждением).

---

## v6.5.0 — feat: /roadmap + NORTH-STAR.md — value-ranked приоритизация (VISION Ось 8 Phase 1) (2026-06-17)

**Что добавлено:**
- **`commands/roadmap.md`** — новая consumer-facing команда. Ранжирует кандидатов проекта (`ROADMAP.md` Considered/Next) по **ROI к North Star**: RICE-score `(Impact×Confidence)/Effort`, форсинг явной оценки на каждого кандидата. Граница 12 — рекомендует, не решает; аннотирует score в ROADMAP только по `y`. Не генерирует кандидатов (это `/vision review`).
- **`templates/NORTH-STAR.template.md`** — новый project-owned артефакт: целевая функция проекта (декларативная метрика ценности + target + self-reported state + `project_role: growth\|enabling` + dependency-edges). Конфигурируемый North Star (рост = дефолт). НЕ live-метрики (Граница 3/11).
- **`templates/model-tiers.md`** — строка `/roadmap` (Default tier).
- **`scripts/sync-methodology.sh`** + **`scripts/new-project-init.sh`** — `NORTH-STAR.md` доставляется (PRESERVE, ADD-if-missing) + создаётся при bootstrap.

**Зачем:** методология приобретает целевую функцию — критерий, по которому работа ранжируется по вкладу в рост. Лекарство от «делаем ради делаем»: enabling-проекты оправдываются через leverage на growth-проекты.

**Что делать consumers:**
- 🟢 **Автоматически:** sync добавит `commands/roadmap.md`, `NORTH-STAR.md` (если отсутствует), строку в `model-tiers.md`.
- 🟡 **Чтобы начать приоритизацию по ценности:** заполни `NORTH-STAR.md` (метрика + target + `project_role`) → запусти `/roadmap`. Или просто запусти `/roadmap` — команда проведёт опрос и создаст `NORTH-STAR.md`.
- 🟢 **Backward-compatible:** старый проект без `NORTH-STAR.md` не ломается — `/roadmap` gracefully предложит создать.

---

## v6.4.7 — feat: File-type secrets + .gcp/ gitignore pattern (2026-06-16)

**Что добавлено:**
- **`.gitignore.template`** — добавлен блок `.gcp/` (+ закомментированные `.aws/` `.azure/`) для cloud credential directories. Доставляется всем консьюмерам через `sync-methodology.sh`.
- **`secrets-manifest.yaml.template`** — новое опциональное поле `type: value | file` (default `value`). Тип `file` означает что значение ENV var = путь к файлу с credentials, а не сам секрет. Добавлен пример GCP-группы (GOOGLE_CLOUD_PROJECT, GOOGLE_APPLICATION_CREDENTIALS, GOOGLE_CLOUD_LOCATION) с инструкциями.
- **`scripts/validate-secrets.sh`** + **`templates/scripts/validate-secrets.sh`** (ADR-014 parity) — поддержка `type: file`: парсит новое поле, проверяет существование файла по пути из `.env`. Backward-compatible: манифесты без `type:` работают как прежде.

**Зачем:** некоторые UI (n8n, Vertex AI) не позволяют вводить credentials как файл — требуется файловый подход. Ранее `.gcp/` добавлялось вручную на каждый проект; теперь это zero-config default для всех консьюмеров.

**Что делать consumers:**
- 🟢 **Автоматически:** sync добавит `.gcp/` в `.gitignore`, обновит `scripts/validate-secrets.sh`.
- 🟡 **При использовании GCP:** раскомментировать GCP-блок в `.claude/secrets-manifest.yaml` + создать `.gcp/` dir + положить JSON ключ + `bash scripts/set-secret.sh GOOGLE_APPLICATION_CREDENTIALS`.
- 🟡 **Если `.gcp/` уже была staged** до sync: `git rm --cached .gcp/<file>.json`.

---

## v6.4.5 — feat: Anti-cheat rule (no-gate-weakening) in /code + /review + CLAUDE.md (2026-06-15)

**Что добавлено:**
- **`commands/code.md`** Шаг 3 п.4: Anti-cheat (no-gate-weakening) — никогда не ослабляй артефакт/критерий ради прохождения гейта; universal + dev/non-dev примеры. Текущий п.4 → п.5.
- **`commands/review.md`** Completeness-check: новый класс «No-gate-weakening» + disposition строка (🔴 fix now при отсутствии named обоснования).
- **`CLAUDE.md`** Workflow rules: блок **Anti-cheat rule** (между Fix rule и Ground-before-act rule).
- **`templates/CLAUDE.template.md`**: тот же блок на EN (dual-copy пара к CLAUDE.md).
- **Closes:** no-gate-weakening class (G-082 смежный). Domain-agnostic — применяется к dev и non-dev консьюмерам.

**Зачем:** правило «не маскировать симптом» покрывало только код; ослабление самого гейта/артефакта не было явно запрещено — теперь норма задокументирована как L1+L3.

**Что делать consumers:**
- 🟢 **Автоматически:** sync обновит `commands/code.md`, `commands/review.md`, `CLAUDE.md`.
- 🟡 **Info:** Anti-cheat rule теперь явная норма в `/code` Шаг 3 и `/review` Completeness-check.

---

## v6.4.4 — docs: wire-or-retire subagents — Architecture decision rule honesty (2026-06-15)

**Что изменено:**
- **`CLAUDE_LONG.md`** — заполнен placeholder `§ Architecture decision rule — расширенно`: nature on-demand, 3 реальных architect-validated решения (commit-discipline REJECT, testing-strategy APPROVE, M2 REJECT).
- **`CLAUDE.md`** — Architecture decision rule: уточнено «on-demand auto-discovery», `qa`/`security` только опционально, ссылка на CLAUDE_LONG.
- **`commands/review.md`** — Шаг 3.5: добавлен OPTIONAL prompt-указатель на делегирование `security`/`qa` суб-агентов (MAY, не MUST). Фиксированного конвейера нет.
- **`templates/.claude/rules/README.template.md`** — уточнена ссылка на qa-агент: опционально on-demand.
- **`docs/architecture/SYSTEM-MAP.md`** (doc repo) — узел `TMPL_AGENTS` + секция суб-агентов: architect = on-demand auto-discovery, qa/security = опционально.
- **Closes:** doc-drift placeholder CLAUDE_LONG, unused-capability advertising qa/security as always-wired.

**Зачем:** карта и правила рекламировали три равно-wired агента — реально работает один (on-demand). Честность = доверие к документации.

**Что делать consumers:**
- 🟢 **Автоматически:** sync обновит `commands/review.md` с опциональным указателем.
- 🟡 **Info:** `security.md`/`qa.md` в `.claude/agents/` — by-design опциональны; их ценность в наличии ready-to-use role-промпта, не в авто-вызове.

---

## v6.4.3 — feat: task-types.md canonical task-type axis (2026-06-15)

**Что добавлено:**
- **`templates/task-types.md`** — единый cited-canon оси классификации задач: 7 типов (`[code]`/`[product]`/`[data]`/`[infra]`/`[security]`/`[process]`/`[contract]`) + Lite/Full threshold + применимость по доменам. Синхронизируется консьюмерам как `model-tiers.md`.
- **`commands/plan.md`** Шаг -2: заменена inline-таблица определений на ссылку `.claude/task-types.md`.
- **`commands/code.md`** Режим: Lite/Full порог → ссылка на canon + кратко inline.
- **`commands/review.md`**: добавлена строка-легенда под навигационной картой.
- **`commands/diagnose.md`**: inline-ссылка на canon рядом с упоминанием типов.
- **Closes:** navigation-table duplication drift-класс между plan/code/review/diagnose.

**Зачем:** ось task-type физически дублировалась в 4 командах без источника правды. Добавление нового типа или изменение Lite-порога требовало ручной правки в нескольких местах — теперь только в canon.

**Что делать consumers:**
- 🟢 **Автоматически:** sync подтянет `.claude/task-types.md`.
- 🟡 **Проверить:** ссылки `.claude/task-types.md` в командах резолвятся — `test -f .claude/task-types.md`.

---

## v6.4.2 — feat: /sync-audit --doctor READ-ONLY healthcheck (2026-06-15)

**Что добавлено:**
- **`scripts/sync-doctor.sh`** (+ dual-copy `templates/scripts/sync-doctor.sh`) — READ-ONLY health snapshot: version (consumer-vs-clone раздельно от clone-vs-remote, closes G-107 conflation), hook liveness, secrets-manifest, runtime deps. `--json` CI-режим. `--online` для upstream проверки.
- **`commands/sync-audit.md` — doctor режим:** argument-dispatch секция + «## Режим doctor» + Ограничения. Trigger: «healthcheck», «doctor», «проверь install».
- **`templates/model-tiers.md`** — уточнение: doctor режим = Default всегда достаточен.
- **Closes:** G-107 (consumer-vs-clone конфляция), частично G-087 liveness.

**Зачем:** консьюмер не мог быстро узнать «здоров ли install» без запуска полного adoption-аудита с побочными эффектами. Doctor = preflight-триаж без записи state.

**Что делать consumers:**
- 🟢 **Автоматически:** sync подтянет `sync-doctor.sh`. Запускать через `/sync-audit --doctor`.
- 🟡 **CI:** `bash scripts/sync-doctor.sh --json` → exit 0/1, структурированный JSON.

---

## v6.4.1 — feat: managed-block idempotency для docs_reminder LIBS (2026-06-15)

**Что добавлено:**
- **`scripts/sync-methodology.sh` — MANAGED-BLOCK (4-й режим taxonomy):** `sync_managed_block()` helper. Методология пишет только между `# >>> methodology managed >>>` markers; fill-зона (LIBS) вне markers сохраняется by-construction.
- **`templates/.claude/hooks/docs_reminder.template.py` — restructured:** LIBS fill-зона сверху (project-owned), вся логика — в одном managed-блоке снизу. Removes unused `import json`.
- **Fail-safe:** pre-existing файл без markers → warn + skip (НЕ перезаписывается).
- **`commands/sync-audit.md` Gap 18:** command-first точка входа для добавления markers в старый fill.
- **Closes:** Security risk «Sync overwrites local fills (Low → Mitigated)».

**Зачем:** консьюмер, заполнивший `LIBS`, терял его на каждом sync — OVERWRITE перезаписывал файл целиком. Managed-block — L4-фикс: потерять fill нельзя by-construction.

**Что делать consumers:**
- 🟢 **Автоматически:** sync обнаружит markers в новом `docs_reminder.py` и начнёт делать selective refresh.
- 🟡 **Если LIBS уже заполнен (pre-v6.4.1):** запусти `/sync-audit` Gap 18 — агент предложит безопасно добавить markers, сохранив твой fill.

---

## v6.4.0 — feat: validator proof-of-rejection harness (test-validators.sh) (2026-06-15)

**Что добавлено:**
- **`templates/scripts/test-validators.sh`** — proof-of-rejection harness (methodology-internal, guarded `[ -d commands ]`). Доставляется consumers через sync, но не исполняется на их стороне.
- **`templates/scripts/fixtures/validators/`** — negative-fixtures каталог: 5 намеренно-сломанных входов для 5 validator-осей (triggers-duplicate, maps-no-scripts, mermaid-missing-link, parity-divergent, delivery-empty-settings).
- **deploy-push.sh gate:** validator-harness вызывается после script-parity, перед maps-coverage.
- **commands/code.md Шаг 5 + commands/review.md:** новое правило — новый `validate-*.sh` обязан иметь negative-fixture (proof-of-rejection обязателен, 🔴 блокирует merge без него).
- **Closes:** G-112 класс (false-green / SKIP-masquerades-as-PASS).

**Зачем:** валидаторы заявляли что отклоняют плохой ввод, но без фикстуров это не доказывалось. Deploy-gate думал «гейт существует ⇒ гейт работает» — без доказательства что гейт реально fire-ит.

**Что делать consumers:**
- 🟢 **Аддитивно:** sync подтянет `test-validators.sh` + fixtures. Harness guarded и не запускается на consumer-стороне.
- 🟡 **Опционально:** если consumer хочет добавить свои валидаторы — see `scripts/fixtures/validators/README.md` для паттерна (добавить fixture + assert_exit строку).

---

## v6.2.0 — feat: shared project context механизм (project-context.md) (2026-06-15)

**Что добавлено:**
- **Новый файл при bootstrap:** `new-project-init.sh` создаёт `.claude/rules/project-context.md` (из шаблона). Tracked in git — все разработчики, клонирующие репо, получают его автоматически.
- **Шаблон:** `.claude/rules/project-context.md` с секциями: Project type · Key Design Specs (таблица ссылок) · Key artifacts to read before /plan · Domain knowledge · Onboarding pointers.
- **Instruction в CLAUDE.md:** п.5 в «Read before any work» — агент читает `project-context.md` перед каждым `/plan` (если файл существует).
- **README обновлён:** `.claude/rules/README.md` теперь перечисляет стандартные файлы директории.

**Зачем:** CLAUDE.local.md gitignored → второй разработчик на другой машине не знал про Design Spec ссылки, project type и что читать перед /plan. Теперь эта информация в git-tracked файле.

**Что делать consumers:**
- 🟢 **Новые проекты:** `new-project-init.sh` создаёт `.claude/rules/project-context.md` автоматически → заполни секции.
- 🟡 **Существующие проекты:** файл НЕ создаётся sync (чтобы не перезаписать). Добавить вручную: скопируй из шаблона и заполни.

---

## v6.1.1 — fix: map-staleness покрывает ROADMAP (4-я living-map) (2026-06-13)

**Что (closes G-123):** ось `_check_map_staleness` (v6.1.0) покрывала 3 living-maps (USER/SYSTEM/ARTIFACT-MAP), ROADMAP выпадал — `_resolve_map_path` был захардкожен на 3 карты. ROADMAP — 4-я living-map (Temporal/Priorities viewpoint, LAR `тип: map`, в корне doc-repo). Фикс: множество карт вынесено в единый источник `LIVING_MAPS="USER-MAP SYSTEM-MAP ARTIFACT-MAP ROADMAP"` (L4 — явное множество вместо «3 по памяти»); резолв ROADMAP добавлен (корень DOC_ROOT). Цикл итерирует `$LIVING_MAPS`, не хардкод.

**Что делать consumers:** 🟢 аддитивно — sync подтянет. Прогон map-staleness теперь учитывает ROADMAP-пары.

---

## v6.1.0 — feat: map-staleness detection-ось (content-drift диаграмм) (2026-06-13)

**Что (closes /diagnose root cause — «содержимое диаграммы молча отстаёт от логики»):**

- **`scripts/validate-maps-coverage.sh` (dual-copy) — новая ось `_check_map_staleness`:** detection-слой поверх существующих presence (coverage) + url-freshness (mermaid-links). Ловит **time-drift**: если файл-компонент (script/command/hook) изменён в git **позже** living-карты, которая его описывает → `[WARN] map-staleness: <file> изменён позже чем <MAP> — сверь стрелки/labels`. Маппинг компонент→карты берётся из `LIVING-ARTIFACTS.md` колонки «Связанные артефакты» (явный человеческий маппинг, не хрупкий label-parse). Commit-based сравнение: синхронный PR-couple (карта+код в одном коммите) → **НЕ** stale (нет ложных WARN). Config `MAP_STALENESS_SEVERITY="warn"` (не блок).
- **Граница:** ось **mechanical** (commit-времена), НЕ семантика. Неверную стрелку при синхронном коммите она пропустит — это остаётся за `/architecture-audit` Способность D (ADR-015 detect+couple). Это третья detection-ось, не замена LLM-аудита.
- **`commands/doc-audit.md`** — ось добавлена в таблицу + уточнена граница.

**Что делать consumers (migration):**
- 🟢 Аддитивно — sync подтянет обновлённый `validate-maps-coverage.sh`. Ось работает автоматически в /doc-audit, /code Шаг 9.5 surfacing, /review, deploy-gate.
- Требует `LIVING-ARTIFACTS.md` с заполненной колонкой «Связанные артефакты» (компонент → какие карты его описывают). Нет LAR → ось graceful-skip с INFO «маппинг недоступен». git недоступен (zip-снимок) → graceful-skip.
- triggers.json **не меняется** — config-флаг в шапке скрипта, не в state. Старый consumer не падает.
- Sync → `bash scripts/sync-methodology.sh .` (methodology) / стандартный sync (consumer).

---

## v6.0.0 — BREAKING: /vision consolidation + Ground-before-act rule + validator fix (2026-06-12)

**Что (3 потока из architecture-audit + diagnose):**

- ⚠️ **BREAKING — командная консолидация:** `/product-vision` + `/product-review` + `/sync-vision` слиты в **`/vision {strategy|review|sync}`** (dispatcher по аргументу). Тела трёх команд сохранены дословно под per-mode секциями; per-mode model-tier таблица (strategy=Capable, review/sync=Default); все три triggers-ключа (`last_product_vision/review/sync_vision`) сохранены — каждый mode пишет свой → схема triggers.json **не меняется**. `/product-check` остаётся отдельной командой (механический Fast-tier аудит, другая ось). Обоснование: один домен (VISION+ROADMAP) + одна аудитория (PM) + взаимные cross-ref «НЕ для X» = три фасета одного lifecycle.
- **`CLAUDE.md` Workflow rules — новое `Ground-before-act rule`:** общий L3-регулятор «читай live-источник перед утверждением о структуре/состоянии/версии/cross-repo». Закрывает `assumption-gap` recurrence class (architecture-audit recurrence_rate=**0.53**, самый высокий — фиксы были локальные, паттерн возвращался). Обобщает разрозненные per-command pre-flights. Таблица канонических триггеров (G-039/G-085/G-100/G-105/G-106/G-109/G-116/G-117 — один корень).
- **`scripts/validate-maps-coverage.sh` (dual-copy) — fix node-readability validator (G-121b):** (1) перестал флагать edge-labels (`X -->|"..."|`) и subgraph-заголовки как ноды без Зачем/Impact формата (false-positive class — приучал владельца игнорировать вывод); (2) summary-counter теперь считает node-readability findings (рапортовал «0 warning(s)» при десятках напечатанных WARN). После фикса 55 **настоящих** advisory-warnings всплыли — существующие карты до G-121 формата (миграция — отдельный PR, как и заявлено в CLAUDE.md §3).

**Что делать consumers (migration):**
- ⚠️ Переименование команд: `/product-vision` → **`/vision strategy`**, `/product-review` → **`/vision review`**, `/sync-vision` → **`/vision sync`**. После sync старые команды **исчезнут** (`sync-methodology.sh` удаляет команды, отсутствующие в источнике). Привычки/скрипты/доки, ссылающиеся на старые имена → обновить.
- triggers.json и DEVLOG-теги (`[sync-vision]` и т.п.) — **без изменений**, обратно совместимы.
- Sync → `/vision` появится; `Ground-before-act rule` в CLAUDE.md; validator перестанет шуметь на edge-labels.

---

## v5.61.0 — feat: diagram semantic fidelity — detect+couple (P-009 BS-2/BS-5, ADR-015) (2026-06-12)

**Что:**
- **`commands/architecture-audit.md`** — новая **Способность D «Diagram semantic review»** (Шаг 3.5): LLM читает узлы+labels+связи **всех** living-карт (SYSTEM/USER/ARTIFACT-MAP, ROADMAP), сравнивает с реальностью системы, выдаёт diff (stale node / stale edge / stale label, confirmed|suspected). Capability-detection в Шаг 0; Capable tier обязателен. Закрывает семантическую ось которую Способность A (граф SYSTEM-MAP↔код) и grep-валидаторы не берут.
- **`commands/code.md` Шаг 4 п.9.5 + `commands/review.md`** — **semantic PR-couple** (L3): расширение существующего v5.59.0 maps-surfacing. diff трогает компонент → сверить его узел/связи/label в картах → обновить в том же PR. Presence ловит `--report`, семантику — этот couple.
- **ADR-015** «Diagram semantic fidelity — detect+PR-couple, не generate» (зеркало ADR-014): семантика поддерживается detect+принуждением обновить в PR, НЕ авто-генерацией. Честно L3, не 100% — для рукописной диаграммы выше нельзя без генерации.
- **OQ-008** — генерация table-derived карт (ARTIFACT-MAP/ROADMAP) при рецидиве drift. CLAUDE.md Maps Standard §5 — правило Semantic fidelity.

**Что делать consumers:**
- Sync → `/architecture-audit` получит Способность D (запускается если есть living-карты с mermaid); `/code` и `/review` — semantic-couple под-пункт.
- Изменение поведенческое, аддитивное (новая способность + prompt-пункты), не breaking.

---

## v5.60.0 — feat: /doc-audit команда + dual-copy parity gate (G-122, ADR-014) (2026-06-12)

**Что:**
- **`commands/doc-audit.md`** — **новая команда**: полный mechanical-freshness аудит документации одним прогоном, on-demand «проверь всё сейчас». Закрывает окно между cadence-аудитами (/architecture-audit ≥5 планов, /retro ≥15) и deploy-gate. Оси: dual-copy parity, maps-coverage (+diagram-freshness +node-readability), mermaid-links/syntax (оба репо), внутренние ссылки, OVERVIEW freshness, LAR, ARTIFACT-MAP. `--fix` режим: авто-обновление всех mermaid.live ссылок (оба корня) перед проверкой. НЕ semantic drift (/architecture-audit), НЕ adoption (/sync-audit).
- **`scripts/doc-audit.sh`** + dual-copy — оркестратор: каждая ось graceful-skip если не применима; Summary PASS/WARN/FAIL/SKIP; exit 1 при ошибках.
- **`scripts/validate-script-parity.sh`** + dual-copy — атомарный детектор drift между `scripts/` и `templates/scripts/` (intersection-only, направление по git-датам). **Wired первым gate в `deploy-push.sh`** (error, блок) — закрывает G-122: ось node-readability (v5.58.0) попала только в templates-копию, канон не обновился, деплой её не запускал.
- **Выравнен весь существующий drift — 7 пар:** validate-maps-coverage (node-readability теперь в каноне и реально работает), deploy-push (tee/G-119 → templates), validate-links, validate-template-format, validate-artifact-size, validate-mermaid-links, mermaid-link.py.
- **ADR-014** — dual-copy parity contract (gate вместо генерации; whitelist запрещён; OQ-007 на генерацию при рецидиве). CLAUDE.md MUST-строка.

**Что делать consumers:**
- Sync → получите `doc-audit.sh` + команду `/doc-audit`: ручной полный аудит своей документации (manual-вариант BS-3 — последний рубеж который у consumers отсутствовал).
- Parity-ось для consumers — no-op (guard `[ -d commands ]`).

---

## v5.59.0 — feat: maps-freshness gate earlier + liveness (BS-1/BS-4, P-009) (2026-06-12)

**Что:**
- **`templates/.claude/hooks/maps-freshness-liveness.sh`** — **новый** SessionStart hook (pure POSIX sh, без run-hook.sh — зеркало `hook-liveness.sh`). На старте сессии смотрит `git diff HEAD` изменённых `.md` с `` ```mermaid `` → если ссылки stale/missing → warning. Закрывает **BS-4**: `post-edit-watchdog` (Edit|Write) слеп к правкам карт через Bash (sed/`>>`/mv) и к staleness при изменении кода-не-карты. Liveness git-diff agnostic к инструменту правки — ловит ЛЮБОЙ путь post-hoc. Non-blocking (exit 0).
- **`commands/code.md` Шаг 4 п.9.5** — новый non-blocking surfacing `validate-maps-coverage.sh --report` сразу после финализации карт. Закрывает **BS-1**: раньше coverage-gate (exit 1) жил ТОЛЬКО в `deploy-push.sh` → drift невидим до деплоя. Теперь виден в момент /code.
- **`commands/review.md`** — тот же `--report` surfacing как финальная сверка перед merge (🔵 Recommendation, НЕ блок — жёсткий gate остаётся на deploy).
- **`commands/plan.md` Подшаг -0.4** — `maps-freshness-liveness.sh` добавлен в SessionStart liveness-set (документирован вместе с `hook-liveness.sh`).
- **`templates/settings.template.json`** — wire нового hook в SessionStart.

**Actions (consumer):**
```bash
bash <methodology>/scripts/sync-methodology.sh .   # доставит новый hook + wiring (merge_settings_json)
```
Перезапусти сессию чтобы SessionStart hook активировался.

**Priority:** 🟡 — улучшает гарантию актуальности карт; не breaking (аддитивный hook + non-blocking surfacing).

**НЕ входит (отдельное PM-решение PLAN-F):** семантика диаграмм BS-2/BS-5 (presence ≠ semantics), консьюмер-симметрия deploy-gate BS-3 (guard `[-d commands]`).

---

## v5.58.0 — feat: mermaid node-readability axis (G-121) (2026-06-12)

**Что:**
- **`CLAUDE.md §3`** — новое правило «Формат node-описания» (closes G-121): компонентные ноды в mermaid обязаны иметь три строки понятные нетехническому читателю: `NodeID["🔹 Имя<br/>Зачем: назначение<br/>Без него: impact"]`. Применяется ко ВСЕМ создаваемым диаграммам (living maps, draft, design-spec §8, ad-hoc). Affordance-ноды и deferred-кластер освобождены.
- **`templates/scripts/validate-maps-coverage.sh`** — новая ось `node-readability` (`NODE_READABILITY_SEVERITY="warn"`): per-block scanner с ASCII-heuristic (≥2 `<br/>`), affordance/deferred exemption. Dual-copy parity (G-103).
- **`templates/CLAUDE-methodology.template.md §3`** — dogfood parity: compact mirror правила.
- **`skills/design-spec/SKILL.md`** — node-format в Шаг 3 (per-component diagram rule) + checklist item в Шаг 5. Combines G-120+G-121 enforcement.
- **`commands/plan.md`** Шаг 99.54 и **`commands/review.md`** — явные ссылки на §3 node-format.

**Что делать consumers:**
- Sync для получения обновлённого `validate-maps-coverage.sh` (новая ось), `skills/design-spec/SKILL.md`, `CLAUDE-methodology.template.md`.
- Существующие диаграммы: migrate форматирование в отдельном PR (WARN, не block).
- Новые диаграммы: следовать формату автоматически (правило в CLAUDE.md §3).

---

## v5.58.0 — feat: deferred[] persistence — тактические scope-cuts видны в /scope-out (P-013) (2026-06-12)

**Что:**
- **`commands/plan.md` Шаг 100** — новый пункт 1bis: сбор `deferred[]` из «Не учтено → deferred/out-of-scope» (anti-double-count vs PRODUCT-GAPS); JSON-шаблон добавлен; Шаг 99.3 write-path note о персистенции тактических cuts.
- **`commands/code.md` Шаг 7** — явный carry-over `sustainment[]` и `deferred[]` (фикс латентной дыры: без carry оба поля тихо терялись при перезаписи last_plan_session); auto_deploy DEVLOG путь: строка `Deferred:` если непусто.
- **`commands/deploy.md` Шаг 2** — строка `Deferred:` в формате [deploy]-записи (читает `last_plan_session.deferred[]`).
- **`commands/review.md`** — новый чек-пункт Deferred-field presence (detection + ссылка на `parse_deferred`).
- **`scripts/scope-view.sh` + `templates/scripts/scope-view.sh`** — 5-й источник `parse_deferred()`: читает `last_plan_session.deferred[]`, генерирует субграф `🟪 Отложено последним планом (task_id)` со стилем dashed; включён в `SCOPE_META total`.
- **`commands/scope-out.md`** — таблица источников +5-я строка; формулировка «не пересекаются» исправлена.
- **`templates/triggers.json.template`** — аддитивное поле `"deferred": []` в `last_plan_session`.

**Зачем:** тактические `→ deferred` / `→ out of scope` пункты планов пропадали навсегда через анти-шум фильтр (P-013). Теперь `/scope-out` показывает их субграфом, DEVLOG фиксирует строкой.

**Что запустить:**
- `bash scripts/sync-methodology.sh .` — self-apply (обновит `.claude/skills/`, `.claude/commands/`, `scripts/scope-view.sh` у себя)
- `bash scripts/sync-methodology.sh <consumer-path>` — доставить `templates/scripts/scope-view.sh` + `triggers.json.template` консьюмеру
- `merge_triggers_json` дозальёт `deferred: []` в существующий consumer `triggers.json` без поломки (graceful additive).

---

## v5.56.0 — feat: /design-spec diagrams + scope-gate (G-120/P-012) (2026-06-12)

**Что:**
- **`skills/design-spec/SKILL.md`** — добавлено три механизма:
  - **Шаг 2 Scope-gate:** после получения списка компонентов агент проверяет cross-domain границу (primary) и ≥6 компонентов (secondary signal). При обнаружении — recommendation-first декомпозиция (не блокировка). Критерий нетривиальности задокументирован. Closes P-012.
  - **Шаг 3 Per-component диаграммы:** для каждого нетривиального `§2.N` (поток с ветвлением / состояния / ≥3 шага взаимодействия) — стандарт добавлять mermaid-блок. Тривиальные получают явную skip-причину. §8 переформулирован: Обязательна / Рекомендуется / Skip с условиями. G-100 pako-запрет явно включён. Closes G-120.
  - **Шаг 5 Checklist:** 4 новых gate-пункта по диаграммам + блок Final без диаграмм/skip-причин.
- **`templates/DESIGN_SPEC.template.md`** — добавлен слот `Диаграмма:` в `§2.1`/`§2.2` с placeholder mermaid; §8 переформулирован с условием-триггером; раздел Верификации добавил 4 диаграммных пункта.

**Что делать consumers:**
- Sync для получения обновлённого SKILL.md и шаблона.
- Существующие Design Spec без диаграмм: необязательно ретроспективно добавлять — Gate активируется только при переводе в `Final` через `/design-spec`.

---

## v5.54.0 — feat: mermaid-coverage axis + USER-MAP полнота команд + WARN-surfacing в deploy (2026-06-12)

**Что:**
- **`scripts/validate-maps-coverage.sh`** — новая ось `mermaid-coverage` (`USER_MAP_MERMAID_COVERAGE="warn"`): проверяет что каждая команда/skill присутствует именно в `\`\`\`mermaid\`\`\`` блоках USER-MAP (не только где-то в файле). Закрывает G-119: `_check_axis` грепал весь файл → команда в таблице falsely проходила проверку. Новая функция `_check_command_in_mermaid`: in-block scanner с edge-label стрипом + blob-поддержкой (`·`-разделители). Dynamic list: любая новая команда/skill автоматически входит в проверку.
- **`scripts/deploy-push.sh`** — WARN-surfacing (G-119, RPN=384): `tee`-паттерн захватывает вывод gate в realtime И считает `[WARN]` строки → после «✅ passed» явно печатает `⚠️ N предупреждений карт — проверь [WARN] выше`. WARNs больше не тонут за passed-строкой.
- **`templates/scripts/validate-maps-coverage.sh`** — dual-copy G-103 (идентичное изменение).
- **`docs/product/USER-MAP.md`** (documentation repo) — добавлены 6 пропущенных элементов: `/test`, `/pull`, `/push-merge · /push-only` (blob), `design-spec · testing-strategy · secrets-management` (blob). 22/22 команд + 14/14 skills в mermaid. Gate: 0 error(s), 0 warning(s).

**Что делать consumers:**
- Sync: `validate-maps-coverage.sh` добавляет WARN на команды/skills пропущенные в mermaid-блоках. WARN — не блокирует. Исправляйте по-мере. Gate по умолчанию `warn` для консьюмеров.
- Для methodology-platform: `USER_MAP_MERMAID_COVERAGE="gate"` включает ERROR (добавить в CLAUDE.local.md при необходимости).

---

## v5.52.0 — feat: command-first USER-MAP + /push-consumers init-flow (2026-06-12)

**Что:**
- **`scripts/validate-maps-coverage.sh`** — отрицательный gate `USER_MAP_NO_SCRIPTS="gate"`: блокирует `.sh`/`.py` узлы внутри mermaid-блоков USER-MAP. Сканирует только `\`\`\`mermaid\`\`\`` фенсы (не таблицы/тексты). Methodology: ERROR. Consumers: WARN (graceful). Closes G-116.
- **`templates/scripts/validate-maps-coverage.sh`** — dual-copy G-103 (warn-only для consumers).
- **`commands-local/push-consumers.md`** — Шаг 3 расширен: `[not-initialized]` repo → per-repo `init/skip/never` выбор → `new-project-init.sh` + включение в батч sync+commit+push. Gap 14 паттерн повторно применён. Closes P-010.
- **`CLAUDE.md`** Maps Standard §3 — добавлено правило «USER-MAP MUST NOT содержать скрипт-узлы».
- **`docs/adr/ADR-013-usermap-audience.md`** (documentation repo) — USER-MAP audience = владелец методологии (maintainer); no-script-nodes rule.
- **`docs/product/USER-MAP.md`** (documentation repo) — 7 script-узлов заменены командами и affordance: `new-project-init.sh`→`/push-consumers`, `sync-methodology.sh`→`/sync-audit`, `set-secret.sh`/`with-secret.sh`/`validate-secrets.sh`→`/secrets`. Validate-maps-coverage gate: 0 ошибок.

**Что делать consumers:**
- После sync: `validate-maps-coverage.sh` на вашем проекте — WARN (не gate) для script-узлов в USER-MAP. Исправьте вручную: заменить `bash scripts/X.sh` узлы в mermaid на соответствующие команды `/cmd`.
- Новые проекты: `new-project-init.sh` автоматически создаёт LAR (v5.51.0).

---

## v5.51.0 — feat: consumer freshness rollout (PLAN-I) — LAR bootstrap + /sync-audit Gap 16 + annotations (2026-06-12)

**Что:**
- **`scripts/new-project-init.sh`** — LAR bootstrap: создаёт `docs/architecture/LIVING-ARTIFACTS.md` из шаблона при init. Guard: существующий файл не перезаписывается.
- **`commands/sync-audit.md`** — Gap 16 «Living Artifact Registry bootstrap» (per-repo init/skip/never, паттерн Gap 14); Gap 15 расширен: diagram-freshness вывод + инструкция по аннотациям для консьюмера.
- **`templates/SYSTEM-MAP.template.md`**, **`USER-MAP.template.md`**, **`ARTIFACT-MAP.template.md`** — вставлены `<!-- diagram-sources: axes -->` стабы перед каждым mermaid-блоком → новые консьюмерские артефакты рождаются аннотированными.
- **`commands-local/pull-consumers.md`** — Шаг 3.6 freshness check (LAR ✅/❌ + validate-maps-coverage.sh result); drift-таблица расширена колонками LAR + Freshness.
- Закрывает PLAN-I задачу: freshness-механизм доставлен консьюмерам через bootstrap + команды.

**Что делать consumers:**
- После sync: `/sync-audit` теперь включает Gap 16 (LAR bootstrap предложение).
- Неаннотированные диаграммы → Gap 15 покажет список + инструкцию `<!-- diagram-sources: ... -->`.
- Новые проекты: `new-project-init.sh` создаёт LAR автоматически.

---

## v5.50.0 — feat: validate-lar.sh V2 (PLAN-G) — LAR-driven auto:* marker runner (2026-06-12)

**Что:**
- **`scripts/validate-lar.sh`** (UPGRADED V2) — per-row исполнение `auto:*` маркеров из LAR Detection ячейки. Enum (6): `auto:exists` (default), `auto:mermaid-links`, `auto:mermaid-syntax`, `auto:date-coupling=<glob>`, `auto:diagram-freshness`, `(нет маркеров)`. Делегирует существующим валидаторам — не реимплементирует. Summary: `auto-checked: N / existence-only: M`. Bash 3.2+, space-safe tmpfile.
- **`templates/scripts/validate-lar.sh`** — dual-copy G-103 (diff -q identical).
- **LAR `LIVING-ARTIFACTS.md`** — добавлены маркеры `auto:mermaid-links` `auto:mermaid-syntax` к SYSTEM-MAP/USER-MAP/ARTIFACT-MAP; `auto:diagram-freshness` к ROADMAP.
- Закрывает PLAN-G задачу: LAR = исполняемый реестр.

**Что делать consumers:**
- После sync: `bash scripts/validate-lar.sh` теперь выполняет auto-проверки по маркерам в LAR. Добавлять маркеры в свою LAR строку для нужной проверки.
- Существующие LAR без маркеров → existence-only (backward compatible).

---

## v5.49.0 — feat: validate-mermaid-syntax.sh (PLAN-C) — R-031 structural mermaid checks (2026-06-12)

**Что:**
- **`scripts/validate-mermaid-syntax.sh`** (NEW) — 5 структурных проверок для `graph`/`flowchart` mermaid-блоков: SUBGRAPH-EDGE (G-085), DUP-NODE (G-029), UNDEF-CLASS, CYRILLIC-ID (G-005), TRANSLIT-LABEL (эвристика). V1: WARN-only (exit 0). `--strict` → exit 1 на findings. Space-safe (tmpfile для find). Bash 3.2+ compatible.
- **`templates/scripts/validate-mermaid-syntax.sh`** — dual-copy G-103 (diff -q identical).
- Закрывает R-031 (architecture-audit 2026-06-10, status proposed).

**Что делать consumers:**
- После sync: `bash scripts/validate-mermaid-syntax.sh --root .` — увидеть structural anti-patterns в своих mermaid-диаграммах (WARN, не блок).
- TRANSLIT-LABEL словарь расширяем через header скрипта `TRANSLIT_WORDS=...`.

---

## v5.48.0 — feat: diagram-freshness engine (PLAN-H) — diagram-sources annotations + G-114 fix (2026-06-12)

**Что:**
- **`scripts/validate-maps-coverage.sh`** (UPGRADED) — добавлен generic движок `_check_diagram_freshness`. Каждый mermaid-блок в living-scope `.md` файлах проверяется через `<!-- diagram-sources: ... -->` annotation. Типы: `table:<Section>`, `list:<Section>`, `max-version:<Section>`, `axes` (skip), `none` (skip). UTF-8-safe (full-string `grep -F`, не `cut -c`). WARN на отсутствие annotation и на стейл-диаграмму. Config: `DIAGRAM_FRESHNESS_SEVERITY="warn"`.
- **Annotations backfilled** во всех living-map файлах documentation repo (ROADMAP.md, SYSTEM-MAP.md, USER-MAP.md×2, ARTIFACT-MAP.md×2).
- **ROADMAP.md Now-секция** актуализирована: заменена Freshness-механизм batch (PLAN-H/C/G/I); DoneBlob обновлён до `v5.47.0`.
- **CLAUDE.md Maps Standard Rule** — добавлено правило `diagram-sources` annotation convention (закрытый enum, severity config, validate-maps-coverage wiring).
- **PLAN-G plan doc** — `auto:diagram-freshness` добавлен в маркер-enum (закрытый, теперь 6 значений).
- **G-114 зафиксирован → fixed**: `_check_roadmap_axis` парсил только bullets (awk `/^[-*]/`), Done-секция ROADMAP.md использует pipe-table → false-negative. Новый движок обрабатывает оба формата.

**Что делать consumers:**
- После sync: annotation convention из CLAUDE.md Maps Standard применима к consumer проектам — добавлять `<!-- diagram-sources: axes -->` (или конкретный тип) перед mermaid.live URL в living maps.
- `validate-maps-coverage.sh --report` покажет mermaid-блоки без annotation (WARN, не блок).
- **Уже существующие consumers:** при первом запуске `--report` увидят WARN по неаннотированным блокам — backfill нужен только для living maps (файлы с данными, не концептуальные диаграммы).

---

## v5.47.0 — feat: maps-coverage gate + validate-maps-coverage.sh + sync-audit Gap 15 (2026-06-11)

**Что:**
- **`scripts/validate-maps-coverage.sh`** (NEW) — проверяет что каждая команда/skill/скрипт присутствует в картах (USER-MAP, ARTIFACT-MAP, SYSTEM-MAP). Режимы: `gate` (exit 1 — deploy блокируется) / `--report` (exit 0, WARN-only — для консьюмеров). Config-матрица в верху файла. POSIX Bash 3.2, CRLF-safe.
- **`scripts/deploy-push.sh`** — gate перед push: maps-coverage + mermaid links (code + doc repo) для methodology-platform. Closes класс "deploy прошёл, карты устарели" (L4).
- **`commands/sync-audit.md`** — Gap 15: Maps coverage audit (`--report` режим). 15 проверок.
- **`commands/plan.md`** — Подшаг -0.2: Skipped-commitments backlog. Показывает `skipped`/`deferred` пользователю перед планированием.
- **Backfill карт:** USER-MAP (+`/push-only`, `/init-consumer`, skills `secrets-management`/`design-spec`/`testing-strategy`); ARTIFACT-MAP (+`/pull`, `/push-merge`, `/push-only`, `/test`, `/push-consumers`, `/init-consumer`, `CODE-GAPS.md`); SYSTEM-MAP (полный реестр 20 команд, reorganized scripts, `git-credential-from-env.sh`, R-030 de-count).

**Что делать consumers:**
- После sync: `bash scripts/validate-maps-coverage.sh --report` — увидеть gaps в своих картах (не блокирует).
- Gap 15 в `/sync-audit` — аудит карт без блока.
- `deploy-push.sh` gate активен только в methodology-platform (guard `[ -d "commands" ] && [ -f "scripts/sync-methodology.sh" ]`); у consumers не срабатывает.
- `commands/plan.md` Подшаг -0.2 доедет при следующем sync.

---

## v5.46.0 — refactor: /sync-audit Gap 14 replaces /init-consumer (2026-06-11)

**Что:**
- **`commands/sync-audit.md`** — Gap 14: `[no-marker]` consumer initialization (init/skip/never + `new-project-init.sh`). 14 проверок вместо 13.
- **`commands-local/init-consumer.md`** — **удалён**. Логика перенесена в Gap 14.
- **`templates/model-tiers.md`** — строка `/init-consumer` удалена.
- **`commands-local/pull-consumers.md`** — ссылки на `/init-consumer` → `/sync-audit`.

**Что делать consumers:** `commands/sync-audit.md` синхронизируется → consumers получают Gap 14 автоматически при следующем `sync-methodology.sh`. `/init-consumer` была LOCAL-ONLY — consumers её не имели, ничего не теряют.

**Архитектурное обоснование:** slash-команда = пользовательский интерфейс; скрипт = реализация. `/init-consumer` была излишней: `scripts/new-project-init.sh` вызывается из `/sync-audit` напрямую.

---

## v5.45.0 — feat: /init-consumer + exclude_paths (PLAN-06) (2026-06-11)

**Что:**
- **`commands-local/init-consumer.md`** — новая LOCAL-ONLY команда. Per-repo init / skip / never. `never` → `exclude_paths`. Закрывает command-first violation.
- **`commands-local/pull-consumers.md`** — exclude_paths filter (Подшаг 0.2) + Summary → `/init-consumer` + Troubleshooting fix.
- **`templates/model-tiers.md`** — строка `/init-consumer Fast LOCAL-ONLY`.

**Что делать consumers:** эта команда LOCAL-ONLY — consumers не получают её через sync. Но `templates/model-tiers.md` обновлён → `sync-methodology.sh` доставит обновлённый model-tiers.

---

## v5.44.0 — feat: /sync-audit Gap 13 — branch protection verify (PLAN-07b) (2026-06-11)

**Что:**
- **`commands/sync-audit.md`** Gap 13: если `mode: team` + GitHub + `gh` CLI → inline `gh api` verify branch protection. 🔴 High WARN если protection отсутствует; graceful skip для GitLab / solo / нет `gh` / нет прав.

**Что делать consumers:** `bash scripts/sync-methodology.sh .` → получить обновлённый `sync-audit.md` с Gap 13. Если `mode: team` + GitHub: следующий `/sync-audit` автоматически проверит protection.

---

## v5.43.0 — feat: branch protection + GH006 classifier + merge retry (PLAN-07) (2026-06-11)

**Что:**
- **`scripts/setup-branch-protection.sh`** (methodology-only, НЕ синхронизируется консьюмерам) — apply/--verify/--off. Закрывает HIGH-риск «Прямой push в main».
- **`deploy-push.sh`** (оба: `scripts/` + `templates/scripts/`) — GH006 branch в `_classify_push_failure`: при блоке branch protection направляет на PR-путь (не ложный auth-flow). Merge retry 3s для transient «not mergeable».
- **`CLAUDE.md § Security`** — «Прямой push в main (High)» → Mitigated.
- **ADR-002** — amendment: pr_tool:auto-merge supersedes фазу 1; branch protection in-scope для methodology repos.

**Что делать consumers:** `bash scripts/sync-methodology.sh .` → получить обновлённый `templates/scripts/deploy-push.sh` с GH006-классификатором. Для включения protection на своём репо — requires GitHub + `gh` CLI + отдельный `setup-branch-protection.sh` (не синкается, methodology-specific).

---

## v5.42.0 — feat: /push-consumers + drift visibility + validate-lar.sh в templates/scripts/ (PLAN-05) (2026-06-11)

**Что:**
- **`commands-local/push-consumers.md`** — новая LOCAL-ONLY команда `/push-consumers`: drift-таблица (version/Δ/статус), dirty-pre-check, батч-подтверждение, batch sync, write-only (без git commit в консьюмерах). Командный интерфейс к массовому обновлению.
- **`templates/scripts/validate-lar.sh`** — dual-use копия validate-lar.sh для консьюмеров (G-112c). Заголовок «канон scripts/ — менять синхронно».
- **`commands-local/pull-consumers.md`** — drift-колонка в report (version/Δ/статус). Видимость без явного пуша.
- **`templates/model-tiers.md`** — строка `/push-consumers: Default tier`.
- **Первый прогон:** 6/6 консьюмеров обновлены v4.10.6–v4.60.0 → v5.41.0 (write-only, без коммита агента). validate-lar.sh доехал до ebay, validate-mermaid-links.sh в erp.

**3-й [domain:sync] в DEVLOG — порог /diagnose:** корень известен (PLAN-05 этот PR). /diagnose не требуется.

**Что делать consumers:** `bash scripts/sync-methodology.sh .` → получить обновлённые команды + validate-lar.sh.

---

## v5.41.0 — feat: Pre-Mortem категория 7 «Execution context» (closes R-032) (PLAN-04) (2026-06-11)

**Что:**
- **`/plan` Шаг 98:** добавлена категория 7 «Execution context» (Windows/cp1252, non-TTY hook, two-repo cwd, parallel-session lock, missing dependency). Few-shot: G-097, G-098, v5.32.0. Прежний пункт 7 (over-engineering) → пункт 8. Счётчик «8 сценариев».
- **`/retro` Шаг 4.6:** «6 категорий» → «7 категорий», список обновлён с `Execution context`. Примечание «зеркало — менять синхронно».
- **R-032 → implemented** (v5.41.0) в `global.last_architecture_audit.recommendations`.

**Что делать consumers:** `bash scripts/sync-methodology.sh .` → обновить команды.

---

## v5.40.0 — fix: auto-pull failure surfacing — error capture + re-notify + /plan floor (PLAN-03) (2026-06-11)

**Что:**
- **`auto-update-watchdog.template.py` error capture:** при `returncode != 0` сохраняет error excerpt (первые 300 символов stderr/stdout, `errors=replace`) в `last_auto_pull.error` в triggers.json. Additive field — graceful read через `.get()`.
- **Re-notify при каждом SessionStart:** если `last_auto_pull.status == "failed"` — печатает `⚠️ Прошлый auto-pull FAILED: <error excerpt>. Запусти /sync-audit` до момента пока status не сменится на success. Не один раз — постоянно.
- **`/plan` Шаг -3 Подшаг -0.3:** floor check `last_auto_pull.status == "failed"` → 🔵 предупреждение с error excerpt. Fate-independent layer (работает даже если hook мёртв).
- **Диагностика инцидента (2026-06-11T13:58:38):** ручной `sync-methodology.sh .` exit=0. Root cause: вероятно параллельная сессия держала `.auto-update.lock` или dirty-git-status во время SessionStart.

**Что делать consumers:** `bash scripts/sync-methodology.sh .` → обновить хук.

---

## v5.39.0 — fix: triggers.json state hygiene — дедуп ключей + validate-triggers.sh (PLAN-02) (2026-06-11)

**Что:**
- **Миграция triggers.json:** удалены top-level дубли `last_retro`/`last_architecture_audit`, смержены в канонические `global.*` с объединением recommendations (R-030..033 + S-1..3 = 7 записей).
- **Новый `scripts/validate-triggers.sh`:** детектор дубль-ключей (global.X vs top-level X). Bash 3.2, python-интерпретер резолвер. Exit 1 при нарушении с именованием конкретных дублей; WARN-SKIP при отсутствии файла.
- **Команды исправлены:** `/retro`, `/architecture-audit`, `/plan` — все инкременты и чтения теперь используют явный путь `global.last_*` (было bare `last_*` без `global.`).
- **templates/scripts/validate-triggers.sh** — dual-use копия для консьюмеров.

**Что делать consumers:** `bash scripts/sync-methodology.sh .` → получить `scripts/validate-triggers.sh` + обновлённые команды.

---

## v5.38.0 — fix: validate-lar.sh two-repo auto-detect + WARN-SKIP (PLAN-01) (2026-06-11)

**Что:**
- **`validate-lar.sh` auto-detect 3-уровневый:** (1) `$ROOT/docs/architecture/LIVING-ARTIFACTS.md`; (2) `--doc-root` если задан; (3) `doc_repo_path` из `CLAUDE.local.md` (two-repo без явных аргументов). Ранее SKIP→exit 0 при отсутствии LAR под `--root` — теперь WARN-SKIP с явным списком искавшихся путей.
- **Фикс sed first-match:** скрипт брал последний бэктик-пэр строки (greedy sed) вместо первого → ложный MISSING_FILE. Теперь корректно берёт первую колонку таблицы.
- **Битый путь в LAR исправлен:** `CLAUDE_LOCAL.template.md` → `templates/CLAUDE_LOCAL.template.md` в строке sync-audit.md команды.
- **`/sync-audit` Gap 10 упрощён:** универсальный вызов `bash scripts/validate-lar.sh` (без аргументов) работает для single-repo и two-repo автоматически.

**Что делать consumers:** `bash scripts/sync-methodology.sh .` → обновить `scripts/validate-lar.sh`. Вызов без аргументов теперь стандартный.

---

## v5.37.0 — feat: ROADMAP Done-trigger reactive path + Gap 12 (P-008) (2026-06-11)

**Что:**
- **ROADMAP Done-trigger rule расширен (CLAUDE.md + /code Шаг 5):** planner path (из ## Now → переместить) + reactive path (gap → /plan → /code → создать новую строку Done). Закрывает P-008: реактивные methodology milestone'ы больше не пропускают ROADMAP.Done.
- **`/sync-audit` Gap 12 (ROADMAP.Done vs DEVLOG milestone sync):** обнаруживает `[milestone]` теги в DEVLOG без соответствующей записи в ROADMAP.Done. Detection layer для P-008.
- **Backfill ROADMAP.Done:** добавлены записи v5.34.0, v5.35.0, v5.36.0 (три пропущенных реактивных milestone).

**Что делать consumers:** `bash scripts/sync-methodology.sh .` → получить обновлённые команды.

---

## v5.36.0 — feat: /sync-audit Gap 11 — config-recommendations для консьюмеров (2026-06-11)

**Что:**
- **`/sync-audit` Gap 11 (config-recommendations)** — новая gap-проверка: читает `CLAUDE.local.md` консьюмера, сравнивает `worktree_isolation` / `enabled` / `interval_hours` с эталоном методологии, предлагает `/plan` на каждое отклонение. Методология теперь «пушит» рекомендации конфигов при каждом audit. Closes G-111.
- **Заголовок `## Шаг 1`** обновлён: «5 проверок» → «11 проверок».

**Что делать consumers:**
```bash
bash scripts/sync-methodology.sh .
# Затем запустить /sync-audit — Gap 11 покажет отклонения конфигов с рекомендациями
```

**Приоритет:** 🟡 Medium — config drift обнаруживается автоматически; изменения через /plan по решению владельца.

---

## v5.35.0 — feat: worktree auto для routine multi-session + G-025 consumer-reach checkpoint (2026-06-11)

**Что:**
- **methodology `CLAUDE.local.md`** — `worktree_isolation: off → auto` (owner routinely runs concurrent sessions; M0 verify passed на Git Bash/Windows 2026-06-11). Каждая сессия в своём worktree+ветке `ai-dev/<task>` — dirty-коллизии невозможны by-construction. Closes G-108.
- **`/plan` Шаг -1.3 G-025** — расширен с file-scope на feature-scope: обязательная строка «Consumer-охват» для любого `[methodology]` изменения (не только при новом файле). Closes G-109 — агент structurally не забывает консьюмеров.
- **`CLAUDE.md`** — Parallel-session rule (одна строка).
- **`ADR-002`** — критерий auto-vs-disciplined-off + re-rejection M2-детектора (зафиксировано чтобы не предлагался 4-й раз).
- **`USER-MAP`** — consumer guidance «когда включать auto».

**Что делать consumers:**
```bash
# Если routinely запускаешь ≥2 сессии одновременно:
# 1. Проверь что worktree работает:
git worktree add ../wt-test -b wt-test && git worktree remove ../wt-test && git branch -D wt-test
# 2. Если OK — поставь в CLAUDE.local.md ## Branching:
#    worktree_isolation: auto
# Если worktree не работает (Git Bash < 2.5) — оставь off, commit-discipline защищает.
bash scripts/sync-methodology.sh .
```

**Приоритет:** 🟡 Medium — methodology repo flip (own config); consumers opt-in вручную.

---

## v5.34.0 — fix: /sync-audit авто-синхронизирует consumer с клоном методологии (G-107) (2026-06-11)

**Что:**
**Consumer-vs-clone auto-sync в /sync-audit Шаг -0.5 (closes G-107):** `/sync-audit` теперь автоматически обнаруживает и устраняет расхождение между consumer `.claude/.version` и клоном методологии. Выполняется после каждого remote-check (клон актуален или только что обновлён) — читает версии обоих, при delta запускает `sync-methodology.sh <consumer_root>` без вопроса. Один `/sync-audit` = полный цикл: remote check + pull клона + apply consumer.

**Реальный инцидент (G-107):** consumer client-matz на v4.60.0 (+73 версии позади), `/sync-audit` показывал «актуально» потому что сравнивал consumer с клоном (оба v4.60.0), не замечая что клон сам устарел. После pull клона — consumer не синхронизировался автоматически. 20+ команд и все 14 skills отсутствовали.

**Consumer action:** `bash scripts/sync-methodology.sh .` — после этого новый подшаг активен в каждом `/sync-audit`.

**Breaking:** нет (аддитивный подшаг; self-dogfood guard исключает methodology-platform).

---

## v5.33.0 — feat: self-apply automation + ROADMAP Done-trigger + G-101/G-102/G-103 (2026-06-11)

**Что:**
1. **Self-apply L4 automation:** `deploy-push.sh` теперь автоматически запускает `sync-methodology.sh .` после каждого merge через guard `[ -d commands ] && [ -f scripts/sync-methodology.sh ]`. Guard различает methodology-platform (true) от consumers (false) — consumers не затронуты. Решает проблему «новые команды/skills не видны после деплоя» системно, без ручного шага.
2. **Skills fix:** `sync_skills()` теперь выполняется и при self-apply (убран `IS_SELF_APPLY == false` guard). `.claude/skills/` создаётся при каждом `sync-methodology.sh .`.
3. **ROADMAP Done-trigger (G-101):** `/code` Шаг 5 добавлено правило — при завершении milestone переместить запись из `## Now` в `## Done` в том же PR. CLAUDE.md **ROADMAP Done-trigger rule** документирует правило.
4. **Recommendation-first rule (G-102):** CLAUDE.md добавлено правило — при clarifying question агент обязан дать рекомендацию до вопроса.
5. **Shared-artifact check (G-103):** `/plan` Шаг -1.3 для `[methodology]` добавлен explicit check: изменяя `scripts/` или `templates/` под self-нужды → проверить существует ли `templates/scripts/<имя>` (consumer-sync признак) + нужен ли guard.
6. **sync-audit self-note:** документировано что для `methodology_path: .` sync-audit делает self-аудит (версионный delta всегда 0, форматные gaps проверяются нормально).

**Consumer action:** `bash scripts/sync-methodology.sh .` после деплоя — после этого self-apply встроен навсегда.

**Breaking:** нет (guard = additive; новые правила не меняют существующие команды).

---

## v5.32.0 — fix: validate-lar.sh --doc-root (two-repo support) + SYSTEM-MAP hybrid labels (2026-06-11)

**Что:** два gap из `/sync-audit`:
1. `validate-lar.sh` выдавал 8 false MISSING_FILE ошибок для two-repo setups: пути из doc-repo (ROADMAP.md, DEVLOG.md, VISION.md и др.) не находились потому что скрипт умел только один `--root`. Добавлен `--doc-root`: пути не найденные в `--root` дорезолвятся в `--doc-root`. Backwards-compatible: без `--doc-root` поведение идентично предыдущей версии (single-repo consumers не затронуты).
2. `SYSTEM-MAP.md` содержал EN-only edge labels (`reads`, `writes`) — нарушение hybrid language rule (CLAUDE.md Maps Standard). Заменены на RU (`читает`, `пишет`); версия v2.1 → v2.2; URL mermaid.live обновлён.

**Изменения:**
- `scripts/validate-lar.sh`: добавлен `--doc-root <dir>` (опциональный второй корень); graceful check `test -d` перед `cd`; WARNING (не error) при недоступном `--doc-root`
- `commands/sync-audit.md` Gap 10: обновлён вызов — при two-repo передаёт `--doc-root <doc_repo_path>`
- `docs/architecture/LIVING-ARTIFACTS.md` (doc-repo): исправлен путь `auto-update-watchdog.py` → `auto-update-watchdog.template.py`; удалена строка `.code-workspace` (файл вне обоих repos); обновлён Detection для `validate-lar.sh`
- `docs/architecture/SYSTEM-MAP.md` (doc-repo): EN-only edge labels → RU; версия v2.2; mermaid.live URL обновлён

**Actions:**
```
bash scripts/sync-methodology.sh .    # подтянуть обновлённый скрипт + команду
# two-repo вызов из /sync-audit Gap 10:
bash scripts/validate-lar.sh \
  --root . \
  --lar ../project-documentation/docs/architecture/LIVING-ARTIFACTS.md \
  --doc-root ../project-documentation
```

**Priority:** 🟡 Medium — fix false positives в /sync-audit Gap 10; hybrid label compliance.

---

## v5.31.0 — feat: validate-lar.sh — детектор файлов Living Artifact Registry (2026-06-11)

**Что:** Living Artifact Registry создан (v5.30.0), но нет инструментального способа проверить что файлы перечисленные в нём реально существуют на диске. Добавлен `scripts/validate-lar.sh` — exit 0 если все пути существуют, exit 1 с `MISSING_FILE:` строками если нет. Wired в `/sync-audit` Gap 10.

**Изменения:**
- `scripts/validate-lar.sh`: новый скрипт (Bash 3.2+, POSIX-compatible). Флаги: `--root <dir>` (repo root для резолвинга путей), `--lar <path>` (явный путь к LAR-файлу). Авто-detect при отсутствии `--lar`
- `commands/sync-audit.md` Gap 10: обновлён — теперь вызывает `validate-lar.sh`, документирует two-repo usage

**Actions:**
```
bash scripts/sync-methodology.sh .    # подтянуть новый скрипт
# Проверить свой LAR (single-repo):
bash scripts/validate-lar.sh
# Проверить LAR (two-repo, methodology-platform):
bash scripts/validate-lar.sh --root . --lar ../project-documentation/docs/architecture/LIVING-ARTIFACTS.md
```

**Priority:** 🟢 Low — вспомогательный детектор; не блокирует workflow.

---

## v5.30.0 — feat: Living Artifact Registry (LAR) — единая точка lifecycle для механизмов (2026-06-11)

**Что:** нет единой точки «что живёт и требует поддержания» в проекте — /plan Шаг -1.3 Adjacent Impact не видел связанные артефакты, Sustainment Declaration оставалась только в triggers.json без persistent registry. LAR = lifecycle-реестр (не flow-граф): когда обновлять, как обнаружить устаревание, кто владелец. Интегрирован в /plan, /code, /review, /sync-audit.

**Изменения:**
- `templates/LIVING-ARTIFACTS.template.md`: новый шаблон LAR (синхронизируется консьюмерам). Колонки: Артефакт · Тип · Trigger обновления · Кто обновляет · Detection · Связанные артефакты
- `commands/plan.md` Шаг -1.3: LAR lookup — читать «Связанные артефакты» колонку для adjacent impact
- `commands/plan.md` Шаг 97: LIVING-ARTIFACTS.md добавлен как класс Sustainment — обязательна строка для нового механизма
- `commands/code.md` Шаг 5: новый пункт «LIVING-ARTIFACTS.md update» (PR-coupling, аналогично Design Spec)
- `commands/review.md` Sustainment gate: LAR cross-check — новый механизм в diff без строки в LIVING-ARTIFACTS.md → 🔴
- `commands/sync-audit.md`: Gap 10 (LIVING-ARTIFACTS.md presence) + строка в report-таблице

**Actions:**
```
bash scripts/sync-methodology.sh .    # подтянуть новый шаблон и обновлённые команды
# Создать LAR для своего проекта:
cp templates/LIVING-ARTIFACTS.template.md docs/architecture/LIVING-ARTIFACTS.md
# Затем populate из /plan Шаг 97 истории
```

**Priority:** 🟡 Medium — новый артефакт, не ломает существующие механизмы. Gap 10 в /sync-audit поможет обнаружить consumer-проекты без LAR.

---

## v5.29.0 — feat: Design Spec верификация + lifecycle — Anti-Hallucination gate + PR-coupling (2026-06-11)

**Что:** Design Spec мог переводиться в `Final` без проверки реализуемости — галлюцинации и нереализуемые требования попадали в спецификацию незамеченными. Плюс: `/plan` и `/code` не требовали обновления Design Spec при изменении фичи → документ устаревал молча.

**Изменения:**
- `skills/design-spec/SKILL.md` Шаг 5: добавлен блок «Верификация реализуемости (Anti-Hallucination gate)» — 4 проверки перед Final: source каждого механизма, ADR drift check, выполнимость примеров, OQ для допущений
- `templates/DESIGN_SPEC.template.md`: новая секция `## Верификация` (между §6 и §7) — 8-пунктовый checklist с явным gate `[ ] Все OK → Final / [ ] Остались открытые → Draft`
- `commands/plan.md` Шаг 97: Design Spec добавлен как класс артефактов требующих Sustainment — PR-coupling rule + STALE detection через `git log -1`
- `commands/code.md` Шаг 5: новый пункт «Design Spec update» — `git log` comparison, graceful skip если нет Design Spec для фичи

**Actions:** (поведенческое правило — sync доставляет обновлённые команды и шаблон)
```
/sync-audit   # подтянуть обновлённую методологию
# При создании/обновлении Design Spec — шаблон теперь содержит § Верификации
```

**Priority:** 🟡 Medium — структурный guard для quality Design Spec; не ломает существующие docs.

---

## v5.27.0 — feat: domain-aware /diagnose trigger — кластер симптомов одного корня детектится рано (2026-06-10, closes S-1)

**Что:** `/diagnose` триггер «N-й фикс» grep'ал DEVLOG по **точному** `[fix:X]` тегу → кластер симптомов одного корня с разными surface-тегами (`consumer-push`/`deploy-push`/`command`) не группировался → /diagnose не срабатывал, корень назывался поздно (push-кластер v5.19-5.24: 9 симптомов до того как P-006 назван). Фикс: CLAUDE.md D6 теперь требует **`[domain:X]` indicator** рядом с `[fix:X]` (общий для всех фиксов одного корня); `/plan` Шаг -1.3 п.3 + `/diagnose` grep'ают DEVLOG **двумя проходами** — точный тег (fallback) + `[domain:X]`. `[domain:X] ≥ 2` → /diagnose предлагается на 3-м фиксе домена даже при разных surface-тегах. Старые записи без domain → graceful fallback на точный grep.

**Actions:** (поведенческое правило — sync доставляет CLAUDE.md + команды)
```
/sync-audit   # подтянуть обновлённую методологию
# При [fix:X] в DEVLOG добавляй [domain:<git-push|secrets|sync|...>] для кластер-детекта
```

**Priority:** 🟡 Medium — структурный фикс из /architecture-audit: кластер одного корня детектится на 3-м симптоме, не на 9-м.

---

## v5.26.0 — feat: Roadmap visualization + G-100 pako-fidelity fix (2026-06-10, closes G-100)

**Что:** ROADMAP.md получил секцию `## Визуальный roadmap` — mermaid-диаграмма с цветовым кодом статусов (Done/Now/High/Med/Low/Hold), двухстрочными «зачем:»-labels, collapse-политикой Done и affordance-узлом `/scope-out`. Шаблон `templates/ROADMAP.template.md` обновлён. Структурный фикс G-100: pako-URL теперь **никогда не проходит через генерацию модели** — `update-mermaid-links.sh` пишет URL прямо в файл, агент линкует строку файла. `/plan` Шаг 99.54 обновлён: Путь A = `update-mermaid-links.sh _tmp_draft-maps.md` + ссылка на файл. CLAUDE.md: roadmap-view строка в Maps Standard supporting views, pako-prohibition правило в Mermaid link rule, in-progress signal (незакоммиченные файлы = сигнал активной работы). `/sync-audit` получил Gap 9. `/product-review` и `/product-vision` получили шаг PR-coupling roadmap.

**Actions:**
```
/sync-audit         # подтянуть обновлённые templates/ROADMAP.template.md, /plan, /sync-audit, /product-review, /product-vision
```

**Consumer impact:** Если ROADMAP.md существует — `/sync-audit` Gap 9 покажет 🟡 Medium (нет секции). Добавить вручную по шаблону (контент project-owned). Шаблон в `templates/ROADMAP.template.md ## Визуальный roadmap`.

**Priority:** 🟢 Low — additive feature. Структурный фикс G-100 — 🟡 Medium (предотвращает класс bitURL).

---

## v5.25.0 — feat: Sustainment Declaration — жизнеобеспечение механизмов в /plan + /review gate (2026-06-10, closes G-099)

**Что:** `/plan` получил Шаг 97 «Sustainment Declaration» — обязательный per-артефакт анализ для каждого механизма, создаваемого или изменяемого планом: Trigger · Refresh · Detection · Owner. Результат выводится пользователю как отдельная секция «## Жизнеобеспечение». `/review` получил Sustainment gate в Completeness check: новый механизм в diff без декларации → 🔴 блок. Закрывает класс G-099 (≥10 инстансов: hooks/mermaid-links/sync-audit/workspace-list/etc. создавались без lifecycle-дизайна → умирали тихо). Добавлен `last_plan_session.sustainment[]` в `triggers.json` — аддитивное поле, старые consumers читают gracefully.

**Actions:**
```
/sync-audit         # подтянуть обновлённые /plan + /review + triggers.json.template
```

**Consumer impact:** `merge_triggers_json` дозальёт поле `sustainment: []` при следующем sync. Поведение в /review: если поле отсутствует (старый план) → 🔵 info, не блок.

**Priority:** 🟡 Medium — методологическое правило, не breaking. Следующий Full /plan автоматически потребует Шаг 97.

---

## v5.24.0 — feat: /pull --current — pull только текущего репо (2026-06-10, closes G-091)

**Что:** `/pull` добавлен режим `--current` — pull ТОЛЬКО текущего репо (`git pull --ff-only` текущей ветки, без workspace-парсинга и без `consumer-pull.sh`). Дефолт `/pull` (весь workspace) не меняется. Закрывает G-091: раньше простого pull одного репо не было — `/pull` всегда тянул весь workspace, для одного репо приходилось в терминал `git pull` (против command-first G-095). Pre-pull чистота + detached-HEAD guard + нет-origin guard.

**Actions:**
```
/sync-audit         # подтянуть обновлённую /pull
/pull --current     # теперь: pull только текущего репо
/pull               # как раньше: весь workspace
```

**Priority:** 🟢 Low — UX/command-first: частая операция (pull одного репо) теперь команда, не терминал. Дефолт не сломан.

---

## v5.23.1 — fix: /sync-audit явно предупреждает что команды stale до рестарта (2026-06-10, closes G-098)

**Что:** после auto-apply `/sync-audit` обновлял команды на диске, но restart-напоминание было одной строкой → пользователь не понимал что ТЕКУЩАЯ сессия держит СТАРЫЕ версии команд до рестарта. Реальный симптом: консьюмер на v5.22.0 показал старое auto_pull-поведение («не установлен → спрашивает»), хотя файл на диске уже имел новую семантику («не установлен → авто») — сессия читала старую команду из контекста. Усилено restart-предупреждение: явно «до рестарта всё поведение — СТАРОЙ версии, файлы новые но сессия перечитает только после рестарта».

**Priority:** 🟢 Low — UX/discovery, текст команды. Не меняет механику.

**NB:** это НЕ баг семантики auto_pull (инверсия v5.20.0 корректна и доехала) — про session-reload lifecycle Claude Code.

---

## v5.23.0 — fix: consumer-pull.sh interpreter-резолвер — больше не «пуллю вручную» на Windows (2026-06-10, closes G-097)

**Что:** `consumer-pull.sh` (за `/pull`) использовал голый `python3 -c` для парсинга `.code-workspace` → на Windows `python3` отсутствует (только `py`) → скрипт падал, `/pull` деградировал в «пуллю вручную». Рецидив G-081 (Windows python3 hardcode) — класс был решён в 6 скриптах резолвером `for _cmd in py python3 python`, но `consumer-pull.sh` (инлайн python) пропущен. Теперь резолвер выбирает `py` на Windows → workspace парсится → `/pull` работает автоматически.

**Actions:**
```
/sync-audit   # подтянуть исправленный consumer-pull.sh
```

**Priority:** 🟡 Medium — `/pull` на Windows-консьюмерах перестаёт деградировать в ручной режим.

**NB:** overlap `/pull` ↔ `consumer-pull.sh` (зачем тяжёлый multi-repo pull при простом /pull) — отдельный вопрос G-091, не закрыт этим фиксом.

---

## v5.22.0 — feat: secrets-manifest = single source of truth для git-remote (2026-06-09, closes P-006)

**Что:** методология теперь имеет SSOT для «куда пушить». Git-секрит в `secrets-manifest.yaml` можно пометить `git_remote: true` — его `service_url` становится каноническим адресом push/pull. Push-команды (`/push-merge`, `/deploy`) перед push сверяют `git remote origin` с manifest и при расхождении **предлагают выровнять** remote под manifest (`git remote set-url`, с подтверждением — не молча). Закрывает корень push-инцидентов (G-083/P-005/G-094 — все были симптомами «нет SSOT для remote»): агент теперь определяет target+auth из secrets детерминированно, не из возможно-неверного git remote.

**Авто-определение:** без флага, если ровно один `service_url` оканчивается на `.git` — он считается git-remote. Несколько → fallback на git remote (graceful). Старые manifest без поля работают без изменений.

**Actions:**
```
/sync-audit   # подтянуть обновлённые push-скрипты
# Пометь git-секрет в .claude/secrets-manifest.yaml:  git_remote: true
# (если используешь GitLab/иной хост — service_url должен быть ПОЛНЫМ repo URL с .git)
```

**Priority:** 🟡 Medium — устраняет класс «push стучится не туда»; агент определяет remote из secrets.

---

## v5.21.0 — feat: command-first позиционирование — AI engineer как первичная персона (2026-06-09, closes G-095)

**Что:** зафиксирована первичная персона методологии — **AI engineer** (оркеструет AI через команды/skills, не запускает скрипты руками). PRODUCT.md «Целевые пользователи» переписан (AI engineer 🥇 первичный, developer/team lead вторичные). CLAUDE.md ## Workflow rules — новый **Command-first invariant**: агент не рекомендует пользователю `bash scripts/...`, направляет на команду; новая consumer-операция обязана иметь command/skill точку входа. Скрипты **не скрыты** — остаются доступны как внутренняя реализация, просто не рекомендуются как пользовательский путь.

**Actions:** (поведенческое правило — sync подтягивает обновлённый CLAUDE.md banner)
```
/sync-audit   # подтянуть обновлённую методологию (command-first, не bash-скрипт!)
```

**Priority:** 🟢 Low — позиционирование/поведение агента; не меняет механику команд.

---

## v5.20.0 — fix: /sync-audit обновляется автоматически без вопроса (2026-06-09, closes G-094)

**Что:** `/sync-audit` Шаг -0.5 при обнаружении обновлений methodology больше **не спрашивает** «a/b/c» — делает `git pull --ff-only` + `sync-methodology.sh .` **автоматически по умолчанию**. Раньше pull был за вопросом (половинчатая автоматизация — G-092 авто-applied sync ПОСЛЕ pull, но pull оставался ручным). Pre-pull safety: проверяется `git status --porcelain` — если в клоне методологии есть незакоммиченные изменения, pull откладывается с инструкцией commit/stash (не трогает правки); diverged (non-ff) → явное сообщение; network/auth → verdict unverified.

**Семантика `auto_pull` инвертирована (⚠️ migration):** раньше `false` (default) спрашивал, `true` = авто. Теперь **не задан / `true`** = авто (default), **`false`** = вернуть вопрос y/n (opt-out для осторожных). Эффект для большинства: обновление стало автоматическим. Кто хочет ручной контроль — ставит `auto_pull: false`.

**Actions:**
```bash
bash scripts/sync-methodology.sh .   # подтянуть обновлённую /sync-audit
# Хочешь подтверждать pull вручную? Добавь в CLAUDE.local.md ## Auto-update:
#   auto_pull: false
```

**Priority:** 🟡 Medium — UX: `/sync-audit` обновляет методологию одной командой без подтверждения.

---

## v5.19.0 — fix: push-диагностика различает 404/403/network + GITHUB_PAT не навязывается GitLab-проектам (2026-06-09, closes G-083 L4 + P-005)

**Что:** push-скрипты (`consumer-push.sh`, `consumer-push-only.sh`, `deploy-push.sh`) больше не печатают «403 / нужен PAT» при ЛЮБОМ провале. Теперь захватывают stderr (LC_ALL=C → детерминированные англ. маркеры), классифицируют причину — **404** (repo не существует → «создать?» или «remote указывает не на ту платформу» если remote-host ≠ secrets-manifest service_url), **403** (не тот gh-аккаунт → `gh auth switch`, а не PAT), **network** (хост недоступен — не credential). stderr sanitize маскирует `://user:token@`. В `deploy-push.sh` push был голым (без проверки exit) → шёл в `gh pr create` на непушнутой ветке — теперь прерывается. `secrets-manifest.yaml.template` больше не объявляет `GITHUB_PAT required:true` всем; `new-project-init.sh` определяет платформу из git remote и подсказывает нужный секрет.

**Actions:**
```bash
bash scripts/sync-methodology.sh .   # подтянуть обновлённые push-скрипты
# Если у тебя GitLab/иной remote и в .claude/secrets-manifest.yaml висит лишний
# GITHUB_PAT — удали его (он давал ложный "MISSING" в secrets-show).
```

**Priority:** 🟡 Medium — устраняет хроническую путаницу «нужен GitHub PAT» на не-GitHub remote; push-диагностика теперь self-explaining.

---

## v5.18.0 — feat: /sync-audit auto-apply после pull — одна команда вместо двух (2026-06-09, closes G-092)

**Что:** `/sync-audit` Шаг -0.5 делал `git pull` но не запускал `sync-methodology.sh` — консьюмер стягивал новые commits в methodology repo, но `.claude/commands/` оставались старыми. Теперь после успешного pull (варианты a и b, включая `auto_pull: true`) автоматически выполняется `bash scripts/sync-methodology.sh .` (self-heal, без вопроса). При ошибке sync-apply — показывает явное сообщение вместо молчания.

**Priority:** 🟡 Medium — UX: консьюмер получает актуальные команды сразу после `/sync-audit`, без второй команды.

**Actions:**
```bash
bash scripts/sync-methodology.sh .
```

---

## v5.17.0 — fix: /sync-audit pull без PAT — прямой git pull для публичного репо (2026-06-09, closes G-091)

**Что:** `/sync-audit` Шаг -0.5 предлагал `with-secret.sh GITHUB_PAT` как рекомендуемый вариант для pull обновлений methodology. Для публичного репо PAT не нужен — `git pull` работает анонимно с любым git-хостингом (GitHub, GitLab и др.). Новый вариант (a): прямой `git pull origin main --ff-only`; при auth-ошибке (прокси) — вариант (b) с `gh auth login`.

**Priority:** 🟢 Low — улучшение UX для консьюмеров без PAT в `.env`; не ломает существующее поведение.

**Actions:**
```bash
bash scripts/sync-methodology.sh .
```

---

## v5.16.0 — feat: visual-parity pre-fix protocol — полное закрытие класса + стек-агностичность (2026-06-08, closes G-090)

**Что:** visual-parity задача («привести формы/окна к единому стандарту») разваливалась на рекурсивные частичные раунды — агент закрывал только видимое в текущем скриншоте, пропуск всплывал слоем глубже (одна ось → все оси → под-элемент → источник разметки). G-089 (v5.15.0) закрыл оси, но не под-элементы / эталон / источник.

Достройка `/code` Frontend DOM verification rule (G-089 блок → **visual-parity pre-fix protocol**), три обязательных измерения ДО первого фикса:
- **Эталон-как-артефакт:** зафиксировать целевые значения в артефакт, сравнивать с ним — не с памятью/скриншотом. Формат/место — на усмотрение проекта.
- **Полный чеклист под-элементов:** инвентаризация surface проходит фиксированный набор {заголовок · строки · поля · поиск · футер/пагинация · кнопки · скроллбар · границы}, матрица surface×под-элемент×ось.
- **Component-source check:** один ли компонент-генератор разметки производит сравниваемые surface; разные → стилевой паритет недостижим без per-source override или унификации компонента.

Плюс: блок очищен от framework/проект-частностей (стек-агностичный) — применим на любом UI-стеке.

**Priority:** 🟢 Low — расширение поведенческого правила агента для visual-задач, не ломает существующее, не требует config-изменений.

**Actions:**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```
Срабатывает только для visual-parity задач (≥2 surface, «привести к стандарту»). Не-frontend проекты — правило не активируется.

---

## v5.15.0 — feat: pre-fix baseline measurement — превентивный слой против visual iterative-thrash (2026-06-08, closes G-089)

**Что:** при visual-задаче «выровнять/сделать одинаковым» (CSS/Vue) агент чинил по ОДНОЙ оси различия за итерацию (letter-spacing → font-weight → background), коммитя после каждой — 3-4 итерации с «готово»/«ничего не изменилось» вместо одной. Проблема multi-source: несколько компонентов, у каждого своя ось. Существующие слои (iteration-watchdog, reasoning-ось) — реактивные, ловят ПОСЛЕ залипания; `reset_on_commit: true` делает watchdog слеп к commit-per-iteration.

Превентивный фикс (L3, встроен в существующий Frontend DOM verification ⛔-gate):
- **`/code` Frontend DOM verification rule:** новый **pre-fix baseline** блок — при visual-alignment задаче с ≥2 элементами ОБЯЗАТЕЛЕН один runtime-замер ВСЕХ осей (font-size/weight/letter-spacing/color/background/height/padding) у ВСЕХ элементов в таблицу → все расхождения видны до первого фикса → один фикс закрывает все. Ordering: measure → fix → verify.
- **CLAUDE.local.md `## Iteration watchdog`:** рекомендация frontend-heavy проектам ставить `reset_on_commit: false` (восстанавливает reactive backstop для commit-per-iteration). Default `true` не меняется.

**Priority:** 🟢 Low — поведенческое правило агента для frontend, не ломает существующее, не требует config-изменений.

**Actions:**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```
Frontend-heavy проекты дополнительно: рассмотреть `reset_on_commit: false` в `CLAUDE.local.md ## Iteration watchdog` (опционально, см. секцию). Non-frontend проекты — правило не срабатывает (триггер по visual-alignment + ≥2 элемента).

---

## v5.14.0 — feat: delivery-consistency gate в /review — структурный фикс review-blindness (2026-06-08, R-029)

**Что:** `/review` был на 100% статическим — проверял что НАПИСАНО (hook wired в template), не что РАБОТАЕТ (sync доставит). v5.12.0 прошёл review «0 critical», но `merge_settings_json` не доставлял `.sh`-wiring → поймал только /deploy dogfood post-merge → re-release v5.12.1. Класс «фикс не доезжает молча» (G-087→G-088) ×3, review ни разу не ловил доставку. `[fix:command]×17` за период — command-churn как производное.

Структурный фикс (architecture-audit R-029, L4 не L3 — prose-защита провалилась 3 раза):
- **`scripts/validate-delivery.sh` (новый):** статический delivery-consistency validator. Для каждого hook-ref в `settings.template.json` проверяет (а) файл есть в `templates/.claude/hooks/` (б) `sync-methodology.sh hook_name()` его распознаёт → реально доедет до консьюмера. Рассогласование template↔sync-parser = FAIL. Зеркалит дуальный regex sync (менять синхронно).
- **`validate-template-format.sh` Check 6:** вызывает validate-delivery — **L4 enforcement** через уже-обязательный validator-прогон (/code Шаг 11), не новая prose-инструкция.
- **`/review` Шаг 3 delivery-gate:** PR трогает hooks/settings-template/sync → `validate-delivery.sh` обязателен, FAIL = 🔴 fix now. **N/A escape запрещён** для этого класса.
- **`/code` Шаг 11:** документирован Check 6 delivery-consistency.

Верификация: validator PASS на текущем состоянии; negative-test (sync regex .py-only = v5.12.0 баг) → корректно FAIL «wiring не доедет, ровно v5.12.0 баг». Поймал бы v5.12.0 pre-merge.

**Priority:** 🟡 Medium — усиление review-gate, не ломает существующее.

**Actions:**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```
Для большинства consumers validate-delivery — no-op (нет methodology-internal delivery-поверхности, graceful skip exit 0).

---

## v5.13.1 — fix: /sync-audit live upstream check — больше не врёт "актуальна" на stale клоне (2026-06-08)

**Что:** `/sync-audit` Шаг -0.5 молча рапортовал «версия актуальна» когда локальный клон методологии отставал от upstream (реальный инцидент: ERP-клон v4.68.0, upstream v5.13.0 → «актуальна»). Причина: `git fetch --dry-run` мог тихо упасть/быть пропущен → Шаг 1b сравнивал локальный stale VERSION с `.claude/.version` (оба совпадали т.к. оба stale) → ложное «актуальна».

Изменения (`commands/sync-audit.md` Шаг -0.5 + Шаг 1b):
- `git fetch --dry-run` → **`git ls-remote origin -h refs/heads/main`** — живой upstream HEAD, не зависит от того когда последний раз делали fetch, работает на shallow-клонах.
- Три явных verdict: `up-to-date` (HEAD совпал) / `stale` (upstream впереди) / `unverified` (ls-remote failed). **Только `up-to-date` даёт право написать «актуальна».**
- fetch-fail → «НЕ смог проверить upstream» (не тихий фолбэк на «актуальна»).
- Шаг 1b: `consumer_version = current_version` больше не значит «актуальна» автоматически — гейтится verdict'ом Шага -0.5 (это значит лишь что consumer синхронен СО СВОИМ клоном, не что клон актуален vs upstream).

**Priority:** 🟡 Medium — поведенческий фикс детектора, не ломает существующее.

**Actions:**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```
**NB (мета-парадокс):** этот фикс доедет до консьюнера только ПОСЛЕ обновления его клона методологии. Если консьюмер на сильно старой версии (как ERP v4.68) — сначала **один раз вручную**: `git -C <methodology_clone> pull origin main`, затем `sync-methodology.sh .`. Дальше Шаг -0.5 будет ловить устаревание сам.

---

## v5.13.0 — feat: escalation layers 2+3 — reset_on_commit flag + session gap counter (2026-06-08)

**Что:** завершение escalation-механизма (слой 1 = v5.12.0/1 hook-liveness). Два слоя real-time эскалации на reasoning-залипание.

Изменения:
- **Слой 2 — `reset_on_commit` флаг** в `iteration-watchdog.py` (config в `CLAUDE.local.md ## Iteration watchdog`). Default `true` = текущее поведение (счётчик обнуляется на commit, RPN-150-safe). `false` (opt-in) = счётчик переживает коммиты в пределах сессии → ловит **commit-per-iteration** reasoning-залипание (агент коммитит после каждого фикса одного бага → при `true` ступень-1 N=3 недостижима — ровно CSS-placeholder инцидент).
- **Слой 3 — `session_gap_counter`** в `triggers.json` (новое поле: `session_marker` + `counts`). `/plan` Шаг D + `/diagnose` 6.3.5 инкрементируют счётчик однотипных gap'ов; на пороге (`gap_escalation_threshold`, default 3) — one-shot real-time эскалация «SESSION GAP PATTERN: 3-й <категория> gap за сессию — смени подход». Session-boundary через timestamp-прокси (`gap_session_window_hours`, default 6ч — нет явного session-id в Claude Code). Ловит серию в моменте, в отличие от `recurrence_rate` пост-фактум в `/architecture-audit`.

**Priority:** 🟡 Medium — поведенческое улучшение escalation, backward compatible. `session_gap_counter` — аддитивное поле (merge_triggers_json дозаливает, graceful read), не breaking → minor bump (CLAUDE.md schema-rule уточнён: major только для breaking).

**Actions:**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```
После sync: `triggers.json` получит `session_gap_counter`; `iteration-watchdog.py` поддержит `reset_on_commit`. Опционально настрой пороги в `CLAUDE.local.md ## Iteration watchdog` (см. template). `reset_on_commit: false` рекомендуется для frontend-тяжёлых проектов где commit-per-iteration частый паттерн.

---

## v5.12.1 — fix: merge_settings_json wires direct .sh hooks (hook-liveness delivery) (2026-06-08)

**Что:** критический follow-up к v5.12.0. `merge_settings_json` `hook_name()` распознавал только `.py` хуки в прямых вызовах (`.claude/hooks/X.py`) — новый `hook-liveness.sh` (прямой вызов без run-hook.sh) не распознавался → его SessionStart wiring **не доезжал** до консьюмера при sync (файл копировался, но не wired). Без этого фикса весь v5.12.0 inert на delivery-пути.

Изменения:
- **`sync-methodology.sh` `hook_name()`:** regex `\.py` → `\.(?:py|sh)` — распознаёт прямые `.sh` вызовы. Зеркалит уже-изменённый missing_hooks detection (консистентность всех detection-sites).

**Priority:** 🔴 High — без этого hook-liveness.sh копируется но не активируется у консьюмера.

**Actions:** уже включено в `sync-methodology.sh .` — консьюмеры получат wiring при следующем sync.

**Обнаружено:** dogfood-верификацией в /deploy — own settings.json не получил wiring после self-sync v5.12.0.

---

## v5.12.0 — fix: hook-liveness detector — разрыв рекурсивной дыры доставки хуков (2026-06-08)

**Что:** закрыта рекурсивная дыра G-087 (повтор 3-й раз). Если у консьюмера `settings.json` ссылается на хуки, но сами файлы (в т.ч. `run-hook.sh` — раннер ВСЕХ хуков) отсутствуют на диске → все хуки молча падают, а детектор этой проблемы (`check_hook_health`) сам недоступен, потому что запускается через отсутствующий `run-hook.sh`. Детектор отсутствующих хуков сам отсутствовал.

Изменения:
- **`templates/.claude/hooks/hook-liveness.sh` (новый):** pure-POSIX-sh детектор, вызывается из SessionStart **напрямую** (`sh .claude/hooks/hook-liveness.sh`), БЕЗ `run-hook.sh`. Проверяет физическое наличие каждого hook из settings.json — включая `run-hook.sh`. Способен сообщить об отсутствии `run-hook.sh` не используя его. Рекурсия разорвана.
- **`settings.template.json`:** `hook-liveness.sh` добавлен первым в SessionStart (перед `auto-update-watchdog`).
- **`/plan` Подшаг -0.4:** предикат сменён с «SessionStart wired?» на физическое наличие каждого referenced hook-файла + `run-hook.sh` на диске (always-read floor, ловит когда hook-подсистема мертва целиком).
- **`sync-methodology.sh`:** missing_hooks detection расширен на direct `.sh` вызовы (был только `.py`) — чтобы `hook-liveness.sh` сам верифицировался при доставке.
- **`/pull-consumers` Шаг 3.5 (новый):** cross-consumer детект HOOK-DRIFT после pull — видит все репо разом.

Три fate-independent детектора: `hook-liveness.sh` (SessionStart, без run-hook.sh) → `check_hook_health` (runtime, когда хуки живы) → `/plan` -0.4 (always-read, когда подсистема мертва). Разные failure modes.

**Priority:** 🔴 High — без этого фикса escalation-механизм + защитные хуки могут быть молча мертвы у консьюмера.

**Actions (для консьюмеров — особенно если хуки не срабатывали):**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```
После sync: `hook-liveness.sh` появится в `.claude/hooks/`, settings.json получит SessionStart wiring. Перезапусти сессию Claude Code. Если видишь `⚠️ HOOK DRIFT` при старте — значит хуки были мертвы, sync их восстановил.

**Проверка:** `grep -c hook-liveness .claude/settings.json` (должно быть ≥1) и `ls .claude/hooks/run-hook.sh .claude/hooks/hook-liveness.sh` (оба должны существовать).

---

## v5.11.0 — feat: auto-gap-capture — gap'ы записываются без подтверждения (2026-06-08)

**Что:** убран friction при захвате gap'ов в `/plan` Шаг -4 и `/diagnose` Шаг 6. Ранее агент спрашивал `(a/p/n)` — gap'ы терялись на практике. Теперь auto-write + opt-out.

Изменения:
- **`/plan` Шаг -4:** при обнаружении коррекции — дедуп-grep → auto-write → одна строка: `📝 Записано: G-NNN — ... Отменить: 'нет'`
- **`/diagnose` Шаг 6.3-6.4:** reinforced "без подтверждения", добавлен opt-out в Шаге 6.4
- **`AGENT-GAPS.md.template` правило захвата:** обновлено — "записывает автоматически"
- **`CLAUDE.template.md` Agent self-reporting rule:** переписан — auto-write flow с примерами

**Priority:** 🟡 Medium — поведенческое изменение, backward compatible.

**Actions (для консьюмеров на v5.10.x и ниже):**
```bash
bash <methodology-path>/scripts/sync-methodology.sh
```
После sync: `/plan` Шаг -4 и `/diagnose` Шаг 6 автоматически пишут gap без вопроса.

**Примечание:** если в вашем `AGENT-GAPS.md` нет секции `## Записи` с маркером `<!-- новые — сверху -->` — агент не сможет вставить запись (упадёт gracefully). Проверить: `grep "новые" AGENT-GAPS.md`.

---

## v5.10.1 — fix: consumer-pull.sh REPO_ROOT path (2026-06-08)

**Что:** исправлен баг в `templates/scripts/consumer-pull.sh` — `REPO_ROOT` вычислялся некорректно при запуске из `scripts/`. Теперь `cd "$SELF_DIR/.." && pwd` — детерминировано независимо от CWD.

**Actions:**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```
Скрипт перезапишется автоматически.

---

## v5.10.0 — feat: /pull workspace-wide — все repos кроме it-dev-methodology (2026-06-08)

**Что:** `/pull` расширен до workspace-wide режима — тянет все repos из `.code-workspace` кроме `it-dev-methodology`.

Изменения:
- `commands/pull.md` — уточнён scope (все workspace repos кроме methodology source)
- `templates/scripts/consumer-pull.sh` — discovery через `.code-workspace` (тот же механизм что `/pull-consumers`)

**Actions:**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```

---

## v5.9.0 — feat: /pull — consumer pull всех workspace repos (ff-only) (2026-06-08)

**Что:** новая consumer команда `/pull` — одной командой подтянуть все repos workspace с remote, без merge, ff-only, с preview входящих коммитов.

Изменения:
- **`commands/pull.md`** — новая команда (синхронизируется консьюмерам)
- **`templates/scripts/consumer-pull.sh`** — новый скрипт: fetch → preview incoming commits → `git pull --ff-only`. Skip при uncommitted changes или diverged history. Hook-safety guard.
- **`templates/model-tiers.md`** — строка `/pull` (Fast tier)

**Actions:**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```
После sync: `bash scripts/consumer-pull.sh` доступен. Команда `/pull` появится в `.claude/commands/`.

---

## v5.8.0 — fix: SYSTEM-MAP шаблон — продуктовые компоненты первичны (2026-06-08)

**Что:** исправлен концептуальный дефект в `templates/SYSTEM-MAP.template.md` (P-004). Шаблон содержал только безликие `<service-1>` / `<service-2>` без примеров — консьюмер не понимал что в диаграмму должны идти компоненты его продукта (`OrderService`, `PartyService`, `CatalogService`), а не dev-инструменты.

Изменения:
- **Callout в начале:** «Это архитектура ТВОЕГО ПРОДУКТА» с примерами по 5 типам проектов (ERP, маркетплейс, бот, API-сервис, инструмент)
- **Bootstrap checklist:** 2 обязательных чекбокса (product components заполнены + у каждого есть назначение)
- **CLAUDE.md Maps Standard Rule:** уточнено что SYSTEM-MAP описывает продуктовые сервисы как первичный слой
- **methodology-platform SYSTEM-MAP:** добавлена note о special case (продукт = методология = слои репо)
- **PRODUCT-GAPS:** закрыт P-004 (resolved in v5.8.0)

**Migration note для консьюмеров bootstrap'нутых до v5.8.0:**

Если `docs/architecture/SYSTEM-MAP.md` в вашем проекте содержит только `<service-1>` / `<service-2>` без замены — карта не заполнена. Для исправления:

1. Открой `PRODUCT.md` → выпиши ключевые сервисы/модули продукта
2. Замени `<service-1>` / `<service-2>` на реальные компоненты (`OrderService`, `PartyService` и т.д.)
3. Заполни Bootstrap checklist в начале файла

**Что запустить:**
```bash
# Ничего — bootstrap-only артефакт, sync-methodology.sh его не трогает
# Изменения нужно внести вручную в docs/architecture/SYSTEM-MAP.md
```

---

## v5.7.0 — fix: ARTIFACT-MAP шаблон — продуктовые артефакты первичны (2026-06-08)

**Что:** исправлен концептуальный дефект в `templates/ARTIFACT-MAP.template.md`. Шаблон раньше направлял консьюмера описывать dev-артефакты (команды `/plan`, `/code`, DEVLOG) как центральный контент карты — вместо документов продукта (`orders.md`, `parties.md`, `invoice-flow.md`).

Изменения:
- **Два явных слоя:** "Продуктовые артефакты (заполнить!)" — новый subgraph первичен в диаграмме; "Методологические артефакты (стандартные)" — вторичный слой, не нужно изобретать
- **Callout в начале:** явное предупреждение "карта описывает артефакты ПРОДУКТА, не процесса разработки"
- **Bootstrap checklist:** 2 обязательных чекбокса при первом заполнении (product artifacts заполнены + у каждого есть триггер)
- **Секция "Продуктовые артефакты"** поднята выше "Методологических" — консьюмер видит что заполнять в первую очередь
- **CLAUDE.md Maps Standard Rule:** убрано `(methodology-specific)` из описания ARTIFACT-MAP viewpoint; уточнено что продуктовые артефакты первичны
- **methodology-platform ARTIFACT-MAP:** добавлена note о special case (продукт = методология = команды)
- **PRODUCT-GAPS:** закрыт P-003 (resolved in v5.7.0)

**Migration note для консьюмеров bootstrap'нутых до v5.7.0:**

Если `docs/product/ARTIFACT-MAP.md` в вашем проекте содержит только `/plan`, `/code`, DEVLOG и другие dev-артефакты без документов специфичных для вашего продукта — карта не заполнена правильно. Для исправления:

1. Открой `PRODUCT.md` → выпиши ключевые сущности продукта (orders, parties, invoices, contracts и т.д.)
2. Для каждой сущности создай или найди `docs/product/<entity>.md`
3. Добавь эти артефакты в секцию "Продуктовые артефакты" в ARTIFACT-MAP (таблица + ноды в диаграмме)
4. Заполни Bootstrap checklist в начале файла

**Что запустить:**
```bash
bash scripts/sync-methodology.sh .
```
Шаблон `templates/ARTIFACT-MAP.template.md` обновлён — но уже bootstrap'нутые файлы не перезаписываются автоматически (bootstrap-only артефакт). Исправь вручную по migration note выше.

---

## v5.6.0 — feat: /scope-out — визуальный обзор отложенного / out-of-scope scope (2026-06-06)

**Что:** новая команда `/scope-out` + `scripts/scope-view.sh` — показывают **одной Mermaid-диаграммой** весь отложенный / непокрытый / out-of-scope scope проекта (PRODUCT-GAPS open/in-roadmap + AGENT-GAPS open + ROADMAP Considered/On-hold/Arch-review + triggers.json recommendations[] proposed*). Диаграмма **эфемерна** — генерируется из текстовых источников при каждом запуске, не сохраняется в файл → не дрейфит. Дефолт-фильтр High+in-roadmap (anti node-explosion), `--all` для полного backlog, `--print-only` для offline.

Сопутствующее:
- **Anchor-узел** `📋 Отложенный scope → /scope-out` (класс `affordance`) добавлен в living USER-MAP + ARTIFACT-MAP — навигация туда, куда владелец и так смотрит (карты).
- **Capture write-path:** `/plan` Шаг 99.3 + `/review` теперь пишут product-значимый out-of-scope в PRODUCT-GAPS (иначе `/scope-out` показывает пустую комнату).
- **`/architecture-audit` Шаг 3:** узлы класса `affordance` исключены из phantom-node сравнения (class-rule, не ID-whitelist) — anchor не флагается как ложный drift.
- **CLAUDE.md Maps Standard §3:** конвенция `classDef affordance` (навигационный узел ≠ scope-claim).

**Зачем:** отложенный scope жил только текстом в 5+ файлах; владелец, глядя на карты, его пропускал — «нет визуальности». Closes P-002.

**Что запустить:**
```bash
bash scripts/sync-methodology.sh .
```
После sync доступна команда `/scope-out`. Для two-repo проектов передавай `--root <doc_repo_path>` (команда читает его из CLAUDE.local.md автоматически).

---

## v5.5.1 — fix: FMEA glossary inline — раздел понятен без внешнего контекста (2026-06-06)

**Что:** добавлена врезка-глоссарий прямо в `/plan` Шаг 1.5 блок A. Расшифровка FMEA / S / O / D / RPN на русском; явное предупреждение что D — обратная шкала (высокий = тихий провал). Заголовок таблицы обновлён (RU-суффиксы). Механика не менялась: шкалы 1-10, формула S×O×D, пороги RPN>200 и D≥7 — без изменений.

**Зачем:** до правки раздел был непонятен без знания промышленного стандарта FMEA — агент заполнял формально, владелец методологии не мог его интерпретировать.

**Что запустить:**
```bash
bash scripts/sync-methodology.sh .
```

---

## (unreleased — version aligned at merge) — feat: sync self-apply hook-wiring + watchdog liveness — mechanism #3 (2026-06-06)

**Что (закрывает «watchdog не запускался → sync/sync-audit спят»):**
- **`sync-methodology.sh` self-apply ветка** теперь вызывает `merge_settings_json` — методология dog-food'ит own hook-wiring (раньше merge был только в consumer-ветке → own settings без SessionStart → auto-update-watchdog мёртв).
- **`/plan` Шаг -3 liveness check** — детектит отсутствие SessionStart/auto-update-watchdog wiring → 🔵 предложить sync. Гарантированно-читаемое место (slash-команда), не рекурсивно-уязвимый рантайм-хук.
- **Bug fix:** `sys.stdout.reconfigure(utf-8)` в merge_settings_json + merge_triggers_json — Windows cp1252 крашил print на `↻`/`—`, маскируя успешный merge как «failed».

**Что запустить:**
```bash
bash scripts/sync-methodology.sh .
```
Консьюмеры: liveness-check в /plan подскажет если SessionStart не wired. NB: первый merge переформатирует settings.json (inline→multi-line, функционально-нейтрально, единожды).

> ⚠️ VERSION выравнивается при финальном мерже (параллельно с v5.5.0).

---

## (unreleased — version aligned at merge) — feat: sync settings.json hooks merge — consumer wiring drift (2026-06-06)

**Что (закрывает mechanism #2 silent-fail: новое hook-wiring не доезжало до существующих консьюмеров):**
- **`sync-methodology.sh` — `merge_settings_json()`** заменяет add-only-if-missing для `settings.json`. При sync дозаливает отсутствующие `run-hook.sh X.py` из `settings.template.json` в существующий consumer `settings.json`. permissions и существующие matcher-группы не трогаются. Идемпотентно (presence-check), graceful (невалидный JSON / нет Python → preserve).
- Дополняет hook-wiring parity gate (/review, v5.3.0): parity ловит на dev-стороне, merge доставляет к консьюмеру. Теперь settings.json = MERGE как triggers.json.

**Что запустить:**
```bash
bash scripts/sync-methodology.sh .
```
Существующие консьюмеры впервые получат недостающее hook-wiring (напр. iteration-watchdog, secrets-guard если их settings отстал). Намеренно удалённые хуки вернутся — methodology-хуки обязательны.

> ⚠️ VERSION bump выравнивается при финальном мерже (изменение делалось параллельно с v5.5.0).

---

## v5.5.0 — feat: commit-discipline + verify-gate — unplanned parallelism at isolation:off (2026-06-06)

**Что (закрывает index-capture класс: 2 сессии при `worktree_isolation: off` → `git commit` захватывает чужой staged-индекс; инцидент a17ecc1):**
- **`/code` Шаг 2 — commit-discipline:** коммить через explicit pathspec (`git commit <пути> -m`), НЕ `git add`+bare `git commit` (последний коммитит весь индекс, включая staged другой сессией). + **verify-before-commit gate:** `git diff --cached --name-only` → staged ⊆ `/plan` Шаг 1 file-scope. Few-shot антипример a17ecc1.
- **`CLAUDE.md` Workflow rules** — короткое правило commit-discipline (discoverability).
- **ADR-002** — субсекция «Index-capture at isolation:off»: документирует что `off` шарит один индекс, регулятор там = commit-discipline (не worktrees), rejected детектор, deferred L4 hook с измеримым trigger.

**Чем дополняет v4.59.0:** v4.59.0 закрывал ЗАПЛАНИРОВАННЫЙ параллелизм (`auto`+AGENTS.md+worktree). Это — НЕЗапланированный (`off` default + фактически 2 сессии). При `auto` баг невозможен (отдельный индекс per worktree); при `off` pathspec — единственная защита.

**Что запустить:**
```bash
bash scripts/sync-methodology.sh .   # получить обновлённый /code + CLAUDE.md
```

**Что отложено:** L4 PreToolUse commit-scope hook (warn если staged вне scope) — trigger: следующий index-capture инцидент ИЛИ /retro ≥1 [git-failure] scope-capture.

**Приоритет:** 🟡 Medium — поведенческое правило коммита (не breaking), но предотвращает потерю чужой работы. Действие: один `sync-methodology.sh`.

---

## v5.3.0 — feat: /review hook-wiring parity gate — dev-side «hook доехал, но не активировался» (2026-06-06)

**Что (закрывает класс тихого провала: fix есть в методологии, но hook мёртв у консьюмера):**
- **`/review` Шаг 3 (methodology-platform)** — новый hard-check **Hook-wiring parity**: PR трогает `templates/.claude/hooks/` → каждый entry-point hook ОБЯЗАН быть wired через `run-hook.sh <name>.py` в `templates/settings.template.json`, иначе 🔴 блок merge. Прямое направление (file→no wiring); комплементарно runtime `check_hook_health` (settings→missing file).
- Helper-исключение через маркер `# NOT-WIRED:`; detection-guard на 0 совпадений (closes G-073-класс).

**Что запустить (получить обновлённый /review):**
```bash
bash scripts/sync-methodology.sh .
```
Поведение для консьюмеров не меняется автоматически — gate применяется при разработке самой методологии. Консьюмеры получают обновлённый текст команды `/review`.

---

## v5.1.0 — feat: testing layer Phase 1 — /test + testing-strategy skill + CODE-GAPS (2026-06-05)

**Что (методология начинает ВЕСТИ тестирование разрабатываемых приложений — обнаружение FE/BE багов: технических, логических, визуальных):**
- **`skills/testing-strategy/SKILL.md`** (новый knowledge-domain) — tiered pyramid (L0 verify / L1 focused / L2 regression «тяжёлая артиллерия»), инструменты per стек (Playwright/Cypress + visual diff, Schemathesis/Pact contract+API, property-based для логики), как ловить логические+визуальные баги не только краши.
- **`/test`** (новая команда) — оркестратор-навигатор (по запросу, как `/marketing`): выбирает уровень по project_type, генерирует+запускает тесты **в консьюмер-проекте**, найденное → CODE-GAPS.md. **Advisory** — вердикт о корректности кода за разработчиком (Граница 12: методология ведёт тестирование, не исполняет движок и не судит код).
- **`templates/CODE-GAPS.md.template`** (новый consumer-owned артефакт) — регистр product-багов со статусом open/fixed/regression-guard; категории открытым списком (frontend-visual/logic, backend-contract/crash, regression, perf). Не агрегируется методологией (G-032).
- **DEVLOG-тег `[test-found:category]`** — указатель на CODE-GAPS; fix-событие остаётся `[fix:X]` (QB3).
- Bootstrap создаёт `CODE-GAPS.md`; sync добавляет если отсутствует; `/pull-consumers` читает read-only для cross-domain pattern detection.

**Что запустить:**
```bash
# Получить новый skill + команду /test + CODE-GAPS.md:
bash scripts/sync-methodology.sh .
```

**Что отложено (Phase 2-4, named re-trigger):** блокирующий L2 regression gate в `/deploy`, test-watchdog hook, `--with-testing` bootstrap флаг, VISION QB11 + Граница 12 (фиксация через `/product-vision`). Разблокировать при: консьюмер пропустил regression-баг в prod который L1 поймал бы, ИЛИ ≥2 AGENT-GAPS completeness-gap по test-coverage.

**Приоритет:** 🟢 Low — additive (новый skill/команда/template), не breaking. Действие: один `sync-methodology.sh`.

---

## v5.0.0 — BREAKING: plan→code→review traceability — commitments[] в triggers.json schema (2026-06-05)

**Что (закрывает class «/plan обещал → /code забыл → /review не поймал», симптом: mermaid-ссылки в map-артефактах создаются/обновляются непоследовательно):**
- **Schema change (BREAKING):** `templates/triggers.json.template` → `last_plan_session` получил поле `commitments: []`. Каждая запись: `{text, status, skip_reason, carried_over?}`. Durable контракт обязательств задачи.
- **`/plan` Шаг 100** — финализирует список «📋 В /code будет реализовано» (Шаг 99.3) в `commitments[]` (status:pending). Под-шаг 0.5: carry-over `status:done` записей при re-plan (не теряем сделанное).
- **`/code` Шаг 7** — отмечает каждый commitment `done` / `skipped`+`skip_reason` по факту реализации. `pending` без причины при завершённой работе запрещён.
- **`/review` Шаг 3 Completeness** — новый класс: читает `commitments` (`.get('commitments') or []` — graceful на отсутствие), сверяет каждый против diff. `pending` без причины ИЛИ `done` без следа в diff → 🔴 fix now (блок merge, disposition за пользователем).

**Почему MAJOR:** изменение схемы `triggers.json` — мажор bump по инварианту CLAUDE.md (структурное правило, не зависит от back-compat механики). **Фактически back-compat:** `deep_merge` в `sync-methodology.sh` авто-добавляет `commitments: []` в существующий `last_plan_session`, сохраняя текущие значения. Старые планы без поля → `/review` graceful skip (🔵, не 🔴).

**Что запустить:**
```bash
# Подтянуть новую схему triggers.json (deep_merge добавит commitments[], значения сохранятся):
bash scripts/sync-methodology.sh .
```
Ручных правок triggers.json не требуется — merge идемпотентен. До запуска sync `/review` работает в graceful-режиме (commitments не сверяются, 🔵 уведомление).

**Приоритет:** 🟡 Medium — schema-breaking по правилу, но фактически back-compat через merge. Действие: один `sync-methodology.sh`.

---

## v4.60.0 — feat: S-026/S-027/S-028 structural gap fixes — template-format validator + few-shot examples + mandatory adjacent output (2026-06-03)

**Что:**
- **`scripts/validate-template-format.sh`** (новый, consumer-distributed) — L4 автопроверка формата templates/*.template.md: required sections, no stale mermaid link format, no unresolved placeholders. Запускается в `/code` Шаг 4 п.11 после любого изменения команд/templates. Закрывает [fix:template]×4 паттерн + G-068 recurrence.
- **`/code` Шаг 1.7** — mandatory output table: агент обязан написать таблицу grep-результатов до первой строки кода (если grep нашёл ≥1 результат). Закрывает completeness-gap класс «adjacent output необязателен».
- **`/plan` Шаг 99.54** — few-shot URL примеры: правильный (голый URL от скрипта) vs неправильный (markdown-link, subagent-generated). Закрывает logic-gap G-064 recurrence.
- **`/sync-audit` Шаг 3** — few-shot финальная фраза: правильная (версия + счётчик gaps) vs неправильная («полностью применена» без данных). Закрывает G-057.

**Что запустить:**
```bash
# 1. Синхронизировать новый скрипт:
bash scripts/sync-methodology.sh .

# 2. Проверить текущие templates:
bash scripts/validate-template-format.sh
```

**Приоритет:** 🟡 Medium — structural improvements, не breaking changes.

---

## v4.59.0 — feat: concurrent-session isolation — worktree + AGENTS.md (multi-dev / multi-session safety, closes P-001) (2026-06-02)

**Что (industry-стандартная 4-слойная модель безопасной параллельной работы):**
- **Новая ось branching contract — isolation (ортогональна mode):** `worktree_isolation: off|auto` + `branch_namespace: ai-dev/<task>` в `CLAUDE.local.md ## Branching`. НЕ третий mode — все 4 комбинации (solo/team × off/auto) валидны.
- **Новый артефакт `AGENTS.md`** (template + synced, project-owned) — task-ownership доска «one file, one owner» (encapsulation): claim file-scope перед правкой, cleanup после merge. Закрывает file-conflict *до* того как случится.
- **`/code` Шаг 5.5** (новый, при `auto`): читает `AGENTS.md ## Active claims` → пересечение file-scope с активным claim → ⛔ СТОП. Branch check теперь принимает namespaced `{agent_branch}/<task>`.
- **`/deploy`:** worktree-aware push (деплоит **текущую** ветку, не хардкод `agent_branch`) + **VERSION/shared-state race guard** (`git fetch && git diff origin/{branch}` перед bump — closes G-052) + claim cleanup после merge.
- **`scripts/deploy-push.sh` (+ template copy):** читает `worktree_isolation` → при `auto` пушит current branch (`$PUSH_BRANCH`), не хардкод `agent_branch`.
- **ADR-002 v2:** снят «multi-agent deferred», добавлена секция Concurrent-Session Isolation (4 слоя: isolation/ownership/staging/merge-gate) + temporal precondition (claim ДО edit).
- **Back-compat:** `worktree_isolation: off` = default → существующие consumers без изменений. `auto` = opt-in после локальной проверки `git worktree add` (Git Bash/Windows: git ≥ 2.5).

**Actions для consumers:**
```bash
bash /path/to/it-dev-methodology/scripts/sync-methodology.sh .   # добавит AGENTS.md, обновит code/deploy/deploy-push, CLAUDE.local fields
# Для concurrent work: в CLAUDE.local.md ## Branching → worktree_isolation: auto (после git worktree add self-check)
```

**Priority:** 🟡 Medium — нужно только проектам с >1 разработчиком или несколькими параллельными сессиями. Solo-single-session не затронут (default off).

---

## v4.58.0 — feat: migration registry — /sync-audit как единая точка обновления consumer'ов (2026-06-01)

**Что (структурное решение, Flyway/Alembic pattern):**
- **`scripts/migrations/`** — версионированные format-миграции. Каждое изменение формата заполненного артефакта = файл `v<X.Y.Z>-<id>.sh` с контрактом: `migration_detect` (нужна ли) + `migration_apply` (idempotent transform) + `MIGRATION_MODE` (auto self-heal / report).
- **`scripts/migrations/_runner.sh`** — прогоняет миграции новее consumer-версии. Source of truth = `.claude/state/migrations-applied.txt` (per-consumer, gitignored) → решает erp-класс «synced to latest, но старый transform не прогонялся».
- **`/sync-audit` Шаг 1.5** — вызывает runner автоматически. `HEALED` (авто) / `REPORT` (нужно решение). **Consumer запускает ТОЛЬКО `/sync-audit`** — миграции форматов применяются сами (user-friendly).
- **Первая миграция `v4.37.0-mermaid-bare-url`** — чинит старый `> 🔗 [Открыть](url)` → голый URL (closes G-072: stale-консьюмер больше не застревает; триплклик выделяет только ссылку).
- **Расширяемость:** новое format-улучшение = новый migration-файл, команда `/sync-audit` НЕ меняется.
- **Bonus fix:** `update-mermaid-links.sh` cross-drive bug (`os.path.relpath` ValueError при `--root` на другом диске) → `_safe_relpath` fallback.

**Actions для consumers (одна команда):**
```bash
/sync-audit          # синкнет migrations + применит все нужные format-миграции автоматически
```

**Priority:** 🟡 Medium — структурная основа для авто-обновления consumer-артефактов при эволюции методологии.

---

## v4.57.0 — security: close confirmed git-https token-leak vector (S0-S3) (2026-06-01)

**Что (security-аудит → 4 структурных фикса; подтверждённая утечка из transcript):**
- **S1 (G-077):** `bash_protect.py` новые `SECRET_EXFIL_PATTERNS` — блокирует (a) token-in-URL `https://user:TOKEN@host` (`git remote set-url`/`push`/`clone`), (b) `.env` reads через cat/grep/sed/awk/head/tail/... Закрывает confirmed leak-вектор (агент читал токен → вставлял в git URL → transcript). **11/11 adversarial-тестов**: 5 leak блокируются, 6 легитимных (вкл. `grep ".env" file`, `cat .env.example`, `git push`) разрешены.
- **S2 (G-078):** `.env` deny-правила добавлены в methodology own `.claude/settings.json` (раньше были только в template — dogfood-нарушение, methodology была уязвима).
- **S3 (G-079):** `deploy-push.sh` auto-wire credential helper перед push (idempotent: skip если gh уже настроен / SSH / helper отсутствует). Агент делает plain `git push` — токен via helper stdin, НЕ argv.
- **S0 (G-077):** `git-credential-from-env.sh` routing по host (service_url + service-field token match), НЕ по имени ключа. User-defined имена (напр. `GITHUB_AI_ASSISTANT_DOCUMENTATION_FULL`) работают без переименования в `GITHUB_PAT`. Actionable stderr hint вместо молчаливого падения.

**Actions для consumers:**
```bash
bash scripts/sync-methodology.sh .   # получить bash_protect.py + git-credential-from-env.sh + deploy-push.sh
# .env deny-правила в settings.json применяются при init; existing consumers — sync обновит hook (L4),
# для L5 denies проверь .claude/settings.json permissions.deny содержит .env правила.
```

**Принцип (industry):** агент структурно НЕ может назвать значение секрета в команде — auth через side-channel (helper stdin / ssh-agent) который агент не читает. Detection — последняя линия, не первая.

**Priority:** 🔴 High — закрывает подтверждённую (не теоретическую) утечку токенов в transcript.

---

## v4.56.0 — fix: Maps Standard — C4→arc42 claim correction + 6-views рамка + ADR-catalog (2026-06-01)

**Что (PR G из методологического аудита — точность модели карт):**
- **C4 claim исправлен:** CLAUDE.md + 2 templates заявляли «основан на C4 Model» — неверно. Три карты это **arc42 viewpoints** (ортогональные плоскости), не C4 zoom levels (один axis granularity). C4 оставлен только для дисциплины диаграмм. Источник: methodology-audit (4+1/arc42 mapping).
- **«3 карты» → «6 views» рамка:** living maps (SYSTEM/USER/ARTIFACT) + supporting views (data-map / ADR catalog / threat-model) явно названы в CLAUDE.md Maps Standard.
- **Слепое пятно задокументировано:** Temporal/Sequence viewpoint (порядок команд + хуков) — отсутствует, ordering-баги невидимы. Кандидат на 7-й view, активируется при первом ordering-инциденте (anti-over-engineering).
- **ADR-catalog drift исправлен** (doc-repo): каталог содержал 1 из 3 ADR. Добавлены ADR-002 (branching) + ADR-003 (secrets).

**Actions:** нет (документация/claim). `bash scripts/sync-methodology.sh .` для обновлённого CLAUDE template.

**Priority:** 🟢 Low — точность стандарта (consumer думал что следует C4, а это arc42).

---

## v4.55.0 — feat: validate-links.sh — Docs-as-Code internal link-check (2026-06-01)

**Что добавилось (PR B из методологического аудита):**
- `scripts/validate-links.sh` (+ `templates/scripts/`) — проверяет что все markdown-ссылки `[...](path)` на локальные файлы резолвятся. `BROKEN_LINK` = битая навигация. Пропускает: external URL, anchors, glob/placeholder, `.claude/` (derived copies), template-файлы, cross-repo sibling (если отсутствует).
- Gate в `/review` (BROKEN_LINK = 🔴 CRITICAL) + `/sync-audit` Gap 8.
- **Эмпирически нашёл 8 реальных битых ссылок** в README.md/PRODUCT.md (class G-076: code-repo ссылался на VISION/ROADMAP/DEVLOG/maps локально, а они в doc-repo) — исправлены на `../it-dev-methodology-documentation/...`.

**Actions:**
```bash
bash scripts/sync-methodology.sh .       # получить validate-links.sh
bash scripts/validate-links.sh           # проверить свои артефакты
```

**Priority:** 🟡 Medium — Docs-as-Code gate, ловит навигационные дыры.

---

## v4.54.0 — fix: universality — de-hardcode two-repo paths + hook-consistency check (2026-06-01)

**Что добавилось (эмпирический consumer-аудит → 2 реальных фикса):**
- **PR A (G-076):** убраны hardcoded `../it-dev-methodology-documentation` из `/code`, `/review`, `/retro`. Новое поле `doc_repo_path` в `CLAUDE.local.md ## Auto-update`: `null` = single-repo (артефакты локальны), путь = two-repo. Команды читают config вместо hardcode. Закрывает leak который видели single-repo consumers (erp: 47 methodology-ссылок, путь к несуществующему sibling-репо).
- **PR H (G-075):** `sync-methodology.sh` после синка hooks проверяет что каждый hook упомянутый в `settings.json` реально присутствует в `.claude/hooks/`. Отсутствует → `⚠️ HOOK-MISMATCH` (fail loud). Закрывает silent-fail найденный в ai-assistant (auto-update-watchdog.py в settings.json но файла нет → hook падал молча → consumer навсегда stale без предупреждения).

**Actions для consumers:**
```bash
bash scripts/sync-methodology.sh .   # получить обновлённые команды + hook-check
# Затем в CLAUDE.local.md ## Auto-update установить doc_repo_path:
#   single-repo проект → doc_repo_path: null  (default, ничего не менять)
#   two-repo проект → doc_repo_path: ../<your-doc-repo>
```

**Priority:** 🔴 High — закрывает реальные consumer-leaks (эмпирически подтверждены на erp + ai-assistant).

---

## v4.53.0 — feat: discipline-creating финализация — /architecture-audit + /diagnose + /sync-audit + /product-check (2026-06-01)

**Что добавилось (PR3 of 3 — завершение трансформации всех 9 команд):**
- `/architecture-audit` 6.3 — recurrence_rate = open/(open+addressed) формула (FMEA Detection logic): ≥0.4 → Level 4+ обязателен.
- `/diagnose` Шаг 2 — таблица гипотез с исполнимой командой + различающим output (Popper falsifiability). «Посмотреть код» = не зачтено.
- `/sync-audit` Gap 1 — PRODUCT coverage через `grep -c` + `find | wc -l` (два числа), не «< 50% на глаз». methodology-platform → N/A.
- `/product-check` п.1-2-6 — команды (`ls`, `git log -1 --format=%ad`) вместо чтения на глаз; дата сверяется с git-историей.

**Actions:** нет (behavior change в commands/).

**Priority:** 🟡 Medium — завершает discipline-creating трансформацию (3-PR серия v4.51-v4.53).

---

## v4.52.0 — feat: discipline-creating classification в /code + /retro (2026-06-01)

**Что добавилось (PR2 of 3 — продолжение FMEA/Gawande трансформации):**
- `/code` Шаг 0.5 (Local/Systemic) — классификация **по числу** через `grep -c` + `git log -S`, не по интуиции. ≥2 места → системный → архитектурный фикс. «Локальный» без показанного grep = не зачтено.
- `/retro` Шаг 2 (Pattern detection) — обязательный `grep -oE "\[fix:...\]" | uniq -c | sort -rn` frequency-замер ДО интерпретации. Таблица из чисел grep, не «на глаз». Ловит semantic-дубли (один баг под разными тегами).

**Actions:** нет (behavior change в commands/).

**Priority:** 🟡 Medium — усиливает точность классификации, не breaking.

---

## v4.51.0 — feat: Forward-Failure Analysis (FMEA+JTBD) + discipline-creating Completeness audit (2026-06-01)

**Что добавилось (industry best practices применены к методологии):**
- `/plan` Шаг 1.5 — **Forward-Failure Analysis**: (A) FMEA RPN-таблица (Severity × Occurrence × Detection, RPN>200 → mitigation, D≥7 → detection-шаг); (B) JTBD struggling-moment (где пользователь скажет «проще руками»); (C) integration/non-duplication check (closes G-074).
- `/plan` Шаг 98 Pre-Mortem — категории усилены до discipline-creating: каждая требует **конкретного механизма** (тип данных, операция, сервис), не абстрактной категории. Klein-грамматика «уже провалилось, почему».
- `/review` Completeness check — заменён aspirational вопрос на **7 структурных классов пропусков** с evidence requirement (CRUD-симметрия, downstream consumers, content-vs-existence, template-sync, trigger-chain, error-path, +open) (closes G-073).
- `/review` Тесты — discipline-creating (назвать конкретный способ верификации + smoke-test для methodology).

**Actions:** нет (behavior change в commands/, не новые файлы).

**Priority:** 🟡 Medium — усиливает качество планирования и аудита, не breaking.

**Trade-off:** plan.md вырос ~+3700 chars (1.1x→1.2x budget). Оправдано новым классом (прямой запрос + G-073/G-074). Кандидат на структурное сжатие plan.md в отдельном /plan.

---

## v4.49.0 — fix: /code Шаг 4 пункт 11 hard rule + Шаг 7 triggers.json + /review template-drift check (2026-06-01)

**Что добавилось:**
- `/code` Шаг 4 пункт 11 усилен до ⛔ hard rule: «нет понятия "незначительный" для format changes» — блок при несоответствии templates/*.template.md (closes G-068).
- `/code` новый Шаг 7 (обязательный финальный): обновление triggers.json после каждого deploy — code_run=true + last_deploy (closes G-063).
- `/review` новый check «Template-drift»: если PR менял формат артефакта — проверить templates/*.template.md, несоответствие = 🔴 CRITICAL.

**Actions:** нет (behavior change в commands/, не новые файлы).

**Priority:** 🟡 Medium — структурная hygiene, не breaking change.

---

## v4.47.7 — feat: post-edit-watchdog PostToolUse hook (2026-06-01)

**Что добавилось:**
- `post-edit-watchdog.py` — новый PostToolUse hook: после каждого Edit/Write проверяет изменённый текст на паттерны из конфига и автоматически запускает скрипт. L4 фикс для G-020 (mermaid ссылки не обновлялись при прямом Edit вне /code workflow).
- Дефолтное правило: ` ```mermaid ` в изменённом тексте → `bash scripts/update-mermaid-links.sh <file>`.
- Конфигурируется через `CLAUDE.local.md ## Post-edit hooks` (YAML rules) — новые автоматизации без правки кода.
- Path validation против traversal атак.

**Actions:**
```bash
bash scripts/sync-methodology.sh .   # получить hook + обновлённые settings.json + CLAUDE_LOCAL.template.md
# Добавить в CLAUDE.local.md секцию ## Post-edit hooks (или использовать дефолтное правило mermaid)
```

**Priority:** 🟡 Medium — рекомендуется для проектов с Mermaid-диаграммами.

---

## v4.46.0 — feat: /marketing команда-навигатор + слоевая модель (2026-06-01)

**Что добавилось:**
- `/marketing` — slash-команда навигатор: читает MARKETING.md, показывает прогресс Foundation + Execution skills, рекомендует следующий skill в правильном порядке.
- Слоевая модель задокументирована: PRODUCT/VISION = внутренний слой, MARKETING = внешний. Marketing skills читают PRODUCT/VISION как вход, пишут только в MARKETING.md.
- Порядок Foundation block зафиксирован: `product-marketing` (breadth V1) → `define-positioning` → `customer-research` → `competitor-profiling`.
- Исправлен overlap: `define-positioning` больше не claims "первый" — теперь "второй (после product-marketing)". `product-marketing` уточнён как breadth-старт только на новом MARKETING.md.
- `MARKETING.md` ресинхронизирован с template (добавлена секция `## Product Context`).
- `model-tiers.md` расширен строкой `/marketing` (Fast tier, upgrade to Default при первом запуске).

**Actions:**
```bash
bash scripts/sync-methodology.sh .   # получить /marketing команду + обновлённые skills
```

**Priority:** 🟢 Optional (новая UX-возможность, не breaking)

---

## v4.45.0 — feat: 8 новых marketing skills (2026-06-01)

**Что добавилось:** 8 новых skills в слой `skills/` вдохновлённых репозиторием coreyhaines31/marketingskills:
- `product-marketing` — foundation skill: маркетинговый контекст продукта (читается всеми остальными)
- `copywriting` — маркетинговые тексты для страниц
- `content-strategy` — контент-стратегия и планирование
- `pricing` — стратегия ценообразования и монетизации
- `launch` — запуск продукта и фич (фреймворк ORB + 5 фаз)
- `emails` — email-последовательности и lifecycle emails
- `cro` — оптимизация конверсии
- `seo-audit` — SEO аудит и диагностика

Все скиллы адаптированы под нашу систему: читают `MARKETING.md` вместо `.agents/product-marketing.md`, документация на русском, artефакт — `MARKETING.md`. `MARKETING.template.md` расширен секцией `## Product Context`.

**Actions:**
```bash
bash scripts/sync-methodology.sh .   # получить новые skills
```

**Доступность:** Все проекты с `--with-marketing` или после `sync-methodology.sh` автоматически получают новые скиллы. `product-marketing` — новый foundation skill (запускать первым).

**Priority:** 🟢 Optional (новые capabilities, не breaking)

---

## v4.44.6 — G-062: закрыты два leak-вектора через bash_protect.py (2026-06-01)

**Что добавилось:** два новых блокирующих паттерна в `bash_protect.py`:
1. `_get-secret-raw.sh` — полностью заблокирован для агентов (был escape-hatch с `--explicit-stdout`, теперь блокируется любой вызов). Агент не может вывести секрет в stdout.
2. Inline env assignment вида `SECRET_KEY="value" bash script.sh` — заблокирован для ключей с секрет-индикаторами (TOKEN, SECRET, PASS, KEY, CRED, PAT, AUTH, ADMIN, PRIVATE, CERT, BEARER). Легитимные `ENV=dev bash cmd.sh` разрешены.

**Triggered by:** инцидент — агент увидел `KeycloakAdmin2024!` через stdout (Vector 2: inline assignment не был заблокирован).

**Security confidence:** 99.9%+ для agent-mediated leak vectors (stdout/transcript path). OS-level vectors (proc/environ, core dumps) documented в CLAUDE.md § Scope limits остаются open per design.

**Actions:**
```bash
bash scripts/sync-methodology.sh .    # получить обновлённые hooks
```

Если у вас уже были секреты которые агент потенциально видел — rotate их немедленно.

**Priority:** 🔴 CRITICAL (security patch, immediate sync recommended)

---

## v4.44.1 — auto_pull: полностью автоматический flow (2026-05-29)

**Что добавилось:** явное объяснение почему `auto_pull: true` нужен для полного авто-flow. Watchdog обновляет `.claude/` но НЕ `it-dev-methodology/` source — без `auto_pull: true` при автозапуске `/sync-audit` source может быть stale.

**Actions:**
```yaml
# Добавь в CLAUDE.local.md ## Auto-update:
auto_pull: true   # для полностью автоматического flow
```

**Priority:** 🟡 Recommended если используешь watchdog auto-trigger (раз в 2 часа).

---

## v4.44.0 — /sync-audit делает pull перед анализом (2026-05-29)

**Что добавилось:** `/sync-audit` теперь начинает с Шага -0.5 — проверяет есть ли обновления в локальной `it-dev-methodology/` и предлагает pull перед delta analysis. Без этого delta analysis мог сравнивать с устаревшей локальной версией и говорить "всё актуально" хотя на remote уже v4.43.x. Добавлено поле `auto_pull: true/false` в `CLAUDE.local.md ## Auto-update`.

**Actions:**
```bash
bash scripts/sync-methodology.sh .          # получить обновлённую команду /sync-audit
```

После этого при запуске `/sync-audit` он сам предложит обновить `it-dev-methodology/`. Для автоматического pull без вопросов добавь в `CLAUDE.local.md ## Auto-update`:
```yaml
auto_pull: true
```

**Priority:** 🟡 Recommended — делает `/sync-audit` честным (не сравнивает со stale локальной копией).

> **Читается `/sync-audit` автоматически** для delta analysis.
> Записи в формате: версия → title → actions (ordered).
> При добавлении нового feature → добавить запись сюда (см. /code Шаг 5 checklist).

---

## v4.42.6 — Mermaid scripts для consumers (2026-05-29)

**Что добавилось:** `update-mermaid-links.sh`, `mermaid-link.py`, `validate-mermaid-links.sh`, `validate-doc-freshness.sh` теперь попадают к consumers через sync.

**Actions:**
```bash
bash scripts/sync-methodology.sh .          # получить скрипты
bash scripts/update-mermaid-links.sh        # обновить ссылки в bare URL формат
bash scripts/validate-mermaid-links.sh      # проверить что все ссылки актуальны
```

---

## v4.41.0 — Secrets schema v2 + multi-host routing (2026-05-29)

**Что добавилось:** manifest schema v2 (service_name, service_url, login, expires_at). `set-secret.sh` интерактивный. `secrets-show.sh`, `secrets-update.sh`, `secrets-edit.sh`, `secrets-rollback.sh`. Multi-host git credential routing.

**Actions:**
```bash
bash scripts/sync-methodology.sh .          # получить новые скрипты
bash scripts/set-secret.sh KEY              # интерактивно обновить metadata секретов
bash scripts/validate-secrets.sh           # проверить состояние + hygiene warnings
```

**Priority:** 🟡 Recommended — добавляет удобство и multi-host support.

---

## v4.34.0 — Secrets management foundation (2026-05-28)

**Что добавилось:** система управления секретами — `.env`, `secrets-manifest.yaml`, `with-secret.sh`, `set-secret.sh`, `check-secret.sh`, `validate-secrets.sh`, `git-credential-from-env.sh`. Pre-commit hook `secrets-guard.py`. Settings.json deny rules для `.env`.

**Actions:**
```bash
bash scripts/sync-methodology.sh .                       # получить все secrets скрипты
cp .env.example .env                                      # создать .env из шаблона
bash scripts/set-secret.sh GITHUB_PAT                    # добавить токен (один раз)
bash scripts/validate-secrets.sh                         # проверить что всё на месте
```

**Priority:** 🔴 Critical — безопасность токенов. Без этого агент может запросить токен через chat.

---

## v4.28.0 — /pull-consumers command (2026-05-27)

**Что добавилось:** команда `/pull-consumers` (LOCAL-ONLY, только для methodology repo) — auto-discovery всех consumer repos + diff новых записей в methodology-tracked артефактах.

**Actions:** только для methodology repo maintainer, не для consumer projects.

**Priority:** 🟢 Optional — только если ты maintainer методологии.

---

## v4.24.0 — PRODUCT-GAPS.md (2026-05-26)

**Что добавилось:** отдельный файл для product gaps (отличие от AGENT-GAPS). Новые шаги в `/plan` Шаг -4 для классификации.

**Actions:**
```bash
bash scripts/sync-methodology.sh .          # обновить команды
# PRODUCT-GAPS.md создаётся автоматически sync если отсутствует
```

**Priority:** 🟡 Recommended — если у тебя есть product roadmap.

---

## v4.20.0 — Sync validators в CLAUDE.local.md (2026-05-24)

**Что добавилось:** секция `## Sync validators` в `CLAUDE.local.md` — config-driven L3 проверки в `/review`.

**Actions:**
```bash
# Добавить секцию вручную в CLAUDE.local.md:
# ## Sync validators
# validators:
#   - name: ...
```

**Priority:** 🟡 Recommended — усиливает /review проверки.

---

## v4.19.0 — PRODUCT.md ## Логика компонентов (2026-05-23)

**Что добавилось:** обязательная секция `## Логика компонентов` в `PRODUCT.md` — tripwire в /plan Шаг -1.3.

**Actions:**
```bash
# Добавить в PRODUCT.md секцию ## Логика компонентов
# с подсекциями для каждого компонента проекта
```

**Priority:** 🟡 Recommended — помогает агенту не менять компонент без понимания контракта.

---

## v4.18.0 — Auto-update hook + Mermaid hybrid language (2026-05-22)

**Что добавилось:** `auto-update-watchdog.py` hook (SessionStart) — автоматически предлагает sync когда methodology обновилась. Mermaid hybrid language rule (EN identifiers + RU descriptions).

**Actions:**
```bash
bash scripts/sync-methodology.sh .          # получить новый hook
# Hook активируется автоматически при следующем SessionStart
```

**Priority:** 🔴 Critical — без hook ты не узнаешь об обновлениях методологии.

---

## v4.16.2 — Agent Skills (SKILL.md frontmatter spec) (2026-05-20)

**Что добавилось:** Agent Skills система — `skills/*/SKILL.md` с YAML frontmatter на строке 1. Auto-activation по keywords.

**Actions:**
```bash
bash scripts/sync-methodology.sh .          # получить skills если есть
# Проверить что .claude/skills/*/SKILL.md имеет frontmatter на строке 1
```

**Priority:** 🟢 Optional — только если используешь marketing skills или создаёшь свои.

---

## v4.10.x и ранее

Базовая методология: `/plan → /code → /review → /deploy` workflow, AGENT-GAPS, DEVLOG, triggers.json, branch check, pre-flight checks. Это foundation — всегда присутствует после `new-project-init.sh`.

---

## Как добавлять новые записи

При добавлении нового feature в методологию — добавить запись **сверху** в формате:

```markdown
## vX.Y.Z — Название feature (дата)

**Что добавилось:** одна строка описания.

**Actions:**
\`\`\`bash
bash scripts/sync-methodology.sh .   # если нужен sync
# дополнительные команды
\`\`\`

**Priority:** 🔴 Critical | 🟡 Recommended | 🟢 Optional
```
