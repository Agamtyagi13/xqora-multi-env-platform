#!/usr/bin/env bash
# test-app.sh
# "Application testing" pipeline stage - runs the freshly built image
# standalone on a throwaway port, confirms /health responds UP, then tears
# it down. This is deliberately separate from deploying to an environment,
# since a build that never even boots shouldn't reach Development at all.
#
# Usage: ./scripts/test-app.sh <version>

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
log_init "test-app"

VERSION="${1:?Usage: test-app.sh <version>}"
TEST_PORT=9999
TEST_CONTAINER="xqora-test-${VERSION}-${RUN_ID}"

cleanup() {
  docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

log_step "Running smoke test for xqora-multi-env-app:${VERSION}"
if ! docker run -d --rm --name "$TEST_CONTAINER" -p "${TEST_PORT}:3000" \
    -e APP_VERSION="$VERSION" -e ENVIRONMENT=test \
    "xqora-multi-env-app:${VERSION}" >>"$CURRENT_LOG_FILE" 2>&1; then
  log_error "Failed to start test container from image xqora-multi-env-app:${VERSION}"
  exit 1
fi

if wait_for_health "http://localhost:${TEST_PORT}/health" 10 1 >>"$CURRENT_LOG_FILE" 2>&1; then
  log_ok "Application testing passed - /health responded UP"
  exit 0
else
  log_error "Application testing FAILED - /health never responded UP"
  exit 1
fi
