# CLAUDE.local.md — it-dev-methodology Project Configuration

Project-specific config for the methodology platform itself.
This file supplements [CLAUDE.md](CLAUDE.md) (methodology canonical rules).

> **Convention:**
> - [CLAUDE.md](CLAUDE.md) = methodology canon + project rules (this repo owns both).
> - This file (CLAUDE.local.md) = project-specific config fields read by commands at runtime.

---

## Branching

```yaml
mode: team
production_branch: main
agent_branch: ai-dev
integration_branch: main
pr_tool: auto-merge
auto_deploy: true
worktree_isolation: auto            # routine multi-session — auto; каждая сессия в своём worktree+ветке ai-dev/<task>
branch_namespace: ai-dev/<task>
```

Dog-fooding: methodology itself uses team-mode to validate the branching contract. Since it is a single-owner project, `integration_branch: main` (no separate dev branch). `pr_tool: auto-merge` — `deploy-push.sh` creates PR and merges immediately via `gh`. `auto_deploy: true` — agent runs /deploy automatically after /code (Lite) or confirmed /review without separate prompt. `worktree_isolation: auto` — owner routinely runs concurrent sessions; `auto` gives each session its own worktree+branch (ai-dev/<task>), eliminating dirty-index collisions by construction. `deploy-push.sh` reads the current branch (not hardcoded `agent_branch`) so namespaced branches work correctly. M0 verify passed 2026-06-11: git worktree works on this Git Bash/Windows machine, deploy-push.sh reads PUSH_BRANCH from current branch. The G-052/a17ecc1 incidents drove this flip.

---

## Auto-deploy (this project only)

`auto_deploy: true` — поведенческое правило для агента:
- **Lite mode `/code`:** после self-lint passed → пропустить "Запустить /review?" → сразу запустить `bash scripts/deploy-push.sh` (push + PR + auto-merge)
- **Full mode `/code` + подтверждённый `/review` (✅ merge):** сразу запустить `bash scripts/deploy-push.sh`
- После deploy → `bash scripts/sync-methodology.sh .` (self-apply)
- Не требует отдельного `/deploy` шага — он встроен в конец /code

---

## Consumer repos — READ ONLY (с исключениями для documentation-репо)

**Общее правило:** агент **не делает `git commit` или `git push` в consumer репо** кроме явно разрешённых случаев ниже.

**Чтение (анализ, диагностика):** разрешено всегда — consumer repos можно читать свободно.

**Запись файлов** (без commit/push): разрешена синком — `sync-methodology.sh` пишет `.claude/`, скрипты, артефакты.

**Git commit + push в consumer repo** — разрешён **только** при выполнении ВСЕХ условий:
1. Репо находится в `auto_commit_consumers` whitelist (ниже).
2. Коммитятся **только файлы из манифеста** `sync-methodology.sh --print-changed` (explicit pathspec, не дерево) — закрывает класс a17ecc1 (pathspec-overcapture).
3. Dirty-check по манифест-путям прошёл (грязный = пропустить, не коммитить).
4. Выполняется через `/push-consumers --commit-push` — не голым `git commit`.

❌ **Запрещено всегда:** прямой `git commit` / `git push` агентом без флага `--commit-push`; коммит файлов вне манифеста sync; любые операции в код-репо консьюмеров.

**Исключение — `/sync-audit` Gap 14 write-only (v5.46.0):** создаёт файлы через `new-project-init.sh` после явного per-repo подтверждения (init / skip / never). Git commit остаётся за пользователем.

### auto_commit_consumers whitelist

Белый список documentation-репо консьюмеров куда `/push-consumers --commit-push` разрешён делать git commit + push. Репо **вне списка** — только sync (commit невозможен by-construction).

```yaml
auto_commit_consumers:
  - path: ../erp-documentantion
    branch: main
  - path: ../it-dev-methodology-documentation
    branch: main
  - path: ../ai-assistant-documentation
    branch: main
  - path: ../client-matz-documentation
    branch: main
  - path: ../ebay-template-documentation
    branch: main
  - path: ../lead-gen-documentation
    branch: main
  - path: ../shopware-frontend-documentation
    branch: main
  - path: ../social-promo-documentation
    branch: main
```

> Добавить репо: добавить строку `- path: <relative-path>\n  branch: <branch>`. Путь относительно этого (`it-dev-methodology`) репо. Только documentation-репо — не код-репо консьюмеров.

---

## Consumers

Auto-discovery параметры для `/pull-consumers` (см. [commands-local/pull-consumers.md](commands-local/pull-consumers.md)).

```yaml
consumers_root: ..              # path relative to methodology repo
marker_file: .claude/.version   # marker that a sibling folder is methodology consumer
workspace_file: ../It dev methodology.code-workspace  # VSCode workspace file — primary discovery source
# exclude_paths: []             # абсолютные пути — /sync-audit Gap 14 пишет сюда при "never" решении
                                # /pull-consumers и /sync-audit Gap 14 молча пропускают эти репо
```

`/pull-consumers` использует **два режима discovery** (приоритет: workspace > sibling):

