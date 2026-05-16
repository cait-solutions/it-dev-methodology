# /deploy — Deployment Command

## Purpose
Coordinate and verify a safe production deployment.

## Trigger
Use after `/review` approval and CI passes.

## Pre-Deploy Checklist
- [ ] All review blockers resolved
- [ ] CI/CD pipeline green
- [ ] Migrations reviewed and tested on staging
- [ ] Feature flags configured if needed
- [ ] Rollback plan documented
- [ ] On-call engineer notified

## Deployment Steps
1. Merge approved PR to main/production branch
2. Monitor deployment pipeline output
3. Verify key metrics (error rate, latency, logs) for 15 min post-deploy
4. Run smoke tests against production
5. Update deployment log

## Post-Deploy
- Close related tickets
- Update SYSTEM-MAP if architecture changed
- Document any incidents or surprises in `/retro`

## Rollback Trigger
If error rate spikes >2x baseline or critical path broken → rollback immediately, then diagnose.

## Exit Criteria
Deployment stable, metrics normal, tickets closed.
