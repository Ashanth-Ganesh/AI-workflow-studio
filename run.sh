#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
OS_NAME="$(uname -s)"
DETACH=false
NO_BUILD=false
DOCKER_TIMEOUT=120
APPLICATION_TIMEOUT=120
FOLLOWING_LOGS=false

usage() {
  printf 'Usage: bash run.sh [--detach] [--no-build] [--docker-timeout SECONDS] [--application-timeout SECONDS]\n'
}

fail() {
  printf '[ERROR] %s\n' "$1" >&2
  exit 1
}

require_timeout() {
  local value="$1" minimum="$2" name="$3"
  [[ "$value" =~ ^[0-9]+$ ]] && (( value >= minimum && value <= 300 )) ||
    fail "$name must be between $minimum and 300 seconds."
}

while (( $# > 0 )); do
  case "$1" in
    --detach) DETACH=true; shift ;;
    --no-build) NO_BUILD=true; shift ;;
    --docker-timeout)
      (( $# >= 2 )) || fail '--docker-timeout needs a number of seconds.'
      DOCKER_TIMEOUT="$2"; shift 2 ;;
    --application-timeout)
      (( $# >= 2 )) || fail '--application-timeout needs a number of seconds.'
      APPLICATION_TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; fail "Unknown option: $1" ;;
  esac
done

case "$OS_NAME" in
  Darwin|Linux) ;;
  *) fail 'This script supports macOS and Linux. On Windows, run .\run.ps1.' ;;
esac
require_timeout "$DOCKER_TIMEOUT" 10 'Docker timeout'
require_timeout "$APPLICATION_TIMEOUT" 30 'Application timeout'

read_env_value() {
  local requested_key="$1" line value
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*${requested_key}[[:space:]]*=(.*)$ ]]; then
      value="${BASH_REMATCH[1]}"
      value="${value%$'\r'}"
      value="${value#"${value%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"
      printf '%s' "$value"
      return 0
    fi
  done < "$PROJECT_ROOT/.env"
  return 0
}

assert_local_configuration() {
  [[ -f "$PROJECT_ROOT/.env" ]] ||
    fail 'Missing .env. Run bash setup.sh, add OAuth credentials, then rerun bash run.sh.'

  local session_secret
  session_secret="$(read_env_value SESSION_SECRET)"
  [[ -n "$session_secret" && "$session_secret" != replace-with-* && ${#session_secret} -ge 32 ]] ||
    fail 'SESSION_SECRET is missing, shorter than 32 characters, or still uses the example value. Run bash setup.sh or set a unique value in .env.'
}

assert_docker_compose_capability() {
  local compose_version up_help
  compose_version="$(docker compose version --short 2>/dev/null || true)"
  [[ -n "$compose_version" ]] || fail 'Docker Compose v2 was not found. Install or update Docker with the Compose plugin.'
  up_help="$(docker compose up --help 2>/dev/null || true)"
  grep -Eq '^[[:space:]]*--wait([[:space:]]|$)' <<< "$up_help" ||
    fail "Docker Compose $compose_version does not support 'docker compose up --wait'. Update Docker Compose."
  printf 'Docker Compose %s is compatible.\n' "$compose_version"
}

docker_engine_ready() {
  docker version --format '{{.Server.Version}}' >/dev/null 2>&1
}

start_docker_engine() {
  if docker_engine_ready; then
    return 0
  fi

  if [[ "$OS_NAME" != Darwin ]]; then
    fail 'Docker Engine is unavailable or this user lacks socket access. Start Docker; if you just joined the docker group, log out and back in before rerunning bash run.sh.'
  fi

  printf 'Starting Docker Desktop...\n'
  if ! docker desktop start --detach >/dev/null 2>&1; then
    open -a Docker >/dev/null 2>&1 ||
      fail 'Docker Desktop could not be started. Install it or open it manually, then rerun bash run.sh.'
  fi

  local deadline=$(( $(date +%s) + DOCKER_TIMEOUT ))
  while (( $(date +%s) < deadline )); do
    if docker_engine_ready; then
      printf 'Docker Engine is ready.\n'
      return 0
    fi
    sleep 2
  done
  fail "Docker Engine was not ready within $DOCKER_TIMEOUT seconds. Check Docker Desktop for an error or first-run prompt."
}

port_listener() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | sed -n '2p' || true
  elif command -v ss >/dev/null 2>&1; then
    ss -ltnH 2>/dev/null | grep -E "(^|[[:space:]])[^[:space:]]*:$port[[:space:]]" | sed -n '1p' || true
  else
    printf '[WARN] Neither lsof nor ss is installed; skipping local port preflight.\n' >&2
  fi
}

assert_local_ports_available() {
  local running_services service port owner
  running_services="$(docker compose ps --status running --services 2>/dev/null || true)"
  for service in web api db; do
    case "$service" in
      web) port=5173 ;;
      api) port=8000 ;;
      db) port=5432 ;;
    esac
    if printf '%s\n' "$running_services" | grep -Fxq "$service"; then
      continue
    fi
    owner="$(port_listener "$port")"
    [[ -z "$owner" ]] || fail "Port $port is already in use ($owner). Stop that process or container before starting the $service service."
  done
}

wait_for_http_endpoint() {
  local url="$1" name="$2" service="$3" attempt
  for (( attempt=0; attempt<20; attempt++ )); do
    if curl --silent --show-error --fail --max-time 3 --output /dev/null "$url" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  WARNINGS+=("$name did not respond at $url. Check 'docker compose logs $service'.")
  WARNINGS_COUNT=$((WARNINGS_COUNT + 1))
}

show_startup_message() {
  local warning
  printf '\n'
  if (( WARNINGS_COUNT == 0 )); then
    printf '\033[32m[OK] AI Workflow Studio started successfully!\033[0m\n'
  else
    printf '\033[33m[WARN] AI Workflow Studio started with %s warning(s).\033[0m\n' "$WARNINGS_COUNT"
    for warning in "${WARNINGS[@]}"; do
      printf '\033[33m   - %s\033[0m\n' "$warning"
    done
  fi
  printf '\033[32m   Web app:  http://localhost:5173\033[0m\n'
  printf '\033[32m   API docs: http://localhost:8000/api/docs\033[0m\n\n'
}

cleanup() {
  if [[ "$FOLLOWING_LOGS" == true ]]; then
    printf '\nStopping application services...\n'
    docker compose stop >/dev/null || true
  fi
}

cd -- "$PROJECT_ROOT"
command -v docker >/dev/null 2>&1 || fail 'Docker CLI was not found. Install Docker, then reopen your terminal.'
command -v curl >/dev/null 2>&1 || fail 'curl is required for local health checks.'
assert_local_configuration
assert_docker_compose_capability
start_docker_engine
assert_local_ports_available

compose_args=(up --wait --wait-timeout "$APPLICATION_TIMEOUT")
if [[ "$NO_BUILD" != true ]]; then
  compose_args+=(--build)
fi
docker compose "${compose_args[@]}"

WARNINGS=()
WARNINGS_COUNT=0
wait_for_http_endpoint 'http://localhost:5173' 'Web app' web
wait_for_http_endpoint 'http://localhost:8000/api/v1/health/ready' API api

if [[ "$DETACH" != true ]]; then
  printf '\nStartup logs:\n'
  docker compose logs --tail 50
fi
show_startup_message

if [[ "$DETACH" != true ]]; then
  printf 'Following logs. Press Ctrl+C to stop the application services.\n'
  FOLLOWING_LOGS=true
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap cleanup EXIT
  docker compose logs --follow --tail 0
fi
