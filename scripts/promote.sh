#!/usr/bin/env bash
# promote.sh
# Deployment Promotion System - promotes the SAME application version from
# one environment to the next (Development -> Staging -> Production),
# rather than deploying a fresh/different build to each. Verifies the
# source environment is actually running that version and is healthy
# before promoting it onward.
#
# Usage:
#   ./scripts/promote.sh <version> <from-env> <to-env>
# Example:
#   ./scripts/promote.sh 1.2.0 development staging
#   ./scripts/promote.sh 1.2.0 staging production

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
log_init "promote"

VERSION="${1:?Usage: promote.sh <version> <from-env> <to-env>}"
FROM_ENV="${2:?Usage: promote.sh <version> <from-env> <to-env>}"
TO_ENV="${3:?Usage: promote.sh <version> <from-env> <to-env>}"

for e in "$FROM_ENV" "$TO_ENV"; do
  if ! is_valid_env "$e"; then
    log_error "Invalid environment '${e}'. Must be one of: ${VALID_ENVS}"
    exit 1
  fi
done

log_step "Verifying ${FROM_ENV} is running version ${VERSION} and is healthy"
CURRENT_JSON="$($VERSION_STORE current "$FROM_ENV")"
CURRENT_VERSION="$(echo "$CURRENT_JSON" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).version)}catch(e){console.log('')}})")"
CURRENT_BUILD="$(echo "$CURRENT_JSON" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).build)}catch(e){console.log(0)}})")"

if [ "$CURRENT_VERSION" != "$VERSION" ]; then
  log_error "${FROM_ENV} is currently running version '${CURRENT_VERSION}', not '${VERSION}'. Cannot promote a version that isn't deployed there."
  exit 1
fi

HEALTH_URL="$(health_url_for "$FROM_ENV")"
if RESP="$(wait_for_health "$HEALTH_URL" 3 1)"; then
  log_ok "${FROM_ENV} confirmed healthy on version ${VERSION}: ${RESP}"
else
  log_error "${FROM_ENV} is not currently healthy. Fix it before promoting from it."
  exit 1
fi

log_step "Promoting version ${VERSION} (build ${CURRENT_BUILD}): ${FROM_ENV} -> ${TO_ENV}"
if "${SCRIPT_DIR}/deploy.sh" "$TO_ENV" "$VERSION" "$CURRENT_BUILD"; then
  echo ""
  echo -e "${C_GREEN}${C_BOLD}PROMOTION SUCCESSFUL${C_RESET}: ${VERSION} moved from ${FROM_ENV} to ${TO_ENV}"
  exit 0
else
  echo ""
  echo -e "${C_RED}${C_BOLD}PROMOTION FAILED${C_RESET}: deployment to ${TO_ENV} did not succeed"
  exit 1
fi
