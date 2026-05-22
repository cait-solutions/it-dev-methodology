# CLAUDE.md

Operational rules for AI agents. Short form, scan-friendly. For rationale, edge cases, and historical context — see [CLAUDE_LONG.md](CLAUDE_LONG.md).

> **Convention:**
> - This file (CLAUDE.md) = **WHAT** — methodology rules. Auto-updated by `sync-methodology.sh`. **Do NOT edit.**
> - [CLAUDE_LONG.md](CLAUDE_LONG.md) = **WHY** — rationale, edge cases, examples. Read on demand.
> - [CLAUDE.local.md](CLAUDE.local.md) = project-specific config (stack, architecture invariants, security threats, key files, external links). **Edit freely.**

---

## Read before any work

1. `VISION.md` (or `docs/vision/*_GLOBAL_AGENT_VISION.md`) before every `/plan`.
2. Relevant ADRs / SYSTEM-MAP for the task domain.
3. `docs/data-map.md` (if exists) before storage-touching changes.
4. [CLAUDE.local.md](CLAUDE.local.md) — project stack, architecture invariants, security threats, key entry points.

---

## Workflow rules

**Implementation through /code:** after `/plan` confirmation — implementation **mandatory** via `/code`. Direct edits forbidden for non-trivial changes. Reason: `/code` updates `triggers.json.last_plan_session.code_run` — without this, methodology state drifts.

**Deploy rule:** before every deploy → `/review` if not run in session → DEVLOG entry with `[deploy]` / `[feat:X]` / `[fix:X]` tag → update data map if changed.

**Architecture decision rule:** new modules / data flows / services / integrations → run `architect` sub-agent. Claude gives own recommendation BEFORE invoking architect (independent second opinion, not confirmation).

**Fix rule:**
- Symptom or cause? Symptom → find cause. Cause → class-level fix preferred.
- Local or systemic? Local needs justification why won't repeat. Default to systemic (decorator / middleware / schema constraint).

**Completeness rule:** Each plan / code / review / deploy decision MUST explicitly state:
- What is covered (main path, happy cases)
- What is NOT covered (gaps, edge cases, parallel paths)
- Why gaps are OK or require action
Without this analysis → plan not approved, code not merged, deploy blocked.

**Adjacent Impact rule:** Before planning, enumerate adjacent zones (what reads this component / what depends on it). Explicitly mark each as in-scope or out-of-scope with reason. Classify solution as Point fix / Structural / Level 4+. Without this classification → plan incomplete. See `/plan` Step -1.3 for protocol.

**Don't advise already-done:** check last 3-5 messages before suggesting an action that may already be running.

**AI branch rule:** All AI agent commits go to the branch defined in [CLAUDE.local.md](CLAUDE.local.md) → `## Branching` → `agent_branch` (default: `ai-dev`). Never commit to `main`, `master`, `develop`, `staging`, or `integration_branch` without explicit developer approval.
Before first commit in session: read `agent_branch` from `CLAUDE.local.md`, then `git branch --show-current`. Wrong branch → switch BEFORE any changes, not after.

**Retroactivity rule:** Methodology updates apply to NEW plans only. Existing plans are revised only if: (a) not yet in `/code` stage, or (b) a critical blocking error found that new rules would catch. Don't revise completed plans for every update — it's an infinite loop.

**Risk scope rule:** Systemic risks (affect multiple tasks, live months/years) → `RISKS.md` only. Task-specific risks → stay in the plan. Don't copy task risks to `RISKS.md` — it pollutes the systemic registry with single-use noise.

**Onboard update rule:** When adding a new slash command, agent, or rules file → update `/onboard` in the same commit/PR. Onboarding that doesn't reflect the current toolset misleads contributors.

