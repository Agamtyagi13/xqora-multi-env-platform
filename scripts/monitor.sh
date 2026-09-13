#!/usr/bin/env bash
# monitor.sh
# Deployment Monitoring and Logging - tracks application status, container
# status, current application version, deployment success/failure, CPU and
# memory usage, and health-check results. Writes to that environment's own
# log directory, so each environment maintains individual logs.
#
# Usage:
#   ./scripts/monitor.sh <environment>

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

ENVIRONMENT="${1:?Usage: monitor.sh <environment>}"
if ! is_valid_env "$ENVIRONMENT"; then
  echo "Invalid environment '${ENVIRONMENT}'. Must be one of: ${VALID_ENVS}"
  exit 1
fi
log_init "monitor" "$ENVIRONMENT"

CONTAINER_NAME="xqora-app-${ENVIRONMENT}"
HEALTH_URL="$(health_url_for "$ENVIRONMENT")"
REPORT_FILE="${LOG_DIR}/${ENVIRONMENT}/monitor-${RUN_ID}.txt"

log_step "Checking application status"
HEALTH_RESP="$(curl -fsS "$HEALTH_URL" 2>/dev/null || echo 'UNREACHABLE')"
log_info "Health: ${HEALTH_RESP}"

log_step "Checking container status"
CONTAINER_STATUS="$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo 'missing')"
CONTAINER_HEALTH="$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo 'n/a')"
log_info "Container: ${CONTAINER_STATUS} (healthcheck: ${CONTAINER_HEALTH})"

log_step "Checking current application version"
CURRENT_JSON="$($VERSION_STORE current "$ENVIRONMENT")"
log_info "Version manifest record: ${CURRENT_JSON}"

log_step "Checking CPU and memory usage"
STATS="$(docker stats --no-stream --format '{{.CPUPerc}} CPU | {{.MemUsage}}' "$CONTAINER_NAME" 2>/dev/null || echo 'unavailable')"
log_info "Resource usage: ${STATS}"

{
  echo "XQORA Deployment Monitoring Snapshot [${ENVIRONMENT}]"
  echo "========================================================"
  echo "Date/Time (UTC):        $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo ""
  echo "Application status:     ${HEALTH_RESP}"
  echo "Container status:       ${CONTAINER_STATUS} (healthcheck: ${CONTAINER_HEALTH})"
  echo "Current version record: ${CURRENT_JSON}"
  echo "CPU / memory usage:     ${STATS}"
} | tee "$REPORT_FILE" >> "$CURRENT_LOG_FILE"

echo ""
echo -e "${C_GREEN}Monitoring snapshot for [${ENVIRONMENT}] saved to:${C_RESET} ${REPORT_FILE}"
