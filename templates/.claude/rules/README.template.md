# {{Project Name}} — Technology Stack Rules

Project-specific guardrails for your tech stack. These rules are read by:
- `/review` command (Шаг 2 — context rules)
- `qa.md` agent (before deep code analysis)

---

## Standard files in this directory

| File | Purpose | Tracked in git |
|---|---|---|
| `README.md` (this file) | Directory guide | ✅ yes |
| `project-context.md` | Shared project context: Design Spec links, domain knowledge, onboarding | ✅ yes |
| `<stack>-style.md` | Tech stack rules (Python, Go, SQL, etc.) | ✅ yes |

> **`project-context.md`** is the primary shared-context file. All developers who clone this repo
> receive it automatically. AI agents read it when instructed by `CLAUDE.md § Read before any work`.

---

## How to use this directory

Create `.md` files for each domain or technology:

| File | Purpose | Example |
|---|---|---|
| `python-style.md` | Python naming, linting, idioms | "All async functions must have timeout ≤ 30s" |
| `go-best-practices.md` | Go conventions, error handling | "Use errors.Is() for error comparison, not ==" |
| `sql-constraints.md` | Database constraints, migrations | "All timestamps must be UTC, never local" |
| `api-contracts.md` | REST/gRPC standards | "All errors return {error, code, message}" |
| `security-rules.md` | Auth, secrets, audit | "PII must be hashed. No plain-text passwords." |

---

## Template: python-style.md

```
# Python Style Rules

## Naming
- Constants: UPPER_SNAKE_CASE
- Private methods: _leading_underscore
- Avoid single-letter variables except loop counters

## Error handling
- Always log exceptions with context
- Catch specific exceptions, not bare except
- No try/except: pass — be explicit

## Async
- All async functions must have timeout ≤ 30s
- Use asyncio.timeout() or timeout decorators
- Document timeout behavior in docstring

## Tests
- Test name format: test_<function>_<scenario>_<expected_result>
- Use fixtures for setup, not setUp methods
```

---

## When to update

- Adding a new language/framework → new file
- Catching repeated issues in `/review` → add rule to prevent
- Standards change → bump version in header

Example:
```
# Python Style Rules (v1.2)
Updated: 2026-05-17
```

---

## Note for `/review` agent

When `/review` reads this directory:
- It's looking for shared constraints across your codebase
- Use to define what "correct" means for your project
- More specific than ADR, more agile than contracts
