# {{Project Name}} — Project Context

Project-specific context for AI agents. This file is:
- **Tracked in git** — available to all developers who clone the repo
- **Project-owned** — edit freely, not overwritten by `sync-methodology.sh`
- **Agent-readable** — loaded by Claude Code agents when referenced in `CLAUDE.md`

> **Convention:** This file supplements [CLAUDE.md](../../../CLAUDE.md) (methodology rules) and
> [CLAUDE.local.md](../../../CLAUDE.local.md) (personal/machine config).
> Fill in the sections below that apply to your project. Remove sections that don't apply.

---

## Project type

`<choose: ai-agent | web-app | api-service | cli-tool | library | multi-service-platform | methodology-platform>`

Brief description (1-2 sentences): `<what this project does and for whom>`

---

## Key Design Specs

Documents that define how this project works. Read before `/plan` on the relevant feature.

| Feature / Area | Design Spec | Status | Notes |
|---|---|---|---|
| `<feature name>` | [`<SPEC_NAME>_DESIGN.md`](<path/to/SPEC_NAME_DESIGN.md>) | Draft \| Final | `<what it covers>` |

> **How to add:** when you create a new Design Spec (`/design-spec`), add a row here.
> Remove this table if the project has no Design Specs.

---

## Key artifacts to read before /plan

Beyond what `CLAUDE.md § Read before any work` prescribes:

- `<path/to/file>` — `<why to read it; what it tells you>`
- `<path/to/file>` — `<why>`

> Remove items that duplicate what CLAUDE.md already lists.
> Keep only project-specific additions.

---

## Domain knowledge

Key concepts, terminology, or constraints that an AI agent needs to understand to work effectively
in this project. Add only what is non-obvious from reading the code.

- `<concept>` — `<1-sentence explanation>`
- `<constraint>` — `<why it exists>`

> Remove this section if there is nothing non-obvious.

---

## Onboarding pointers

For a new developer or a new Claude Code session on a different machine:

1. `<first thing to do>` — `<why>`
2. `<second thing>` — `<why>`

> Example: "Run `new-project-init.sh` — sets up .claude/ structure"
> Remove this section if CLAUDE.md / README.md already covers onboarding fully.

---

*Last updated: `<YYYY-MM-DD>` by `<author>`*
