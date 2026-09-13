#!/usr/bin/env bash
# common.sh - shared helpers sourced by every script in this project.
# Not meant to be executed directly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/logs"
ENVIRONMENTS_DIR="${PROJECT_ROOT}/environments"
APPROVALS_DIR="${PROJECT_ROOT}/approvals"
VERSIONS_DIR="${PROJECT_ROOT}/versions"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"
APP_DIR="${PROJECT_ROOT}/app"
VERSION_STORE="node ${SCRIPT_DIR}/lib/version-store.js"
VALID_ENVS="development staging production"

mkdir -p "$LOG_DIR/development" "$LOG_DIR/staging" "$LOG_DIR/production" "$APPROVALS_DIR" "$VERSIONS_DIR"

# ---- Colors ----
if [ -t 1 ]; then
  C_RED='\033[0;31m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'
  C_BLUE='\033[0;34m'; C_BOLD='\033[1m'; C_RESET='\033[0m'
else
  C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_BOLD=''; C_RESET=''
fi

RUN_ID="$(date +'%Y%m%d-%H%M%S')"
CURRENT_LOG_FILE="${LOG_DIR}/run-${RUN_ID}.log"

# log_init <script_name> [environment]
# If an environment is given, the log is written under logs/<env>/ so each
# environment maintains its own individual logs, per the spec.
log_init() {
  local script_name="$1" env="${2:-}"
  if [ -n "$env" ]; then
    CURRENT_LOG_FILE="${LOG_DIR}/${env}/${script_name}-${RUN_ID}.log"
  else
    CURRENT_LOG_FILE="${LOG_DIR}/${script_name}-${RUN_ID}.log"
  fi
  mkdir -p "$(dirname "$CURRENT_LOG_FILE")"
  touch "$CURRENT_LOG_FILE"
  echo "===== ${script_name} started at $(date -u +'%Y-%m-%dT%H:%M:%SZ') =====" >> "$CURRENT_LOG_FILE"
}

_log() {
  local level="$1"; shift
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [${level}] $*" >> "$CURRENT_LOG_FILE"
}
log_info()  { _log "INFO"  "$*"; echo -e "${C_BLUE}[INFO]${C_RESET}  $*"; }
log_ok()    { _log "OK"    "$*"; echo -e "${C_GREEN}[ OK ]${C_RESET}  $*"; }
log_warn()  { _log "WARN"  "$*"; echo -e "${C_YELLOW}[WARN]${C_RESET}  $*"; }
log_error() { _log "ERROR" "$*"; echo -e "${C_RED}[FAIL]${C_RESET}  $*" >&2; }
log_step()  { _log "STEP"  "$*"; echo -e "${C_BOLD}==> $*${C_RESET}"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

require_tool() {
  local tool="$1" hint="$2"
  if command_exists "$tool"; then
    log_ok "Found required tool: ${tool} ($(${tool} --version 2>&1 | head -n1))"
    return 0
  else
    log_error "Missing required tool: ${tool}. ${hint}"
    return 1
  fi
}

docker_compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif command_exists docker-compose; then
    echo "docker-compose"
  else
    echo ""
  fi
}

is_valid_env() {
  local env="$1"
  echo " $VALID_ENVS " | grep -q " $env "
}

env_file_path() { echo "${ENVIRONMENTS_DIR}/$1/.env"; }

# Read a single key from an environment's .env file without polluting the
# calling shell's environment.
env_get() {
  local env="$1" key="$2"
  grep -E "^${key}=" "$(env_file_path "$env")" 2>/dev/null | tail -n1 | cut -d= -f2-
}

health_url_for() {
  local env="$1"
  echo "http://localhost:$(env_get "$env" HOST_PORT)/health"
}

wait_for_health() {
  local url="$1" retries="${2:-10}" delay="${3:-2}"
  local attempt=1
  while [ "$attempt" -le "$retries" ]; do
    RESP="$(curl -fsS "$url" 2>/dev/null || true)"
    if echo "$RESP" | grep -q '"status":"UP"\|"status": "UP"'; then
      echo "$RESP"
      return 0
    fi
    sleep "$delay"
    attempt=$((attempt + 1))
  done
  echo "$RESP"
  return 1
}
