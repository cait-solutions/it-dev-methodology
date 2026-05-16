# /review — Code Review Command

## Purpose
Systematic review of a pull request or diff before merge.

## Trigger
Use after `/code` completes. Can be triggered on any PR or diff.

## Inputs
- PR link or branch name
- Original plan or task description
- `CLAUDE.md` conventions

## Checklist

### Correctness
- [ ] Logic matches the plan / task requirements
- [ ] Edge cases handled
- [ ] No silent failures or swallowed errors

### Security
- [ ] No injection vectors (SQL, command, XSS)
- [ ] Secrets not hardcoded or logged
- [ ] Input validated at system boundaries

### Code Quality
- [ ] Names are self-explanatory
- [ ] No dead code, commented-out blocks, or TODOs left behind
- [ ] No premature abstractions

### Tests
- [ ] Tests cover happy path and key edge cases
- [ ] No mocks masking real integration behavior

### Conventions
- [ ] Follows `CLAUDE.md` standards
- [ ] Commit messages are clear and purposeful

## Output
Review summary: Approve / Request Changes / Block (with blockers listed).
