#!/usr/bin/env bash
# approve-production.sh
# Deployment Approval Simulation - implemented as a deployment approval
# FILE (approvals/<version>.approved), which deploy.sh checks before any
# Production deployment. Can be used interactively (manual confirmation)
# or non-interactively for CI (--approve / --reject flags).
#
# Usage:
#   ./scripts/approve-production.sh <version>                # interactive prompt
#   ./scripts/approve-production.sh <version> --approve       # non-interactive approve
#   ./scripts/approve-production.sh <version> --reject        # non-interactive reject / revoke

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
log_init "approve-production"

VERSION="${1:?Usage: approve-production.sh <version> [--approve|--reject]}"
MODE="${2:-}"
APPROVAL_FILE="${APPROVALS_DIR}/${VERSION}.approved"

do_approve() {
  echo "approved_by=$(whoami) at $(date -u +'%Y-%m-%dT%H:%M:%SZ')" > "$APPROVAL_FILE"
  log_ok "Version ${VERSION} APPROVED for production. Approval file: ${APPROVAL_FILE}"
  echo -e "${C_GREEN}${C_BOLD}APPROVED${C_RESET} - version ${VERSION} may now be deployed to production."
}

do_reject() {
  rm -f "$APPROVAL_FILE"
  log_warn "Version ${VERSION} REJECTED / approval revoked for production."
  echo -e "${C_YELLOW}${C_BOLD}REJECTED${C_RESET} - version ${VERSION} will NOT be deployed to production."
}

case "$MODE" in
  --approve)
    do_approve
    exit 0
    ;;
  --reject)
    do_reject
    exit 1
    ;;
  "")
    echo -e "${C_BOLD}Production Deployment Approval${C_RESET}"
    echo "Version to approve: ${VERSION}"
    read -r -p "Approve this version for production deployment? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      do_approve
      exit 0
    else
      do_reject
      exit 1
    fi
    ;;
  *)
    echo "Usage: $0 <version> [--approve|--reject]"
    exit 1
    ;;
esac
