#!/usr/bin/env bash
# setup.sh
# Validates tools, checks all three environment config files exist,
# initializes the version manifest, and prepares per-environment log
# and approval directories.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
log_init "setup"

MISSING=0

log_step "1/5  Checking required tools"
require_tool docker "Install Docker: https://docs.docker.com/get-docker/" || MISSING=1
if [ -n "$(docker_compose_cmd 2>/dev/null)" ]; then
  log_ok "Found Docker Compose ($(docker_compose_cmd))"
else
  log_error "Missing Docker Compose."
  MISSING=1
fi
require_tool node "Install Node.js: https://nodejs.org/" || MISSING=1
if command_exists curl || command_exists wget; then
  log_ok "Found HTTP client (curl/wget)"
else
  log_error "Neither curl nor wget found."
  MISSING=1
fi

log_step "2/5  Validating Docker installation"
if command_exists docker && docker info >/dev/null 2>&1; then
  log_ok "Docker daemon is running and reachable"
else
  log_error "Docker daemon not reachable."
  MISSING=1
fi

log_step "3/5  Checking environment configuration files"
for env in development staging production; do
  f="$(env_file_path "$env")"
  if [ -f "$f" ]; then
    port="$(env_get "$env" HOST_PORT)"
    log_ok "Found ${env} config (port ${port}): ${f}"
  else
    log_error "Missing environment config: ${f}"
    MISSING=1
  fi
done

log_step "4/5  Checking application source and compose files"
for f in "${APP_DIR}/Dockerfile" "${APP_DIR}/server.js" "${APP_DIR}/package.json" "$COMPOSE_FILE"; do
  if [ -f "$f" ]; then
    log_ok "Found $(basename "$f")"
  else
    log_error "Missing required file: $f"
    MISSING=1
  fi
done

log_step "5/5  Initializing version manifest and directories"
$VERSION_STORE init | while IFS= read -r line; do log_info "$line"; done
mkdir -p "$APPROVALS_DIR"
log_ok "Approvals directory ready: ${APPROVALS_DIR}"
for env in development staging production; do
  mkdir -p "${LOG_DIR}/${env}"
  log_ok "Log directory ready: ${LOG_DIR}/${env}"
done

echo ""
if [ "$MISSING" -eq 0 ]; then
  log_ok "Environment initialized and validated."
  echo -e "${C_GREEN}${C_BOLD}ENVIRONMENT READY${C_RESET}"
  exit 0
else
  log_error "One or more requirements are missing. See messages above."
  echo -e "${C_RED}${C_BOLD}ENVIRONMENT NOT READY${C_RESET}"
  exit 1
fi
