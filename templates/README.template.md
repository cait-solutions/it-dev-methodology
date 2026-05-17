# {{Project Name}}

> Open this folder as your Claude Code workspace, then run `/plan` for the first feature.

---

## After `git clone`

Slash commands are gitignored (synced, not project-owned). Restore them locally after cloning:

```bash
bash /path/to/it-dev-methodology/scripts/sync-methodology.sh .
```

Takes < 30 seconds. After that, open this folder in Claude Code — `/plan`, `/code`, `/review`, `/deploy` are all available.

**Workspace root:** open `{{Project Name}}/` directly in Claude Code (not the parent directory). Commands are resolved from workspace root.

---

## Workflow

```
/plan  →  /code  →  /review  →  /deploy
```

| Command | What it does |
|---|---|
| `/plan` | Architectural analysis + implementation plan |
| `/code` | Implementation per approved plan |
| `/review` | Pre-deploy review with architecture checks |
| `/deploy` | Deploy with safety checks + DEVLOG entry |

---

## Architecture

- [SYSTEM-MAP](docs/architecture/SYSTEM-MAP.md) — components, edges, layers
- [USER-MAP](docs/product/USER-MAP.md) — what users/teams can do with this system
- [PRODUCT.md](PRODUCT.md) — system behavior from user's point of view
- [VISION.md](VISION.md) — strategic axes

---

## Dev artifacts

| File | Purpose |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Operational rules for AI agents |
| [DEVLOG.md](DEVLOG.md) | Decision and deploy history |
| [IDEAS.md](IDEAS.md) | Raw product signals |
| [ROADMAP.md](ROADMAP.md) | Product backlog |
| [OPEN-QUESTIONS.md](OPEN-QUESTIONS.md) | Unresolved decisions |
| [HYPOTHESES.md](HYPOTHESES.md) | Hypotheses under review |
| [RISKS.md](RISKS.md) | Risk registry |

---

## Keeping methodology up to date

This project uses [it-dev-methodology](https://github.com/cait-solutions/it-dev-methodology).

To pull the latest commands and hooks:

```bash
bash /path/to/it-dev-methodology/scripts/sync-methodology.sh .
```
