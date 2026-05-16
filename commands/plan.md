# /plan — Planning Command

## Purpose
Translate a feature request or problem statement into a structured implementation plan before any code is written.

## Trigger
Use when: starting a new feature, refactoring a module, or resolving a complex bug requiring multiple steps.

## Inputs
- Feature description or issue link
- Relevant context files (PRODUCT.md, SYSTEM-MAP.md)
- Constraints (deadlines, tech stack, team size)

## Process
1. Clarify scope — what is in and out of scope
2. Identify affected components from SYSTEM-MAP
3. Draft step-by-step implementation tasks
4. Flag risks, dependencies, and open questions
5. Estimate complexity (S/M/L/XL)

## Outputs
- `PLAN.md` in the project root or feature branch
- Task list with clear acceptance criteria
- Decision log for non-obvious choices

## Exit Criteria
Plan reviewed and approved before coding begins.
