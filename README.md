# IT Dev Methodology Platform

Version: see [VERSION](VERSION)

A shared methodology repository for AI-assisted software development. Provides slash commands, agent skeletons, artifact templates, and bootstrap/sync scripts used across all cait.solutions projects.

The methodology is derived from the ERP platform's mature multi-service approach, with single-developer patterns (hooks, IDEAS taxonomy, ROADMAP structure, level-4 regulator framework) merged in from the PAI project.

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

- **Phase A (this PR):** rename `product.vision.md`, canonical `triggers.json` template, real bootstrap and sync scripts.
- **Phase B:** full templates for DEVLOG, IDEAS, ROADMAP, OPEN-QUESTIONS, HYPOTHESES, RISKS.
- **Phase C:** rewrite CLAUDE/PRODUCT/SYSTEM-MAP/VISION templates with patterns from live projects.
- **Phase D:** Tier-2 templates — two-tier vision (AGENT_VISION + LONG_VISION), ADR, data-map, glossary, BEHAVIOR, threat-model, SKILL, services-registry, inbox.
- **Phase E:** agent skeletons (architect/qa/security), hooks (`bash_protect.py`, `protect.py`, `docs_reminder.template.py`), rules guide.
- **Phase F:** apply methodology to this repo itself — generate its own CLAUDE.md, PRODUCT.md, DEVLOG.md and adopt the `/plan` flow for future changes.
