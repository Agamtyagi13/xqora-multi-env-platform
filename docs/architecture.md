# Architecture & Workflow

## 1. Overview

One application, one Docker image per version, deployed identically across
three isolated environments — Development, Staging, and Production — with
a promotion system that moves a *specific, already-tested version* forward
rather than redeploying fresh code at each stage, a mandatory approval gate
before Production, automated rollback, and per-environment monitoring.

```
                    ┌─────────────┐
                    │   build.sh   │  validate → build image → tag → test
                    └──────┬──────┘
                           │ xqora-multi-env-app:<version>
                           ▼
   ┌───────────────────────────────────────────────────────────┐
   │                     pipeline.sh                            │
   │                                                             │
   │   deploy.sh development ──► monitor/validate ──►┐          │
   │                                                   │          │
   │                              promote.sh           ▼          │
   │                          (dev → staging)   deploy.sh staging │
   │                                                   │          │
   │                                        monitor/validate       │
   │                                                   │          │
   │                                    approve-production.sh     │
   │                                    (BLOCKS without approval) │
   │                                                   │          │
   │                              promote.sh            ▼          │
   │                        (staging → production)  deploy.sh production
   └───────────────────────────────────────────────────────────┘
```

## 2. Environment isolation

All three environments run from the **same** `docker-compose.yml` template.
Isolation comes from `environments/<env>/.env`, which supplies a distinct:

| | Development | Staging | Production |
|---|---|---|---|
| Port | 3001 | 3002 | 3003 |
| Container | `xqora-app-development` | `xqora-app-staging` | `xqora-app-production` |
| Network | `xqora-net-development` | `xqora-net-staging` | `xqora-net-production` |
| Compose project | `xqora-development` | `xqora-staging` | `xqora-production` |
| Log level | debug | info | warn |

Because each environment has its own compose project name, all three can
run **simultaneously** on one machine without colliding — exactly as the
spec's example dashboard shows (Dev and Staging already on 1.2.0 while
Production is still catching up on 1.1.0).

## 3. Version management

`versions/versions.json` is the single source of truth. Every deploy,
success or failure, appends a record:

```json
{ "environment": "production", "version": "1.2.0", "build": 3,
  "status": "success", "timestamp": "...", "note": "..." }
```

`scripts/lib/version-store.js` provides the query logic used throughout:
`current(env)` for "what's live right now", and `previous-stable(env)` for
"what should we roll back to" (the most recent successful/rolled-back
record whose version differs from the current one — so a repeated bad
deploy doesn't roll back to itself).

## 4. Promotion vs. fresh deployment

`deploy.sh` deploys *a* version to *an* environment. `promote.sh` is
stricter: it first confirms the **source** environment is actually running
the version being promoted and is currently healthy, then calls `deploy.sh`
with that exact version and build number — guaranteeing the artifact that
reaches Production is byte-for-byte the one that was validated in Staging,
not a fresh rebuild.

## 5. Production approval gate

Implemented as a **deployment approval file**: `approvals/<version>.approved`.
`deploy.sh` refuses any Production deployment (`exit 1`, no container
touched) unless that file exists. `approve-production.sh` creates it —
either interactively (prompts y/N) or non-interactively (`--approve` /
`--reject`, for CI use). `pipeline.sh` checks for this same file and pauses
with clear instructions if it's missing, rather than deploying anyway.

## 6. Automated rollback

```
rollback.sh <env> [--simulate-failure]
  1. (optional) force-kill the current container to manufacture a failure
  2. detect current health/container state
  3. stop the failed container
  4. look up previous-stable(env) from the version manifest
  5. redeploy that exact version+build via deploy.sh ... --rollback
     (records status "rolled_back", not "success", for audit clarity)
  6. health-check the restored version
  7. write a full rollback report to logs/<env>/rollback-report-*.txt
```

## 7. Monitoring & logging

`monitor.sh <env>` captures application status (`/health`), container
status (`docker inspect`), the current version-manifest record, and
CPU/memory (`docker stats`) — writing to `logs/<env>/`, so each
environment's history stays separate, as required.

## 8. CI/CD

Two equivalent implementations:
- **`scripts/pipeline.sh`** — locally runnable, used for the actual
  demonstration video: build → test → deploy dev → validate → deploy
  staging → validate → approval gate → deploy production.
- **`.github/workflows/ci-cd.yml`** — the same stages as GitHub Actions
  jobs, using `needs:` so a failure in any job stops all downstream jobs.
  The Production job uses a GitHub **Environment** with required
  reviewers, which is GitHub's native equivalent of the approval-file gate.

## 9. Dashboard

`dashboard.sh` reads the version manifest and renders both a terminal
table and `dashboard.html` (open in any browser) showing Environment /
Version / Build / Status / Last Deployment for all three environments at a
glance — the same shape as the spec's example table.
