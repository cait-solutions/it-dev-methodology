# CLAUDE.md — {{Project Name}}

Operational rules for AI agents. Short form, scan-friendly. For rationale, edge cases, and historical context — see [CLAUDE_LONG.md](CLAUDE_LONG.md).

> **Convention:**
> - This file (CLAUDE.md) = **WHAT** — rules, MUST / MUST NOT, conventions. Auto-loaded by Claude Code.
> - [CLAUDE_LONG.md](CLAUDE_LONG.md) = **WHY** — rationale, edge cases, examples. Read on demand.
> - Local `CLAUDE.local.md` (if exists) overrides these rules.

**Project type:** `<choose: ai-agent | web-app | api-service | cli-tool | library | multi-service-platform>` — used by `/review` and `/deploy` for additional checks.

---

## Read before any work

1. `VISION.md` (or `docs/vision/*_GLOBAL_AGENT_VISION.md`) before every `/plan`.
2. Relevant ADRs / SYSTEM-MAP for the task domain.
3. `docs/data-map.md` (if exists) before storage-touching changes.

---

## Architecture invariants (MUST / MUST NOT)

See [SYSTEM-MAP.md](docs/architecture/SYSTEM-MAP.md).

**MUST:**
- `<invariant 1 — e.g. all external API calls via single adapter>`
- `<invariant 2>`

**MUST NOT:**
- `<anti-pattern 1 — e.g. business logic in controllers>`
- `<anti-pattern 2>`

For rationale of each invariant — see [CLAUDE_LONG.md § Architecture](CLAUDE_LONG.md#архитектура-расширенно).

---

## Stack

- **Language / framework / DB / queues / testing / CI / deploy:** `<one-line each>`

---

## Data ownership (short)

| Storage | Source of truth | Writers | Invalidation |
|---|---|---|---|
| | yes/no (cache) | | |

Full details in [CLAUDE_LONG.md § Data map](CLAUDE_LONG.md#карта-данных-полная) or [`docs/data-map.md`](docs/data-map.md).

---

## Don'ts

- ❌ Don't edit `.env`, secrets, deploy files (`_deploy.*`, `_update.*`).
- ❌ Don't add packages without updating `requirements.txt` / `package.json`.
- ❌ Don't call external APIs directly — only via single adapter.
- ❌ `<project-specific don't>`

---

## Workflow rules

**Implementation through /code:** after `/plan` confirmation — implementation **mandatory** via `/code`. Direct edits forbidden for non-trivial changes. Reason: `/code` updates `triggers.json.last_plan_session.code_run` — without this, methodology state drifts.

**Deploy rule:** before every deploy → `/review` if not run in session → DEVLOG entry with `[deploy]` / `[feat:X]` / `[fix:X]` tag → update data map if changed.

**Architecture decision rule:** new modules / data flows / services / integrations → run `architect` sub-agent. Claude gives own recommendation BEFORE invoking architect (independent second opinion, not confirmation).

**Fix rule:**
- Symptom or cause? Symptom → find cause. Cause → class-level fix preferred.
- Local or systemic? Local needs justification why won't repeat. Default to systemic (decorator / middleware / schema constraint).

**Don't advise already-done:** check last 3-5 messages before suggesting an action that may already be running.

**AI branch rule:** All AI agent commits go to `ai-dev` branch (or other designated AI branch named in this file). Never commit to `main`, `master`, `develop`, or `staging` without explicit developer approval.
Before first commit in session: `git branch --show-current`. Wrong branch → switch BEFORE any changes, not after.

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

Я ОБЯЗАН предложить запись в `AGENT-GAPS.md` в двух случаях:

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
**Срабатывает на:** (1) разработчик корректирует мою работу и я вношу правку; (2) я явно признаю конкретное упущение.

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

Strategic axes from VISION.md: `[feat:<axis-tag>]`

Full DEVLOG entry format: [DEVLOG.md](DEVLOG.md).

---

## Security: real threats only

Before proposing security measure — check it closes a concrete threat from project threat-list:

- **Secret leak (High):** `<project-specific tokens / where they may leak>`
- **Data loss (High):** `<storages without backup>`
- **Access compromise (High):** `<auth attack vectors>`
- **Financial (Med):** `<billing-affecting>`
- **Operational (Med):** `<monitoring gaps>`

**Rule:** if proposed measure closes ZERO threats from this list → it's security theater. Justify or skip.

Details: [CLAUDE_LONG.md § Security threats](CLAUDE_LONG.md#реальные-угрозы-безопасности-расширенно).

---

## Key entry points

- `<main / index>`
- `<router / dispatcher>`
- `<config loader>`
- `<data layer entry>`

---

## External links

- Runbooks: `<link>`
- Wiki: `<link>`
- Monitoring: `<link>`
- Incident response: `<link>`
