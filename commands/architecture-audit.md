# /architecture-audit — Architecture Audit Command

## Purpose
Periodic review of system architecture for drift, tech debt, security gaps, and scalability risks.

## Trigger
Quarterly, before major new features, or when team suspects systemic issues.

## Inputs
- Current `SYSTEM-MAP.md`
- Recent `PLAN.md` files and retros
- Dependency list and versions

## Audit Areas

### Structural Health
- [ ] SYSTEM-MAP matches reality — no phantom components
- [ ] Clear ownership for each component
- [ ] No circular dependencies

### Technical Debt
- [ ] Identify components older than 2 years without review
- [ ] Deprecated libraries or APIs still in use
- [ ] Duplicated logic across modules

### Security Posture
- [ ] Auth and authz boundaries correct
- [ ] Secrets management up to standard
- [ ] Attack surface reviewed (exposed endpoints, file uploads, etc.)

### Scalability
- [ ] Bottlenecks identified (DB, queues, sync calls)
- [ ] Single points of failure documented
- [ ] Load estimates vs. current capacity

### Observability
- [ ] All critical paths have logging, metrics, and alerts
- [ ] Runbooks exist for top failure modes

## Output
- Architecture audit report with findings ranked by severity
- Updated `SYSTEM-MAP.md` if needed
- Action items fed into next sprint planning

## Exit Criteria
Report delivered, critical findings have owners and timelines.
