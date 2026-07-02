# CLAUDE.md

Operational rules for AI agents. Short form, scan-friendly. For rationale, edge cases, and historical context — see [CLAUDE_LONG.md](CLAUDE_LONG.md).

> **Convention:**
> - This file (CLAUDE.md) = **WHAT** — methodology rules. Auto-updated by `sync-methodology.sh`. **Do NOT edit.**
> - [CLAUDE_LONG.md](CLAUDE_LONG.md) = **WHY** — rationale, edge cases, examples. Read on demand.
> - [CLAUDE.local.md](CLAUDE.local.md) = project-specific config (stack, invariants, threats, key files). **Edit freely.**
> - Adding/expanding a rule: WHAT (≤~5 lines) here, WHY → CLAUDE_LONG.md under the same anchor. Enforcement: `/code` Step 5 split-coupling + `validate-artifact-size.sh` (confirmer).

---

## Read before any work

1. `VISION.md` (or `docs/vision/*_GLOBAL_AGENT_VISION.md`) before every `/plan`.
2. Relevant ADRs / SYSTEM-MAP for the task domain.
3. `docs/data-map.md` (if exists) before storage-touching changes.
4. [CLAUDE.local.md](CLAUDE.local.md) — project stack, architecture invariants, security threats, key entry points.
5. [`.claude/rules/project-context.md`](.claude/rules/project-context.md) (if exists) — shared project context (Design Spec links, domain knowledge, onboarding). Tracked in git.

---

## Workflow rules

**Implementation through /code:** after `/plan` confirmation — implementation **mandatory** via `/code`. Direct edits forbidden for non-trivial changes. (`/code` updates `triggers.json.last_plan_session.code_run` — иначе methodology state drifts.)

**Deploy rule:** before every deploy → `/review` if not run in session → DEVLOG entry with `[deploy]` / `[feat:X]` / `[fix:X]` tag → update data map if changed.

**Architecture decision rule:** new modules / data flows / services / integrations → run `architect` sub-agent. Claude gives own recommendation BEFORE invoking architect (independent second opinion, not confirmation).

**Fix rule:** symptom → find cause (class-level fix preferred). Local fix needs justification why won't repeat; default to systemic (decorator / middleware / schema constraint).

**Completeness rule:** each plan/code/review/deploy decision MUST state: what is covered (happy path) · what is NOT (gaps, edge cases, parallel paths) · why gaps are OK or require action. Without this → plan not approved, code not merged, deploy blocked.

**Anti-cheat rule (no-gate-weakening):** ⛔ Never weaken an **artifact** or **criterion** to pass a quality gate — change the measured, not the measuring instrument. Applies to ANY gate (`/review`, `/doc-audit`, acceptance criteria, tests, map validators). Boundary: changing a gate as an explicit decision with named justification (gate was wrong) = legitimate; changing it to pass without justification = cheat. Examples: [CLAUDE_LONG.md § Anti-cheat](CLAUDE_LONG.md).

**Adjacent Impact rule:** before planning, enumerate adjacent zones (what reads this / depends on it); mark each in-scope or out-of-scope with reason. Classify solution: Point fix / Structural / Level 4+. Without this → plan incomplete. See `/plan` Step -1.3.

**Don't advise already-done:** check last 3-5 messages before suggesting an action that may already be running.

**AI branch rule:** all AI agent commits go to the branch in [CLAUDE.local.md](CLAUDE.local.md) → `## Branching` → `agent_branch` (default: `ai-dev`). Never commit to `main`/`master`/`develop`/`staging`/`integration_branch` without explicit approval. Before first commit: read `agent_branch`, then `git branch --show-current`; wrong branch → switch BEFORE changes.

**Methodology sync rule:** slash commands/hooks seem outdated — run `sync-methodology.sh` (path: `README.md` → "Обновление методологии"). CLAUDE.md auto-overwritten after sync.

**Retroactivity rule:** methodology updates apply to NEW plans only. Existing plans revised only if: (a) not yet in `/code`, or (b) critical blocking error new rules would catch. Don't revise completed plans for every update.

