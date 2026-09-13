#!/usr/bin/env bash
# deploy.sh
# Deploys a specific application version to a specific environment.
# Enforces the Production approval gate: a Production deployment refuses
# to proceed unless approvals/<version>.approved exists.
#
# Usage:
#   ./scripts/deploy.sh <environment> <version> [build_number] [--rollback]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

ENVIRONMENT="${1:?Usage: deploy.sh <environment> <version> [build_number] [--rollback]}"
VERSION="${2:?Usage: deploy.sh <environment> <version> [build_number] [--rollback]}"
BUILD_NUMBER="${3:-0}"
IS_ROLLBACK=0
[ "${4:-}" = "--rollback" ] && IS_ROLLBACK=1

log_init "deploy" "$ENVIRONMENT"

if ! is_valid_env "$ENVIRONMENT"; then
  log_error "Invalid environment '${ENVIRONMENT}'. Must be one of: ${VALID_ENVS}"
  exit 1
fi

# ---- Production approval gate ----
if [ "$ENVIRONMENT" = "production" ] && [ "$IS_ROLLBACK" -eq 0 ]; then
  APPROVAL_FILE="${APPROVALS_DIR}/${VERSION}.approved"
  if [ ! -f "$APPROVAL_FILE" ]; then
    log_error "Production deployment BLOCKED: no approval found for version ${VERSION}."
    log_error "Run: ./scripts/approve-production.sh ${VERSION} --approve"
    exit 1
  fi
  log_ok "Approval found for version ${VERSION}: $(cat "$APPROVAL_FILE")"
fi

COMPOSE="$(docker_compose_cmd)"
if [ -z "$COMPOSE" ]; then
  log_error "Docker Compose not available."
  exit 1
fi

ENV_FILE="$(env_file_path "$ENVIRONMENT")"
PROJECT_NAME="$(env_get "$ENVIRONMENT" COMPOSE_PROJECT_NAME)"
HOST_PORT="$(env_get "$ENVIRONMENT" HOST_PORT)"

log_step "Deploying xqora-multi-env-app:${VERSION} (build ${BUILD_NUMBER}) to ${ENVIRONMENT}"
export APP_VERSION="$VERSION"
export BUILD_NUMBER="$BUILD_NUMBER"
export ENVIRONMENT="$ENVIRONMENT"

cd "$PROJECT_ROOT" || exit 1
if $COMPOSE -p "$PROJECT_NAME" --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --build >>"$CURRENT_LOG_FILE" 2>&1; then
  log_ok "Container started for ${ENVIRONMENT} on port ${HOST_PORT}"
else
  log_error "docker compose up failed for ${ENVIRONMENT}. See ${CURRENT_LOG_FILE}"
  $VERSION_STORE record "$ENVIRONMENT" "$VERSION" "$BUILD_NUMBER" "failed" "compose up failed" >>"$CURRENT_LOG_FILE" 2>&1
  exit 1
fi

log_step "Running post-deploy health check"
HEALTH_URL="$(health_url_for "$ENVIRONMENT")"
if RESP="$(wait_for_health "$HEALTH_URL" 10 2)"; then
  log_ok "Health check passed: ${RESP}"
  STATUS="success"
  [ "$IS_ROLLBACK" -eq 1 ] && STATUS="rolled_back"
  $VERSION_STORE record "$ENVIRONMENT" "$VERSION" "$BUILD_NUMBER" "$STATUS" "deployed via deploy.sh" | while IFS= read -r line; do log_info "$line"; done
  echo ""
  echo -e "${C_GREEN}${C_BOLD}DEPLOYMENT SUCCESSFUL${C_RESET} [${ENVIRONMENT}]"
  echo -e "  URL:     http://localhost:${HOST_PORT}"
  echo -e "  Version: ${VERSION} (build ${BUILD_NUMBER})"
  exit 0
else
  log_error "Health check FAILED after deploying to ${ENVIRONMENT}: ${RESP:-no response}"
  $VERSION_STORE record "$ENVIRONMENT" "$VERSION" "$BUILD_NUMBER" "failed" "health check failed post-deploy" | while IFS= read -r line; do log_info "$line"; done
  echo ""
  echo -e "${C_RED}${C_BOLD}DEPLOYMENT FAILED${C_RESET} [${ENVIRONMENT}] - health check did not pass"
  echo -e "  Consider running: ./scripts/rollback.sh ${ENVIRONMENT}"
  exit 1
fi
