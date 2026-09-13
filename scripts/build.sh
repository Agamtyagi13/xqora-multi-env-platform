#!/usr/bin/env bash
# build.sh
# Pipeline stages 1-4 (spec: code validation, application testing, docker
# image build, image tagging - reordered slightly here since testing an
# image requires it to exist first):
#   1. Code validation      (node -c server.js)
#   2. Docker image build
#   3. Image tagging with version numbers
#   4. Application testing  (delegates to test-app.sh, runs the built image)
#
# Usage:
#   ./scripts/build.sh <version> [build_number]
# If build_number is omitted, it auto-increments from the version manifest.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
log_init "build"

VERSION="${1:?Usage: build.sh <version> [build_number]}"
BUILD_NUMBER="${2:-}"

if [ -z "$BUILD_NUMBER" ]; then
  TOTAL_BUILDS="$($VERSION_STORE all | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).length)}catch(e){console.log(0)}})")"
  BUILD_NUMBER=$((TOTAL_BUILDS + 1))
  log_info "Auto-assigned build number: ${BUILD_NUMBER}"
fi

log_step "1/4  Validating application code"
if ! command_exists node; then
  log_error "node is required to validate application code"
  exit 1
fi
if node -c "${APP_DIR}/server.js" 2>>"$CURRENT_LOG_FILE"; then
  log_ok "server.js passed syntax validation"
else
  log_error "Code validation FAILED - server.js has a syntax error. Aborting build."
  exit 1
fi

log_step "2/4  Building the Docker image"
if ! command_exists docker; then
  log_error "docker is required to build the image"
  exit 1
fi
if docker build -t "xqora-multi-env-app:${VERSION}" \
    --build-arg "APP_VERSION=${VERSION}" \
    "$APP_DIR" >>"$CURRENT_LOG_FILE" 2>&1; then
  log_ok "Built image xqora-multi-env-app:${VERSION}"
else
  log_error "Docker image build FAILED. See ${CURRENT_LOG_FILE}. Aborting."
  exit 1
fi

log_step "3/4  Tagging image with version and build numbers"
docker tag "xqora-multi-env-app:${VERSION}" "xqora-multi-env-app:build-${BUILD_NUMBER}" >>"$CURRENT_LOG_FILE" 2>&1
log_ok "Tagged as xqora-multi-env-app:${VERSION} and :build-${BUILD_NUMBER}"

log_step "4/4  Running application tests"
if "${SCRIPT_DIR}/test-app.sh" "$VERSION"; then
  log_ok "Application testing passed"
else
  log_error "Application testing FAILED. Image is built but must not be deployed. Aborting."
  exit 1
fi

echo ""
echo -e "${C_GREEN}${C_BOLD}BUILD SUCCESSFUL${C_RESET}"
echo -e "  Image:  xqora-multi-env-app:${VERSION}"
echo -e "  Build#: ${BUILD_NUMBER}"
echo "${BUILD_NUMBER}" > "${VERSIONS_DIR}/.last-build-number-${VERSION}"
exit 0
