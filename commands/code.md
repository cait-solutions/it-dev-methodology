# /code — Coding Command

## Purpose
Guide the implementation phase: writing, reviewing, and iterating on code against an approved plan.

## Trigger
Use after `/plan` is approved. Also use for hotfixes where a plan is overkill.

## Inputs
- Approved `PLAN.md` or clear task description
- `CLAUDE.md` for project conventions
- Relevant existing code context

## Process
1. Read `CLAUDE.md` — follow all conventions defined there
2. Implement smallest working unit first
3. Write or update tests alongside code
4. Self-review: security, edge cases, naming, no dead code
5. Run linter and tests before declaring done

## Standards
- No comments explaining WHAT; only WHY when non-obvious
- No speculative abstractions — solve the task at hand
- Validate at system boundaries only (user input, external APIs)
- No backwards-compatibility shims for dead code

## Exit Criteria
Tests pass, linter clean, ready for `/review`.