**Risk scope rule:** systemic risks (multiple tasks, live months/years) → `RISKS.md` only. Task-specific risks → stay in the plan (don't pollute the systemic registry).

**HIGH risks action rule:** if `RISKS.md` exists — `/plan` pre-flight checks open HIGH severity risks without a scheduled fix; any HIGH older than 14 days without a linked /plan → surfaced before analysis. Absent `RISKS.md` → skip silently.

**Frontend DOM verification rule:** any task touching `.vue`/`.tsx`/`.jsx`/`.svelte`/`.css`/`.html` — DOM verification required before commit. Three accepted paths: (1) Playwright E2E; (2) screenshot via Claude Code + Read tool with explicit DOM description; (3) explicit skip with written reason. «Wrote code → should work» without one of the three = not complete.

**Onboard update rule:** adding a new slash command / agent / rules file → update `/onboard` in the same commit/PR. If the new command is a discoverable **audit / strategy variant** (`*-audit`, roadmap/opinion/vision class) → also add it to the `how` router skill's routing table (that skill routes by task-type, so most commands need no edit — only new *entries in the audit/strategy sub-tables* do). Prevents the stale-router-reference class (e.g. a routing table naming a command that no longer exists).

**Skill frontmatter spec compliance rule:** creating/editing `skills/*/SKILL.md` — frontmatter MUST follow [official Anthropic spec](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview). Top-level keys: `name`, `description` (+ optional `metadata`). `description` = **single-line** ≤1024 chars (multi-line `description: |` → broken). `version`/`type`/custom → inside `metadata:`. `name` — lowercase+digits+hyphens, ≤64 chars, no "anthropic"/"claude". Verify with IDE linter before commit. Details: [CLAUDE_LONG.md § Skill frontmatter](CLAUDE_LONG.md).

**Bootstrap detection rule:** if `.claude/.version` absent — methodology never initialized here. First response: propose `bash <methodology_path>/scripts/new-project-init.sh .` (`<methodology_path>` default `../it-dev-methodology`, configurable in CLAUDE.local.md). `auto-update-watchdog.py` SessionStart hook detects this — surface it, don't work without bootstrap.

**PRODUCT.md component sync rule:** planning work touching code of a component → `/plan` Step -1.3 reads PRODUCT.md `## Логика компонентов → ### <component>`. Missing → block until section created with user. Exists → cite verbatim in `## Agent's understanding` (Step 3); mismatch → STOP. Changing component behavior → section in "Затронутые файлы" (Step 3) + updated in `/code` Step 5. `/review` L4 git-diff sync check: code changed without PRODUCT.md section → 🔵 Recommendation. Two-level: L3 in `/plan` + L4 in `/review`. Details: [CLAUDE_LONG.md § PRODUCT sync](CLAUDE_LONG.md).

**Purpose registry rule:** каждый нормативный элемент имеет explicit purpose (closes G-049 «purpose-by-position»): slash-команды — inline `> **Цель:** <строка>` после H1; hooks/scripts/artifacts/templates — строка в [CLAUDE_LONG.md § Purpose registry](CLAUDE_LONG.md). При создании/переименовании/удалении — обновить.

**Gap classification rule (AGENT vs PRODUCT):** два namespace: **AGENT-GAPS.md** — agent's reasoning failures (prompt/context/logic/assumption-gap, state-stale) → сигнал методологии; **PRODUCT-GAPS.md** — product coverage gaps (feature/capability/ux/integration/edge-case-gap) → сигнал roadmap. В `/plan` Шаг -4 classify семантически: «я не подумал» → AGENT; «продукт не умеет» → PRODUCT; сомнение → AGENT. `agent-gaps-watchdog.py` пишет только в AGENT-GAPS. Details: [CLAUDE_LONG.md § Gap classification](CLAUDE_LONG.md).

**Methodology delivery rule (push-only):** обновления доставляются **только** maintainer'ом через `/push-consumers` — проект не обновляется сам (нет consumer-side self-sync). Healthcheck (read-only): `bash scripts/sync-doctor.sh`. SessionStart `auto-update-watchdog.py` — read-only детектор drift+hook-health. Adoption gaps чинятся maintainer'ом.

**Sync validators framework rule:** `/review` reads CLAUDE.local.md `## Sync validators` — config-driven L3: doc artifacts updated alongside code. Default validators: PRODUCT-whole, PRODUCT-components, USER-MAP, SYSTEM-MAP, ARTIFACT-MAP, ADR-status. Each: `trigger_paths` (code globs) + `required_artifact`. Trigger matches `git diff main..HEAD` but artifact not in diff → 🔵 Recommendation with disposition. Opt-in: section absent → skipped. New validator = one YAML block, no code changes. Details: [CLAUDE_LONG.md § Sync validators](CLAUDE_LONG.md).

**Plain-language output rule:** команда, выдающая пользователю аналитический вывод (синтез/вердикт/рекомендации/findings), завершает вывод блоком `## Простыми словами` (2-5 строк): что значит и что делать, без жаргона. Резюме завершается **закрытым итогом** — следующий шаг («Рекомендую X») ИЛИ названная развилка с критерием («A если…, B если…»). ⛔ Не голый вопрос; не выдумывать рекомендацию где её нет (weakening = anti-cheat). Применяется к аналитическим командам (`/opinion`, `/plan`, `/research`, `/retro`, `/architecture-audit`, `/diagnose`, `/review`, `/roadmap`, `/product-check`, `/vision`, `/scan-sources*`, `/scope-out`, `/doc-audit`, `/marketing`, `/last-repo-changes`, `/pull-consumers`, `/push-consumers`). Не применяется к механическим/state-командам и внутренним артефактам. Новая аналитическая команда наследует правило. Details: [CLAUDE_LONG.md § Plain-language](CLAUDE_LONG.md).

For rationale and historical examples — [CLAUDE_LONG.md § Workflow rules](CLAUDE_LONG.md).

---

## Artifact Storage Rule

Где живут артефакты (полная таксономия — в ARTIFACT-MAP):

| Класс | Дом |
|---|---|
| Living-артефакт (DEVLOG, IDEAS, ROADMAP, RISKS, *-GAPS, HYPOTHESES) | корень / `docs/…` |
| Пришло извне (VCD, чужой анализ, дамп) | `inbox/` → `_processed/` |
| Durable-спека (ADR, design-spec, architecture) | `docs/adr` · `docs/architecture` · `docs/services/<svc>/` |
| Research-вывод (verdict) | `DEVLOG.md` строка `[research:X]` |
| Продукт работы (отчёт, аналитика, контент, deliverable) | `work/<stream>/` в **documentation-repo** (не code-repo) |
| Эфемерное (черновик-превью) | scratchpad вне репо / gitignored `_tmp_*` |

**MUST:** продукт работы → `work/<stream>/` (структура папок = живой индекс, не ручной README). Two-repo: `work/` всегда в documentation-repo. Эфемерное не оседает в корне. Research-вывод — строка в DEVLOG, не дублировать в `work/`.
**MUST NOT:** ❌ ad-hoc папки под deliverables (`docs/content/`, корневой `research/`) · разрастание `work/<stream>/` вместо promote в свой documentation-repo · `work/` в code-repo.
**Forward-only (grandfather):** правило для НОВЫХ артефактов; существующие организованные папки (`docs/analysis/`, `contracts/`) остаются (git mv порвёт входящие ссылки). Ретро-перенос только реактивно. Детектор сканирует только корневой litter. Enforcement: `validate-work-home.sh` (warn). Rationale: `work/README.md` + [CLAUDE_LONG.md § Artifact Storage](CLAUDE_LONG.md).

---

## Maps Standard Rule

Стандарт для трёх карт. Основа: arc42 multi-viewpoint + Living Documentation + C4-inspired диаграмм-дисциплина (нотация, не таксономия — карты это ортогональные viewpoints, не C4 zoom levels).

**Три карты (arc42 viewpoints):** SYSTEM-MAP (как устроена система) · USER-MAP (что умеет пользователь) · ARTIFACT-MAP (кто что обновляет и когда). Direction: SYSTEM-MAP ← USER-MAP ← ARTIFACT-MAP. Дублирование фактов запрещено — cross-reference.

**Структура карты:**
```
# [ТИП] — {{Project Name}}
**Версия:** vX.Y | **Обновлён:** YYYY-MM-DD | **Граф проверен:** YYYY-MM-DD
## Agent TL;DR      ← 5-15 строк scan-friendly
## [Диаграмма]      ← Mermaid с URL выше
## [Таблицы]        ← полный реестр (каждый компонент — строка)
## Refresh Policy   ← когда обновлять + когда НЕ
```

**Диаграмма:** Mermaid-only (ASCII/PlantUML запрещены). URL над блоком — bare URL, без `[текст](url)`; после правки mermaid-блока → `bash scripts/update-mermaid-links.sh <file>` (hook — страховка). Гибридный язык: технические термины/команды/файлы EN; описания поведения RU (❌ транслитерация кириллицы латиницей — не RU). Детализация: отдельный нод = уникальные связи; blob = одинаковые связи (label через `·`); ~15-20 нодов (детали в таблице). Группировка по доменам. Стрелки: `-->` W · `-.->` R · `===` RW · `--o` git · `--x` C. Repo/setup контекст в USER-MAP если внешний methodology-repo.

**Таблицы:** триггеры `🔁` цикл · `📊` счётчик · `🔭` стратегический · `⚡` событие. Акторы: Developer · PM/Owner · System · External · AI Agent.

**Governance:** PR-coupling (обновить карту в том же PR; рефакторинг/perf/typo — не обновлять). Audit: SYSTEM-MAP `/architecture-audit` ≥5 · USER-MAP `/product-check` ≥5 · ARTIFACT-MAP `/retro` ≥15. `/review` блокирует merge если: Mermaid удалён из SYSTEM/USER-MAP; новая команда/skill/артефакт без обновления карты. Details: [CLAUDE_LONG.md § Maps Standard](CLAUDE_LONG.md).

---

## Regulator levels (Level-4 framework)

Strong → weak: (1) Schema/type constraint — guarantee · (2) No alternative path — very strong · (3) Input data structure — strong · (4) Few-shot examples — medium, drifts · (5) Tool description — weak · (6) Prompt rule — ignored.

**Rule:** adding behavior — start from level 1-3, not 4-6. Prompt-only rule as first solution = 🔵 Recommendation in `/review`. Before accepting any rule — ask «is there a level-4+ (structural) fix?». If yes — primary, rule secondary. Details: [CLAUDE_LONG.md § Level-4 framework](CLAUDE_LONG.md).

---

## Model tier rule

Every methodology command MUST have `## Рекомендуемая модель` section. Canonical registry: [.claude/model-tiers.md](.claude/model-tiers.md). New command → also add row to per-command matrix; without both, `/review` blocks merge. Anthropic renames models → update only the Mapping table. Details: [CLAUDE_LONG.md § Model tier rule](CLAUDE_LONG.md).

---

## Agent self-reporting rule (AGENT-GAPS.md)

Записываю **автоматически** (без вопроса) в трёх случаях; после записи — одна строка извещения + opt-out «нет»/«n».

- **Триггер 0 — /plan с коррекцией в задании (приоритет):** текст задания семантически указывает что прошлая работа была неполной/неверной — оцениваю смысл, не ключевые слова → /plan Шаг -4 дедуп-grep + auto-write + извещение до pre-flight.
- **Триггер 1 — разработчик указывает на ошибку** («ты пропустил», «почему не...», «это неточно», «ты не проверил») И я вношу правку → записываю.
- **Триггер 2 — я сам признаю** («ты прав», «я пропустил», «не учёл», «I missed»…).

**Действие:** (1) дедуп-grep 2-3 ключевых слова в AGENT-GAPS.md (hit → извещаю, не дублирую); (2) запись сверху в `## Записи`, `Контекст:` = `/plan`|`/code`|`/free-chat`; (3) извещение `📝 Записано: G-NNN — [что]. Отменить: «нет»/«n»`.

**НЕ срабатывает на:** уточнения, дополнения, переформулировки, вопросы, новые требования. AGENT-GAPS.md отсутствует → пропустить тихо. Примеры (4 few-shot по триггерам): [CLAUDE_LONG.md § Agent self-reporting](CLAUDE_LONG.md).

---

## Secrets & Credentials

**Canonical store:** `.env` (per-project, gitignored) + optional `~/.config/it-dev/secrets.env` (shared). Declared keys + per-service metadata: `.claude/secrets-manifest.yaml` (schema v2+ — service_name/service_url/login → multi-host git credential routing).

**MUST:**
- Setup (one-time, user runs): `bash scripts/set-secret.sh KEY` (interactive: service_name, URL, login, expires_at, value via read -s).
- View metadata (no values): `secrets-show.sh` [KEY]. Audit + hygiene: `/secrets` or `validate-secrets.sh`. Rotate: `secrets-update.sh KEY`. Edit metadata: `secrets-edit.sh KEY`. Rollback: `secrets-rollback.sh`.
- Use in command (agent-safe): `with-secret.sh KEY -- <cmd>` (value never in stdout/transcript). Boolean: `check-secret.sh KEY` (exit 0/1). Git HTTPS: `git-credential-from-env.sh` as credential helper.

**MUST NOT:**
- ❌ Agent reading `.env` directly (blocked by `settings.json` deny + `bash_protect.py` for common-path readers; not universal — rotation = final net).
- ❌ `env`/`printenv`/`echo $SECRET`/`source .env` (blocked by `bash_protect.py`).
- ❌ Writing secret values into chat/DEVLOG/commit messages.
- ❌ Calling `_get-secret-raw.sh` (value → stdout → transcript; blocked; only user in terminal).
- ❌ Constructing `KEY="value" bash script.sh` (visible in tool input; use `with-secret.sh KEY -- cmd`; blocked).
- ❌ Committing `.env` (gitignored; `secrets-guard.py` blocks force-add) · `--no-verify` bypass without DEVLOG justification.

**On compromise:** rotate at provider → `set-secret.sh KEY <new>` → `secrets-scrub.sh` → check git history. Runbook: `skills/secrets-management/SKILL.md`. **Scope limit** (agent-mediated only; NOT OS-level; Windows NTFS `chmod 600` best-effort — use `icacls` on shared workstation) + external managers (Vault/AWS/Azure via priority chain step 3): [CLAUDE_LONG.md § Secrets](CLAUDE_LONG.md).

---

## Hybrid dev

Projects combining AI agent workflow with manual human development:
- **Project root `CLAUDE.md`** — workflow rules (this file): `/plan`, `/code`, AI branch rule, invariants.
- **Service/directory `CLAUDE.md`** — technical stack rules (developer's own: linting, naming, test patterns, idioms).
- **`.claude/commands/`** — methodology slash commands.

Claude Code loads both; service-level takes priority on conflict (rules orthogonal). Escape hatch for solo-dev/single-branch: override AI branch rule explicitly with justification.

---

## Capture product signals (silent)

In any dialog — silently add to `IDEAS.md` when user says «would be nice if...», «didn't know...», «have to do X manually every time...», expresses surprise/confusion, or repeats an action ≥3 times. Don't mention IDEAS to user; don't interrupt response; add in parallel. Symptom of violation: IDEAS.md empty after 10+ dialogues.

---

## DEVLOG tags (taxonomy)

Base: `[fix:X]` `[feat:X]` `[process:X]` `[infra:X]` `[security:X]` `[ops:X]` `[milestone]` `[regression:X]` `[missed-signal]` `[methodology]`. Methodology commands: `[architecture-audit]` `[sync-vision]` `[retro]` `[diagnose]` `[product-vision]` `[product-review]` `[product-check]`. Strategic axes from VISION.md: `[feat:<axis-tag>]`.

**Semantic tagging rule:** categorize problems semantically, not by surface name — one problem = one semantic indicator (`[git-failure]` not `[git_push-failed]`/`[github-error]`; `[state-pollution]` not `[history-leak]`+`[cache-contamination]`). Reason: pattern detection in `/retro` breaks when the same problem is named differently.

Full DEVLOG entry format: [DEVLOG.md](DEVLOG.md).
