# XQORA Multi-Environment Deployment Management System

A complete DevOps system that automates the journey of one application
from Development through Staging to Production — with automated CI/CD,
version tracking, deployment promotion, a mandatory Production approval
gate, automated rollback, and per-environment monitoring.

## 1. What's included

```
xqora-multi-env-platform/
├── app/                          # Demo application (Node.js/Express)
│   ├── server.js                   - Displays version, build, environment
│   ├── package.json
│   ├── public/index.html            - Frontend showing version + env badge
│   └── Dockerfile
├── docker-compose.yml            # One template, parameterized per environment
├── environments/
│   ├── development/.env            - port 3001, debug logging
│   ├── staging/.env                - port 3002, info logging
│   └── production/.env             - port 3003, warn logging
├── scripts/
│   ├── common.sh                    - Shared logging/helper library
│   ├── lib/version-store.js         - Version manifest CRUD (Node, no deps)
│   ├── lib/dashboard-gen.js         - Renders the dashboard table/HTML
│   ├── setup.sh                     - Validate tools & environment configs
│   ├── build.sh                     - Validate code, build image, tag, test
│   ├── test-app.sh                  - Standalone smoke test of a built image
│   ├── deploy.sh                    - Deploy a version to one environment
│   ├── promote.sh                   - Promote a validated version forward
│   ├── approve-production.sh        - Production approval simulation
│   ├── rollback.sh                  - Automated rollback to last stable version
│   ├── monitor.sh                   - Per-environment monitoring & logging
│   ├── dashboard.sh                 - Final deployment dashboard/report
│   └── pipeline.sh                  - Full CI/CD orchestrator
├── .github/workflows/ci-cd.yml   # GitHub Actions equivalent pipeline
├── docs/architecture.md          # Full architecture & workflow explanation
├── versions/versions.json        # Version manifest (created by setup.sh)
├── approvals/                    # Production approval files (created at runtime)
├── logs/{development,staging,production}/  # Individual logs per environment
└── screenshots/                  # Where to put your captured screenshots
```

## 2. Demo application

| Requirement                   | Implementation                                  |
|---------------------------------|--------------------------------------------------|
| Basic frontend interface        | `app/public/index.html` — shows version + env badge live |
| Backend/API service              | `GET /api/info`                                  |
| Health-check endpoint            | `GET /health`                                    |
| Version info on the application  | Both endpoints and the frontend show version, build, and environment |

The **same image** is deployed to all three environments — only
`APP_VERSION`, `BUILD_NUMBER`, and `ENVIRONMENT` differ, injected by
`deploy.sh` at deploy time.

## 3. Prerequisites

- Docker Engine + Docker Compose
- Node.js (for the version-store/dashboard helper scripts)
- `curl` or `wget`

## 4. Quick start

```bash
chmod +x scripts/*.sh
./scripts/setup.sh
```

### Run the full pipeline for a new version
```bash
./scripts/pipeline.sh 1.0.0
```
This builds, tests, deploys to Development, validates, deploys to Staging,
validates, then **stops** and tells you to approve Production:
```bash
./scripts/approve-production.sh 1.0.0 --approve
./scripts/pipeline.sh 1.0.0   # re-run to complete the Production deploy
```

### Or run each stage manually
```bash
./scripts/build.sh 1.0.0
./scripts/deploy.sh development 1.0.0 1
./scripts/promote.sh 1.0.0 development staging
./scripts/approve-production.sh 1.0.0 --approve
./scripts/promote.sh 1.0.0 staging production
```

Check what's running where:
```bash
./scripts/dashboard.sh
open dashboard.html   # or just double-click it
```

## 5. Rollback

Roll back an environment to its last stable version:
```bash
./scripts/rollback.sh development
```

Or demonstrate the full failure → rollback flow on demand:
```bash
./scripts/rollback.sh staging --simulate-failure
```

## 6. Monitoring

```bash
./scripts/monitor.sh development
./scripts/monitor.sh staging
./scripts/monitor.sh production
```
Each writes its own report under `logs/<environment>/`.

## 7. CI/CD

- **Local:** `./scripts/pipeline.sh <version>` — the same sequence as CI,
  runnable without pushing to GitHub.
- **GitHub Actions:** `.github/workflows/ci-cd.yml` — job-per-stage, with
  `needs:` dependencies so a failure stops all downstream deployments, and
  a GitHub Environment (with required reviewers) gating Production.

## 8. 9-Day build plan (for reference)

| Day | Task |
|-----|------|
| 1 | Design architecture and create the demo application |
| 2 | Containerize the application and configure Docker |
| 3 | Set up Development, Staging, and Production environments |
| 4 | Create environment-specific configurations and deployment scripts |
| 5 | Build the CI/CD pipeline |
| 6 | Implement versioning and deployment promotion |
| 7 | Implement Production approval and automated rollback |
| 8 | Configure monitoring, logging, and deployment reporting |
| 9 | Perform complete testing, simulate failure, demonstrate rollback, prepare final documentation |

## 9. Expected deliverables checklist

- [x] Complete source code
- [ ] Git repository link *(push this project and add the link here)*
- [x] Demo application
- [x] Dockerfile and Docker Compose configuration
- [x] Separate Development, Staging, and Production configurations
- [x] CI/CD pipeline configuration (`pipeline.sh` + GitHub Actions)
- [x] Deployment automation scripts (`deploy.sh`, `promote.sh`)
- [x] Version management system (`version-store.js`, `versions.json`)
- [x] Production approval mechanism (`approve-production.sh`)
- [x] Rollback scripts (`rollback.sh`)
- [ ] Monitoring dashboard or screenshots *(run `dashboard.sh` / `monitor.sh`, then screenshot)*
- [ ] Deployment and rollback logs *(generated under `logs/<env>/` once you run the scripts)*
- [x] Complete project documentation (`docs/architecture.md`)
- [x] Architecture diagram (in `docs/architecture.md`)
- [ ] Screenshots showing deployment across all three environments
- [ ] Final demonstration video *(see checklist below)*

### Demonstration video checklist
1. Development → Staging → Production workflow via `pipeline.sh`
2. Approval gate blocking Production, then `approve-production.sh` unblocking it
3. A version visibly displayed differently per environment (dashboard.sh)
4. A failed deployment (e.g. `rollback.sh <env> --simulate-failure`)
5. Automated rollback restoring the previous stable version, with health verification
