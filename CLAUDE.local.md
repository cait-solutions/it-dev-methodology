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
agent_doc_branch: ai-documentation
integration_branch: main
pr_tool: manual
```

Dog-fooding: methodology itself uses team-mode to validate the branching contract. Since it is a single-owner project, `integration_branch: main` (no separate dev branch). Agent commits to `ai-dev`, `/deploy` outputs PR URL, owner self-merges.