For rationale and historical examples — [CLAUDE_LONG.md § Workflow rules](CLAUDE_LONG.md#реализация-через-code-расширенно).

---

## Regulator levels (Level-4 framework)

Strong → weak:
1. Schema / type constraint — guarantee
2. No alternative path — very strong
3. Input data structure — strong
4. Few-shot examples — medium, drifts
5. Tool description — weak
6. Prompt rule — ignored

**Rule:** when adding behavior — start from level 4-6, not 1-3. Prompt-only rule as first solution = 🟡 WARNING in `/review`. Before accepting any methodology rule — ask "is there a level-4+ structural fix?". If yes — that's primary, rule secondary.

Details: [CLAUDE_LONG.md § Level-4 framework](CLAUDE_LONG.md#сила-регуляторов-поведения-level-4-framework--расширенно).

---

## Model tier rule

Every methodology command MUST have `## Рекомендуемая модель` section (5 fields). Canonical registry: [.claude/model-tiers.md](.claude/model-tiers.md).

When adding new command → also add row to per-command matrix in `model-tiers.md`. Without both, `/review` blocks merge.

When Anthropic renames models → update only the Mapping table in `model-tiers.md`; commands stay stable.

Details: [CLAUDE_LONG.md § Model tier rule](CLAUDE_LONG.md#model-tier-rule-расширенно).

---

## Agent self-reporting rule (AGENT-GAPS.md)

Я ОБЯЗАН предложить запись в `AGENT-GAPS.md` в трёх случаях:

**Триггер 0 — /plan с коррекцией в задании (первый приоритет):**
Если текст задания /plan семантически указывает на то что прошлая работа агента была неполной, неверной или что-то важное было пропущено — **оценивай смысл, а не ключевые слова**. Примеры: явная критика реализации, недовольство результатом, указание на несделанное рядом со сделанным. → /plan ОБЯЗАН предложить AGENT-GAPS **до** начала pre-flight. Детали: Шаг -4 в commands/plan.md.

**Триггер 1 — Разработчик указывает на ошибку в моей работе:**
Если разработчик указывает на упущение/неточность в том что я сделал ("ты пропустил", "почему ты не...", "это неточно/неправильно", "ты не проверил") И я вношу правку → я ОБЯЗАН предложить запись — независимо от того, произнёс ли я конкретные признательные слова.

**Триггер 2 — Я сам признаю ошибку:**
Ключевые фразы: "ты прав", "я пропустил", "я не предусмотрел", "я упустил", "я был неточен", "я ошибся", "не учёл", "you're right", "I missed", "I overlooked".

**Обязательное действие:**
```
📝 Зафиксировать в AGENT-GAPS.md?
   Категория: [prompt-gap | context-gap | logic-gap | assumption-gap | completeness-gap | scope-gap]
   Гипотеза: [одна строка — почему я это пропустил]
   (y/n)
```

При `y` → записать немедленно, инкрементировать `agent_gaps_open_count` в `triggers.json`.
При `n` → не настаивать.

**Правило НЕ срабатывает на:** уточнения, дополнения, переформулировки, вопросы, новые требования.
**Срабатывает на:** (0) задание /plan семантически указывает на коррекцию прошлой работы — оцениваю смысл, а не ключевые слова; (1) разработчик корректирует мою работу и я вношу правку; (2) я явно признаю конкретное упущение.

**Пример — Триггер 0 (с явным указанием):**

> Разработчик: "/plan — добавь описания к командам. Ты добавил их к нодам, но не сделал аналогичного для PM-стрелок."
> Claude (первым делом, до pre-flight): "Задание содержит указание на пропуск в прошлой работе. 📝 Зафиксировать в AGENT-GAPS.md?
>   Категория: completeness-gap
>   Гипотеза: /review Шаг 3 не проверяет консистентность всех связанных нод при частичном изменении ARTIFACT-MAP
>   (y/n)"

**Пример — Триггер 0 (без триггерных слов, по смыслу):**

> Разработчик: "/plan — мне кажется, системное решение не было реализовано. Хочу пересмотреть подход."
> Claude (оценивает смысл: недовольство реализацией → коррекция): "Задание семантически указывает на недовольство прошлой реализацией. 📝 Зафиксировать в AGENT-GAPS.md?
>   Категория: scope-gap
>   Гипотеза: был выбран более простой вариант вместо системного решения
>   (y/n)"

**Пример — Триггер 1 (ситуационный, без фразы):**

> Разработчик: "Ты не проверил все существующие Dev-стрелки — только добавил новые."
> Claude: "Ты прав, я смотрел только на новые изменения. 📝 Зафиксировать в AGENT-GAPS.md?
>   Категория: context-gap
>   Гипотеза: /code Шаг 4 не требует аудита всех существующих human-actor стрелок при правке ARTIFACT-MAP
>   (y/n)"

**Пример — Триггер 2 (классический):**

> Разработчик: "Ты не проверил что файл уже существует перед записью."
> Claude: "Ты прав — я пропустил эту проверку. 📝 Зафиксировать в AGENT-GAPS.md?
>   Категория: completeness-gap
>   Гипотеза: /code Шаг 4 не содержит проверки side-effects записи
>   (y/n)"

Если `AGENT-GAPS.md` не существует в проекте → пропустить предложение тихо (не создавать файл автоматически).

---

## Hybrid dev

For projects combining AI agent workflow with manual human development:

- **Project root `CLAUDE.md`** — workflow rules (this file): `/plan`, `/code`, AI branch rule, architecture invariants
- **Service / directory `CLAUDE.md`** — technical stack rules (developer's own file: linting, naming conventions, test patterns, framework idioms)
- **`.claude/commands/`** — methodology slash commands

Claude Code loads both levels. Service-level takes priority over root on conflict. Workflow rules and technical rules are orthogonal — they don't conflict.

Escape hatch for solo-dev or single-branch setups: override the AI branch rule explicitly in this file with justification.

---

## Capture product signals (silent)

In any dialog — silently add to `IDEAS.md` when user says "would be nice if...", "didn't know...", "have to do X manually every time...", expresses surprise / confusion / repeats an action ≥3 times.

Don't mention IDEAS to user. Don't interrupt response. Add entry in parallel.

Symptom of violation: IDEAS.md empty after 10+ dialogues.

---

## DEVLOG tags (taxonomy)

Base: `[fix:X]` `[feat:X]` `[process:X]` `[infra:X]` `[security:X]` `[ops:X]` `[milestone]` `[regression:X]` `[missed-signal]` `[methodology]`

Methodology commands: `[architecture-audit]` `[sync-vision]` `[retro]` `[diagnose]` `[product-vision]` `[product-review]` `[product-check]`

**Semantic tagging rule:** Categorize problems semantically, not by surface name. One problem = one semantic indicator:
- `[git-failure]` — not `[git_push-failed]` OR `[github-error]` (same class)
- `[async-failure:X]` — not different names per operation type
- `[state-pollution]` — not `[history-leak]` AND `[cache-contamination]`
Reason: pattern detection in `/retro` breaks when the same problem is named differently.

Strategic axes from VISION.md: `[feat:<axis-tag>]`

Full DEVLOG entry format: [DEVLOG.md](DEVLOG.md).

---

