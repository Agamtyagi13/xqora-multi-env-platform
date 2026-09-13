#!/usr/bin/env bash
# rollback.sh
# Automated Rollback System:
#   1. Detect or simulate a failed deployment
#   2. Stop the failed version
#   3. Restore the previous working version
#   4. Restart the application
#   5. Perform health checks
#   6. Generate rollback logs
#
# Usage:
#   ./scripts/rollback.sh <environment> [--simulate-failure]
#
# --simulate-failure forcibly kills the current container first, so the
# rollback path can be demonstrated on demand rather than waiting for a
# real bad deploy.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

ENVIRONMENT="${1:?Usage: rollback.sh <environment> [--simulate-failure]}"
SIMULATE="${2:-}"

log_init "rollback" "$ENVIRONMENT"

if ! is_valid_env "$ENVIRONMENT"; then
  log_error "Invalid environment '${ENVIRONMENT}'. Must be one of: ${VALID_ENVS}"
  exit 1
fi

REPORT_FILE="${LOG_DIR}/${ENVIRONMENT}/rollback-report-${RUN_ID}.txt"
CONTAINER_NAME="xqora-app-${ENVIRONMENT}"
HEALTH_URL="$(health_url_for "$ENVIRONMENT")"

if [ "$SIMULATE" = "--simulate-failure" ]; then
  log_step "1/6  Simulating a failed deployment (force-killing current container)"
  docker kill "$CONTAINER_NAME" >>"$CURRENT_LOG_FILE" 2>&1 || log_warn "Container was not running"
  CURRENT_JSON="$($VERSION_STORE current "$ENVIRONMENT")"
  BAD_VERSION="$(echo "$CURRENT_JSON" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).version)}catch(e){console.log('unknown')}})")"
  $VERSION_STORE record "$ENVIRONMENT" "$BAD_VERSION" 0 "failed" "simulated failure via rollback.sh --simulate-failure" >>"$CURRENT_LOG_FILE" 2>&1
  log_warn "Simulated failure of version ${BAD_VERSION}"
else
  log_step "1/6  Detecting failed deployment"
fi

FAILED_HEALTH="$(curl -fsS "$HEALTH_URL" 2>/dev/null || echo 'unreachable')"
FAILED_CONTAINER_STATE="$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo 'missing')"
log_info "Detected state: health=${FAILED_HEALTH}, container=${FAILED_CONTAINER_STATE}"

if echo "$FAILED_HEALTH" | grep -q '"status":"UP"\|"status": "UP"'; then
  log_warn "Current deployment appears healthy. Proceeding anyway since rollback was explicitly requested."
fi

log_step "2/6  Stopping the failed version"
docker stop "$CONTAINER_NAME" >>"$CURRENT_LOG_FILE" 2>&1 || log_warn "Container was already stopped"
log_ok "Stopped ${CONTAINER_NAME}"

log_step "3/6  Restoring the previous working version"
PREV_JSON="$($VERSION_STORE previous-stable "$ENVIRONMENT")"
if [ "$PREV_JSON" = "null" ]; then
  log_error "No previous stable version found for ${ENVIRONMENT}. Cannot roll back."
  {
    echo "XQORA Rollback Report [${ENVIRONMENT}]"
    echo "========================================"
    echo "Date/Time (UTC): $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo "Result:          FAILED - no previous stable version available"
  } | tee "$REPORT_FILE" >> "$CURRENT_LOG_FILE"
  exit 1
fi
PREV_VERSION="$(echo "$PREV_JSON" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).version)})")"
PREV_BUILD="$(echo "$PREV_JSON" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).build)})")"
log_ok "Previous stable version found: ${PREV_VERSION} (build ${PREV_BUILD})"

log_step "4/6  Restarting the application on the previous stable version"
if "${SCRIPT_DIR}/deploy.sh" "$ENVIRONMENT" "$PREV_VERSION" "$PREV_BUILD" --rollback; then
  log_ok "Redeployed ${PREV_VERSION} to ${ENVIRONMENT}"
else
  log_error "Failed to redeploy previous version ${PREV_VERSION}"
  {
    echo "XQORA Rollback Report [${ENVIRONMENT}]"
    echo "========================================"
    echo "Date/Time (UTC):   $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo "Attempted restore: ${PREV_VERSION}"
    echo "Result:            FAILED - redeploy of previous version did not succeed"
  } | tee "$REPORT_FILE" >> "$CURRENT_LOG_FILE"
  exit 1
fi

log_step "5/6  Performing post-rollback health checks"
if RESP="$(wait_for_health "$HEALTH_URL" 10 2)"; then
  log_ok "Post-rollback health check passed: ${RESP}"
  ROLLBACK_HEALTHY=1
else
  log_error "Post-rollback health check FAILED: ${RESP:-no response}"
  ROLLBACK_HEALTHY=0
fi

log_step "6/6  Generating rollback logs"
RESULT_TEXT="SUCCESS"
[ "$ROLLBACK_HEALTHY" -eq 1 ] || RESULT_TEXT="COMPLETED BUT UNHEALTHY"
{
  echo "XQORA Rollback Report [${ENVIRONMENT}]"
  echo "========================================"
  echo "Date/Time (UTC):       $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "Detected failure:      health=${FAILED_HEALTH}, container=${FAILED_CONTAINER_STATE}"
  echo "Restored version:      ${PREV_VERSION} (build ${PREV_BUILD})"
  echo "Post-rollback health:  $( [ "$ROLLBACK_HEALTHY" -eq 1 ] && echo UP || echo DOWN )"
  echo "Result:                ${RESULT_TEXT}"
  echo "Full log:              ${CURRENT_LOG_FILE}"
} | tee "$REPORT_FILE" >> "$CURRENT_LOG_FILE"

echo ""
if [ "$ROLLBACK_HEALTHY" -eq 1 ]; then
  echo -e "${C_GREEN}${C_BOLD}ROLLBACK SUCCESSFUL${C_RESET} [${ENVIRONMENT}] - restored to version ${PREV_VERSION}"
  exit 0
else
  echo -e "${C_RED}${C_BOLD}ROLLBACK COMPLETED BUT APPLICATION IS UNHEALTHY${C_RESET}"
  exit 1
fi
