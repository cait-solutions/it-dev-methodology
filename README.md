# IT Dev Methodology Platform

Version: see [VERSION](VERSION)

A shared methodology repository for AI-assisted software development. Contains commands, agents, rules, and project templates used across all cait.solutions projects.

## Structure

```
methodology-platform/
├── commands/              ← Slash-command definitions for Claude Code
│   ├── plan.md            — /plan: structure work before coding
│   ├── code.md            — /code: implementation standards
│   ├── review.md          — /review: PR review checklist
│   ├── deploy.md          — /deploy: safe deployment process
│   ├── retro.md           — /retro: retrospective format
│   └── architecture-audit.md — /architecture-audit: quarterly audit
├── agents/                ← Agent definitions (coming soon)
├── rules/                 ← Shared lint/behavior rules (coming soon)
├── templates/             ← Project bootstrap templates
│   ├── PRODUCT.template.md
│   ├── VISION.template.md
│   ├── SYSTEM-MAP.template.md
│   ├── CLAUDE.template.md
│   └── new-project-init.sh
└── VERSION                ← Semver of this methodology
```

## Quick Start — New Project

```bash
# From within this repo
bash templates/new-project-init.sh my-project-name /path/to/new/project
```

## Versioning

This repo follows semver:
- **MAJOR** — breaking changes to command contracts or template structure
- **MINOR** — new commands, agents, or templates added
- **PATCH** — fixes and refinements to existing content
