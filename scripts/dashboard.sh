#!/usr/bin/env bash
# dashboard.sh
# Final Deployment Dashboard / Report - shows Environment | Version |
# Status | Last Deployment for all three environments, matching the
# spec's example table. Writes both a text report (logs/) and a browsable
# dashboard.html.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
log_init "dashboard"

REPORT_FILE="${LOG_DIR}/dashboard-${RUN_ID}.txt"
HTML_FILE="${PROJECT_ROOT}/dashboard.html"

log_step "Generating deployment dashboard"
{
  echo "XQORA Deployment Dashboard"
  echo "============================"
  echo "Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo ""
  node "${SCRIPT_DIR}/lib/dashboard-gen.js"
} | tee "$REPORT_FILE"

node "${SCRIPT_DIR}/lib/dashboard-gen.js" --html > "$HTML_FILE"
log_ok "Wrote text report to ${REPORT_FILE}"
log_ok "Wrote HTML dashboard to ${HTML_FILE}"

echo ""
echo -e "${C_GREEN}Open ${HTML_FILE} in a browser for a visual dashboard.${C_RESET}"
