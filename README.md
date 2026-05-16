# IT Dev Methodology Platform

Version: see [VERSION](VERSION) (currently **v3.0.0** — first major bump, breaking change in CLAUDE.md split convention)

> ⚠️ **For consumers:** This repo is the _methodology canon_ (commands, templates, scripts). Do NOT clone directly. Instead, run:
> ```bash
> bash /path/to/methodology/scripts/new-project-init.sh my-project ~/my-project
> ```
> Files like DEVLOG.md, PRODUCT.md, VISION.md are _our project context_, not methodology templates.

Общая методология для AI-assisted разработки на проектах cait.solutions. Slash-команды, скелеты sub-agents, шаблоны артефактов, защитные хуки, bootstrap/sync скрипты — единый источник правды.

Методология развивалась из опыта как single-developer, так и multi-service проектов. Patterns из обоих подходов (хуки, IDEAS таксономия, ROADMAP структура, level-4 framework) влиты как универсальные дополнения.

С версии v2.4.0 методология применяется к самой себе (eats own dog food) — изменения идут через её собственный `/plan` → `/code` → `/review` → `/deploy` процесс. См. [CLAUDE.md](CLAUDE.md), [PRODUCT.md](PRODUCT.md), [VISION.md](VISION.md).

## Structure

```
methodology-platform/
├── commands/              ← Slash-command definitions (synced into project .claude/commands/)
│   ├── plan.md            /plan — pre-flight checks, plan with risks
│   ├── code.md            /code — implementation with self-review
│   ├── review.md          /review — strict architectural review
│   ├── deploy.md          /deploy — safety checks, smoke tests
│   ├── retro.md           /retro — methodological retrospective
│   ├── diagnose.md        /diagnose — deep root-cause investigation
│   ├── onboard.md         /onboard — new developer / legacy domain handover
│   ├── architecture-audit.md  /architecture-audit — map vs code drift
│   ├── sync-vision.md     /sync-vision — vision ↔ reality reconciliation
│   ├── product-check.md   /product-check — PRODUCT.md vs code freshness
│   ├── product-review.md  /product-review — IDEAS signals → ROADMAP
│   └── product-vision.md  /product-vision — strategic axes (quarterly)
├── agents/                ← Agent skeletons (Claude Code sub-agent format) — Phase E
├── rules/                 ← Tech-stack-specific rules guide — Phase E
├── hooks/                 ← Universal protection hooks (Bash/Edit safety) — Phase E
├── templates/             ← Artifact templates
│   ├── triggers.json.template     ← canonical state schema
│   ├── CLAUDE.template.md
│   ├── PRODUCT.template.md
│   ├── VISION.template.md
│   └── SYSTEM-MAP.template.md
├── scripts/
│   ├── new-project-init.sh        ← bootstrap a fresh project
│   └── sync-methodology.sh        ← update commands/hooks in existing project
├── VERSION                ← semver of the methodology
└── README.md
```

## Quick Start — Bootstrap a new project

```bash
# From the methodology repo (works on any path):
/path/to/methodology-platform/scripts/new-project-init.sh my-project /path/to/new/project
```

This creates the target directory with:
- `.claude/commands/` — all slash commands, banner-prefixed
- `.claude/state/triggers.json` — initialized counters
- `.claude/.version` — pointer to methodology version
- Root artifacts: `CLAUDE.md`, `PRODUCT.md`, `VISION.md`, plus stubs for DEVLOG/IDEAS/ROADMAP/HYPOTHESES/RISKS
- `docs/architecture/SYSTEM-MAP.md`
- Git initialized if absent

## Sync — Update an existing project to latest methodology

```bash
/path/to/methodology-platform/scripts/sync-methodology.sh /path/to/project
```

- Overwrites `.claude/commands/*.md` (canonical source = methodology). Warns if local edits found.
- Copies new agent skeletons (existing per-project content preserved).
- Copies hooks (universal infrastructure — always overwrite).
- Updates `.claude/.version`.

Each synced command file starts with an AUTO-GENERATED banner. Local edits are allowed only as emergency overrides — open a PR to the methodology repo within 48h.

## Versioning

Semver:
- **MAJOR** — breaking changes to command contracts, triggers.json schema, or artifact format
- **MINOR** — new commands, agents, templates, or non-breaking field additions
- **PATCH** — fixes, wording, and content refinements

## Roadmap

Initial build (Phases A-F) — **completed 2026-05-16, v2.4.0**:

- ✅ **Phase A:** rename `product.vision.md`, canonical `triggers.json` template, real bootstrap and sync scripts.
- ✅ **Phase B:** full templates for DEVLOG, IDEAS, ROADMAP, OPEN-QUESTIONS, HYPOTHESES, RISKS.
- ✅ **Phase C:** rewrite CLAUDE/PRODUCT/SYSTEM-MAP/VISION templates with patterns from live projects.
- ✅ **Phase D:** Tier-2 templates — two-tier vision (AGENT_VISION + LONG_VISION), ADR, data-map, glossary, BEHAVIOR, threat-model, SKILL, services-registry, inbox.
- ✅ **Phase E:** agent skeletons (architect/qa/security), hooks (`bash_protect.py`, `protect.py`, `docs_reminder.template.py`), rules guide.
- ✅ **Phase F:** apply methodology to this repo itself — real CLAUDE.md, PRODUCT.md, VISION.md, SYSTEM-MAP.md, DEVLOG.md with phase history. Future changes go through the methodology's own `/plan` → `/code` → `/review` → `/deploy` flow.
- ✅ **Phase G1 (v2.5.0):** navigation maps in `/review`, `/deploy`, `/onboard`; model recommendation tier system (`templates/model-tiers.md`) with Pre-flight check and mid-task complexity reassessment.
- ✅ **Phase G2 (v3.0.0, breaking):** CLAUDE.md split into short `CLAUDE.md` (WHAT — rules) + new `CLAUDE_LONG.md` (WHY — rationale, edge cases); Agent TL;DR convention in PRODUCT and SYSTEM-MAP templates; migration helper `scripts/migrate-claude-md.sh` for existing consumers; Pre-flight check now asks user (was auto-detect from system prompt — unreliable mid-session).
- ✅ **Phase H1 (v3.1.0, breaking):** Bootstrap simplification — removed all flags from `new-project-init.sh` (`--multi-service`, `--with-adr`, `--with-inbox`, etc.). One universal init command for all project types. Full artifact structure created by default; solo-dev projects ignore/delete unused dirs, multi-service projects fill in the multi-tier sections. Consumer templates sanitized: removed project-specific names (PAI, ERP, nexchance), replaced with generic abstractions (single-dev, multi-service).

**Breaking change migration for existing consumers:**

*Phase G2 (CLAUDE.md split):*
```bash
# Run once per consumer:
/path/to/methodology-platform/scripts/migrate-claude-md.sh /path/to/consumer
# Then follow the 5-step manual extraction instructions.
```

*Phase H1 (bootstrap flags):*
```bash
# Old (v3.0.0):
bash scripts/new-project-init.sh my-app ~/my-app --multi-service --with-adr --with-inbox

# New (v3.1.0+):
bash scripts/new-project-init.sh my-app ~/my-app
# → creates full structure; ignore unused dirs or delete them
```

Next planned work — see [ROADMAP.md](ROADMAP.md) for current priorities.
