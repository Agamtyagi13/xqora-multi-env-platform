#!/usr/bin/env bash
# pipeline.sh
# Automated CI/CD Pipeline - runs, in order:
#   1. Code validation           (build.sh)
#   2. Application testing       (build.sh -> test-app.sh)
#   3. Docker image build        (build.sh)
#   4. Image tagging             (build.sh)
#   5. Deployment to Development (deploy.sh)
#   6. Validation and health checks (monitor.sh)
#   7. Deployment to Staging     (deploy.sh)
#   8. Production approval gate  (checks approvals/<version>.approved)
#   9. Final deployment to Production (deploy.sh)
#
# The pipeline stops immediately - with no further deployment - if any
# validation, build, test, or health-check stage fails.
#
# Usage:
#   ./scripts/pipeline.sh <version>

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
log_init "pipeline"

VERSION="${1:?Usage: pipeline.sh <version>}"

abort() {
  log_error "$1"
  echo -e "${C_RED}${C_BOLD}PIPELINE ABORTED${C_RESET} - ${1}"
  exit 1
}

log_step "STAGE 1-4/9  Build: code validation, image build, tagging, application testing"
if ! "${SCRIPT_DIR}/build.sh" "$VERSION"; then
  abort "Build stage failed. No deployment was attempted."
fi
BUILD_NUMBER="$(cat "${VERSIONS_DIR}/.last-build-number-${VERSION}" 2>/dev/null || echo 1)"

log_step "STAGE 5/9  Deploy to Development"
if ! "${SCRIPT_DIR}/deploy.sh" development "$VERSION" "$BUILD_NUMBER"; then
  abort "Deployment to Development failed. Pipeline stopped - Staging and Production were never touched."
fi

log_step "STAGE 6/9  Validation and health checks (Development)"
"${SCRIPT_DIR}/monitor.sh" development >>"$CURRENT_LOG_FILE" 2>&1
if ! curl -fsS "$(health_url_for development)" 2>/dev/null | grep -q '"status":"UP"\|"status": "UP"'; then
  abort "Development failed post-deploy validation. Pipeline stopped."
fi
log_ok "Development validated healthy"

log_step "STAGE 7/9  Deploy to Staging"
if ! "${SCRIPT_DIR}/deploy.sh" staging "$VERSION" "$BUILD_NUMBER"; then
  abort "Deployment to Staging failed. Pipeline stopped - Production was never touched."
fi
"${SCRIPT_DIR}/monitor.sh" staging >>"$CURRENT_LOG_FILE" 2>&1
if ! curl -fsS "$(health_url_for staging)" 2>/dev/null | grep -q '"status":"UP"\|"status": "UP"'; then
  abort "Staging failed post-deploy validation. Pipeline stopped."
fi
log_ok "Staging validated healthy"

log_step "STAGE 8/9  Production approval gate"
APPROVAL_FILE="${APPROVALS_DIR}/${VERSION}.approved"
if [ ! -f "$APPROVAL_FILE" ]; then
  log_warn "No production approval found for version ${VERSION}."
  echo ""
  echo -e "${C_YELLOW}${C_BOLD}PIPELINE PAUSED - AWAITING PRODUCTION APPROVAL${C_RESET}"
  echo -e "  Development: deployed and healthy"
  echo -e "  Staging:     deployed and healthy"
  echo -e "  Production:  BLOCKED - not yet approved"
  echo ""
  echo -e "  Run: ${C_BOLD}./scripts/approve-production.sh ${VERSION} --approve${C_RESET}"
  echo -e "  Then re-run: ${C_BOLD}./scripts/pipeline.sh ${VERSION}${C_RESET} to complete the production deployment."
  exit 1
fi
log_ok "Production approval found: $(cat "$APPROVAL_FILE")"

log_step "STAGE 9/9  Final deployment to Production"
if ! "${SCRIPT_DIR}/deploy.sh" production "$VERSION" "$BUILD_NUMBER"; then
  abort "Deployment to Production failed."
fi

"${SCRIPT_DIR}/dashboard.sh"

echo ""
echo -e "${C_GREEN}${C_BOLD}CI/CD PIPELINE SUCCESSFUL${C_RESET} - version ${VERSION} is live in Development, Staging, and Production."
exit 0