**Режим A — Workspace file (приоритет):** читает `workspace_file`, извлекает все `folders[].path`, резолвит пути относительно папки workspace-файла. Видит все репо добавленные в VSCode — включая `../URAI/`, `../Social Promo folder/` и другие за пределами sibling-дерева. Репо без `.claude/.version` включаются с пометкой `[no-marker]` (gap-checks пропускаются, DEVLOG/IDEAS читаются если есть).

**Режим B — Sibling scan (fallback):** если `workspace_file` не найден — сканирует `consumers_root/*/` как раньше, требует `marker_file`.

**Что НЕ нужно делать:**
- ❌ Не вести явный список консьюмеров здесь — discovery автоматический
- ❌ Не менять `workspace_file` без переноса workspace — путь должен указывать на актуальный `.code-workspace`

**Когда менять `workspace_file`:** если `.code-workspace` переименован или перемещён.

---

## Post-edit hooks

```yaml
rules:
  - pattern: "```mermaid"
    script: scripts/update-mermaid-links.sh
    file_arg: true
```

Dogfood: methodology platform использует тот же hook что и consumers.

---

## Iteration watchdog

Config для `iteration-watchdog.py` (PostToolUse, L4) + session gap counter (слой-3, `/plan` Шаг D + `/diagnose` 6.3.5).

```yaml
threshold: 3
threshold_escalate: 5
reset_on_commit: true
extensions: .vue .css .scss .tsx .jsx .svelte .html
gap_escalation_threshold: 3
gap_session_window_hours: 6
```

Dogfood: methodology platform применяет тот же escalation-config что и consumers. `reset_on_commit: true` — этот репо редко commit-per-iteration на одном frontend-файле (методология = markdown/python, не Vue); flip to `false` если frontend-тяжёлая сессия. Полное описание полей — `templates/CLAUDE_LOCAL.template.md ## Iteration watchdog`.

---

## Auto-update

Конфиг для `auto-update-watchdog.py` SessionStart hook.

```yaml
enabled: true
interval_hours: 2
on_failure: notify
methodology_path: .
doc_repo_path: ../it-dev-methodology-documentation
audit_threshold: 3
auto_pull: false
```

`methodology_path: .` — methodology-platform это самоаудит (this repo IS the methodology). Hook проверяет наличие обновлений, но не делает self-pull (вместо этого запускает `sync-methodology.sh .`).

`doc_repo_path: ../it-dev-methodology-documentation` — methodology-platform использует **two-repo** pattern: код здесь, документация (DEVLOG/карты/ADR) в sibling-репо. Команды (`/code`, `/review`, `/retro`) читают это значение для путей к артефактам. Consumer single-repo проекты имеют `doc_repo_path: null` (артефакты локальны). Closes G-076.

---

## Sync validators

```yaml
validators:
  - name: DEVLOG-on-commands-change
    trigger_paths: ["commands/*.md", "commands-local/*.md"]
    required_artifact: ../it-dev-methodology-documentation/DEVLOG.md
    reason: "Изменена команда методологии — DEVLOG запись добавлена?"
  - name: VERSION-on-sync-artifact-change
    trigger_paths: ["commands/*.md", "templates/**", "skills/**", "scripts/**"]
    required_artifact: VERSION
    reason: "Изменён синхронизируемый артефакт — VERSION bumped?"
  - name: CHANGELOG-on-consumer-feature
    trigger_paths: ["templates/scripts/**", "templates/.claude/**"]
    required_artifact: CHANGELOG.md
    reason: "Изменён consumer-facing артефакт — CHANGELOG запись добавлена?"
```

---

## Remotes

```yaml
origin_url: https://github.com/cait-solutions/it-dev-methodology.git
```

Used by `sync-methodology.sh` (auto-corrects `git remote set-url origin` if mismatch) and `/deploy` (validates before push).
**Tokens:** stored in OS credential manager (`gh auth login`). Never put tokens in this file.

### Push auth — multi-account (closes G-083)

> **Push доступ есть через `gh` credential helper — НЕ через `GITHUB_PAT` в `.env`.** `check-secret.sh GITHUB_PAT` возвращает exit 1, но это **не** значит что push невозможен: `gh auth` залогинен. Не приравнивай «нет GITHUB_PAT» к «нет доступа» — это два разных механизма.

Машина имеет **несколько `gh` аккаунтов** (`IDK-IDK`, `cait-solutions`, `cait-deployer`). Push в `cait-solutions/*` репо требует активного аккаунта **`cait-solutions`**.

**При push-failure (403 / "Permission denied") — ПЕРЕД любым выводом «нужен PAT»:**
```bash
gh api user -q .login                  # кто активен сейчас
gh auth switch --user cait-solutions   # переключить если не cait-solutions
git push origin <branch>               # повторить
```
403 под `IDK-IDK` = **wrong active account**, лечится `gh auth switch`, НЕ настройкой PAT.

> Для doc-repo (`it-dev-methodology-documentation`) — тот же аккаунт `cait-solutions`.
