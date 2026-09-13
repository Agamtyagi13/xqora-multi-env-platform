# What to screenshot

Run these in order on a machine with Docker + Node installed.

1. `./scripts/setup.sh` — `ENVIRONMENT READY`
2. `./scripts/pipeline.sh 1.0.0` — runs through Dev + Staging, then pauses
   asking for Production approval
3. Browser: `http://localhost:3001` (Development) — shows version 1.0.0 badge
4. `./scripts/approve-production.sh 1.0.0 --approve`
5. `./scripts/pipeline.sh 1.0.0` again — completes, deploys to Production
6. Browser: `http://localhost:3002` (Staging) and `http://localhost:3003`
   (Production) — same version, different colored badges
7. `./scripts/dashboard.sh` — terminal table
8. Open `dashboard.html` in a browser — visual dashboard
9. `./scripts/rollback.sh staging --simulate-failure` — full rollback run
10. `curl http://localhost:3002/health` right after — confirms it's back on
    the previous version
11. `cat logs/staging/rollback-report-*.txt` — the rollback log
12. Build and promote a NEW version end to end, to show the promotion
    system moving one exact version forward:
    ```
    ./scripts/build.sh 1.1.0
    ./scripts/deploy.sh development 1.1.0 1
    ./scripts/promote.sh 1.1.0 development staging
    ```
13. `./scripts/dashboard.sh` again — shows Dev/Staging on 1.1.0, Production
    still on 1.0.0 (exactly like the spec's example table)
14. GitHub repo page with README rendered
