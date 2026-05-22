# CLAUDE.local.md — {{Project Name}} Project Configuration

Project-specific rules and configuration for AI agents.
This file supplements [CLAUDE.md](CLAUDE.md) (methodology canonical rules — auto-updated by sync).

> **Convention:**
> - [CLAUDE.md](CLAUDE.md) = methodology rules. Auto-updated by `sync-methodology.sh`. **Do NOT edit.**
> - This file (CLAUDE.local.md) = project-specific config. **Edit freely.**

**Project type:** `<choose: ai-agent | web-app | api-service | cli-tool | library | multi-service-platform>` — used by `/review` and `/deploy` for additional checks.

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

## Project-specific Don'ts

- ❌ Don't edit `.env`, secrets, deploy files (`_deploy.*`, `_update.*`).
- ❌ Don't add packages without updating `requirements.txt` / `package.json`.
- ❌ Don't call external APIs directly — only via single adapter.
- ❌ `<project-specific don't>`

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

## Branching

```yaml
mode: solo                          # solo | team
production_branch: main             # protected — agent never commits here directly
agent_branch: ai-dev                # AI branch (single source of truth, enforced by /code and /deploy).
                                    # Applies to all repo types — doc-repos and code-repos use the same name.
                                    # Differentiation comes from repo isolation, not branch naming.
# team-mode only (uncomment and fill):
# integration_branch: dev           # PR target — where agent_branch merges (dev | main | etc.)
# pr_tool: manual                   # manual (default) | gh
```

- **solo** (default): agent pushes `{agent_branch} → production_branch` directly. For single-owner projects.
- **team**: agent pushes `{agent_branch}` to remote, `/deploy` outputs PR creation URL. Human reviews and merges.

Switch to `team` when the project has >1 developer or requires a review gate.
See [ADR-002](docs/adr/ADR-002-branching-mode-contract.md) for rationale.

---

## External links

- Runbooks: `<link>`
- Wiki: `<link>`
- Monitoring: `<link>`
- Incident response: `<link>`
