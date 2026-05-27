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
```

Dog-fooding: methodology itself uses team-mode to validate the branching contract. Since it is a single-owner project, `integration_branch: main` (no separate dev branch). `pr_tool: auto-merge` — `deploy-push.sh` creates PR and merges immediately via `gh`. `auto_deploy: true` — agent runs /deploy automatically after /code (Lite) or confirmed /review without separate prompt.

---

## Auto-deploy (this project only)

`auto_deploy: true` — поведенческое правило для агента:
- **Lite mode `/code`:** после self-lint passed → пропустить "Запустить /review?" → сразу запустить `bash scripts/deploy-push.sh` (push + PR + auto-merge)
- **Full mode `/code` + подтверждённый `/review` (✅ merge):** сразу запустить `bash scripts/deploy-push.sh`
- После deploy → `bash scripts/sync-methodology.sh .` (self-apply)
- Не требует отдельного `/deploy` шага — он встроен в конец /code

---

## Consumer repos — READ ONLY

❌ **НИКОГДА не коммитить, не пушить, не изменять файлы** в consumer репо:
- `erp-documentantion/` (и любые sibling repos не являющиеся `it-dev-methodology` или `it-dev-methodology-documentation`)
- Consumer repos используются ТОЛЬКО для чтения (анализ паттернов, диагностика)
- Все изменения только в `it-dev-methodology/` и `it-dev-methodology-documentation/`
- Перед `git add` / `git commit` — проверить что cwd находится в одном из двух разрешённых репо

---

## Remotes

```yaml
origin_url: https://github.com/cait-solutions/it-dev-methodology.git
```

Used by `sync-methodology.sh` (auto-corrects `git remote set-url origin` if mismatch) and `/deploy` (validates before push).
**Tokens:** stored in OS credential manager (`gh auth login`). Never put tokens in this file.
