#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
OS_NAME="$(uname -s)"
INSTALL_PREREQUISITES=false
INSTALL_DOCKER=false
ENABLE_DOCKER_GROUP=false

usage() {
  printf 'Usage: bash setup.sh [--install-prerequisites] [--install-docker] [--enable-docker-group]\n'
  printf '  --install-prerequisites  Install missing system tools on macOS or Ubuntu/Debian.\n'
  printf '  --install-docker         Install missing Docker on macOS or Ubuntu/Debian.\n'
  printf '  --enable-docker-group    On Linux, grant this user Docker daemon access (root-equivalent).\n'
}

fail() {
  printf '[ERROR] %s\n' "$1" >&2
  exit 1
}

for argument in "$@"; do
  case "$argument" in
    --install-prerequisites) INSTALL_PREREQUISITES=true ;;
    --install-docker) INSTALL_DOCKER=true ;;
    --enable-docker-group) ENABLE_DOCKER_GROUP=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; fail "Unknown option: $argument" ;;
  esac
done

case "$OS_NAME" in
  Darwin|Linux) ;;
  *) fail "This script supports macOS and Linux. On Windows, run .\\setup.ps1." ;;
esac

if [[ "$OS_NAME" == Darwin && "$ENABLE_DOCKER_GROUP" == true ]]; then
  fail '--enable-docker-group applies to Linux only.'
fi

prepare_homebrew_path() {
  local brew_path
  for brew_path in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$brew_path" ]]; then
      eval "$("$brew_path" shellenv)"
      return 0
    fi
  done
}

ensure_homebrew() {
  prepare_homebrew_path
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi
  [[ "$INSTALL_PREREQUISITES" == true || "$INSTALL_DOCKER" == true ]] ||
    fail 'Homebrew is missing. Rerun bash setup.sh --install-prerequisites to install it and the app tools.'
  command -v curl >/dev/null 2>&1 || fail 'curl is required to bootstrap Homebrew.'
  printf 'Installing Homebrew from its official installer (may request your password)...\n'
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /bin/bash
  prepare_homebrew_path
  command -v brew >/dev/null 2>&1 ||
    fail 'Homebrew was installed but is not available. Open a new terminal and rerun setup.'
}

ensure_linux_admin() {
  (( EUID != 0 )) || fail 'Run setup as your normal user, not root; sudo will be used for privileged changes.'
  command -v sudo >/dev/null 2>&1 || fail 'sudo is required for privileged Linux changes.'
  sudo -v || fail 'Administrator approval is required for privileged Linux changes.'
}

ensure_linux_base_tools() {
  local distro_id
  [[ -r /etc/os-release ]] || fail 'Cannot identify Linux distribution from /etc/os-release.'
  distro_id="$(. /etc/os-release; printf '%s' "$ID")"
  [[ "$distro_id" == ubuntu || "$distro_id" == debian ]] ||
    fail "Automatic installation currently supports Ubuntu and Debian, not $distro_id. Install prerequisites manually and run bash setup.sh."
  ensure_linux_admin
  printf 'Installing Ubuntu/Debian bootstrap packages...\n'
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl git tar xz-utils unzip
}

prepare_uv_path() {
  local uv_directory
  for uv_directory in "${UV_INSTALL_DIR:-}" "${XDG_BIN_HOME:-}" "$HOME/.local/bin"; do
    if [[ -n "$uv_directory" && -x "$uv_directory/uv" ]]; then
      PATH="$uv_directory:$PATH"
      export PATH
      return 0
    fi
  done
}

install_linux_python() {
  command -v uv >/dev/null 2>&1 || {
    printf 'Installing uv from its official installer...\n'
    curl -LsSf https://astral.sh/uv/install.sh | sh
    prepare_uv_path
  }
  command -v uv >/dev/null 2>&1 || fail 'uv installed but was not found. Open a new terminal and rerun setup.'
  printf 'Installing Python 3.13 with uv...\n'
  uv python install 3.13
}

get_nvm_directory() {
  if [[ -n "${NVM_DIR:-}" ]]; then
    printf '%s\n' "$NVM_DIR"
  elif [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
    printf '%s\n' "$XDG_CONFIG_HOME/nvm"
  else
    printf '%s\n' "$HOME/.nvm"
  fi
}

prepare_nvm_node_path() {
  local nvm_directory
  nvm_directory="$(get_nvm_directory)"
  [[ -s "$nvm_directory/nvm.sh" ]] || return 0
  set +u
  . "$nvm_directory/nvm.sh"
  nvm use 24 --silent >/dev/null 2>&1 || true
  set -u
}

install_linux_node() {
  local nvm_directory
  nvm_directory="$(get_nvm_directory)"
  if [[ ! -s "$nvm_directory/nvm.sh" ]]; then
    printf 'Installing nvm from its pinned upstream installer...\n'
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | bash
  fi
  [[ -s "$nvm_directory/nvm.sh" ]] || fail 'nvm installed but its shell script was not found.'
  # nvm is a shell function, so load it in this process before npm ci.
  set +u
  . "$nvm_directory/nvm.sh"
  nvm install 24
  nvm alias default 24
  set -u
}

install_linux_docker() {
  printf 'Installing Docker Engine and Compose from Docker official installer...\n'
  curl -fsSL https://get.docker.com | sudo sh
  docker compose version >/dev/null 2>&1 ||
    fail 'Docker was installed, but the Compose plugin is unavailable. Check the Docker installer output.'
}

enable_linux_docker_group() {
  ensure_linux_admin
  command -v docker >/dev/null 2>&1 || fail 'Docker must be installed before enabling Docker group access.'
  getent group docker >/dev/null 2>&1 || fail 'Docker group was not created by the installation.'
  printf '[WARN] Docker group membership grants root-equivalent privileges.\n'
  sudo usermod -aG docker "$(id -un)"
  printf '[WARN] Log out and back in before running bash run.sh without sudo.\n'
}

prepare_homebrew_node_path() {
  if command -v brew >/dev/null 2>&1; then
    local node_prefix
    node_prefix="$(brew --prefix node@24 2>/dev/null || true)"
    if [[ -n "$node_prefix" && -x "$node_prefix/bin/node" ]]; then
      PATH="$node_prefix/bin:$PATH"
      export PATH
    fi
  fi
}

find_python_313() {
  local candidate version python_prefix
  for candidate in python3.13; do
    if command -v "$candidate" >/dev/null 2>&1; then
      version="$("$candidate" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || true)"
      if [[ "$version" == 3.13 ]]; then
        command -v "$candidate"
        return 0
      fi
    fi
  done

  if command -v brew >/dev/null 2>&1; then
    python_prefix="$(brew --prefix python@3.13 2>/dev/null || true)"
    candidate="$python_prefix/bin/python3.13"
    if [[ -n "$python_prefix" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  if command -v uv >/dev/null 2>&1; then
    candidate="$(uv --no-python-downloads python find 3.13 2>/dev/null || true)"
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi
  return 1
}

node_and_npm_compatible() {
  command -v node >/dev/null 2>&1 || return 1
  command -v npm >/dev/null 2>&1 || return 1

  local version major minor
  version="$(node --version 2>/dev/null || true)"
  version="${version#v}"
  if [[ ! "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    return 1
  fi
  major="${BASH_REMATCH[1]}"
  minor="${BASH_REMATCH[2]}"
  npm --version >/dev/null 2>&1 || return 1

  (( major > 22 || (major == 22 && minor >= 12) || (major == 20 && minor >= 19) ))
}

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

show_oauth_status() {
  local provider client_id client_secret configured_count=0
  printf '\nOAuth provider readiness:\n'
  for provider in GITHUB GOOGLE MICROSOFT; do
    client_id="$(read_env_value "${provider}_CLIENT_ID")"
    client_secret="$(read_env_value "${provider}_CLIENT_SECRET")"
    if [[ -n "$client_id" && -n "$client_secret" ]]; then
      printf '  [OK] %s: configured\n' "$provider"
      configured_count=$((configured_count + 1))
    elif [[ -n "$client_id" || -n "$client_secret" ]]; then
      printf '  [WARN] %s: incomplete credentials\n' "$provider"
    else
      printf '  [--] %s: not configured\n' "$provider"
    fi
  done
  if (( configured_count == 0 )); then
    printf '[WARN] No OAuth providers are configured. Add credentials to .env before users can sign in.\n' >&2
  fi
}

cd -- "$PROJECT_ROOT"

if [[ "$OS_NAME" == Linux && ( "$INSTALL_PREREQUISITES" == true || "$INSTALL_DOCKER" == true ) ]]; then
  ensure_linux_base_tools
fi
if [[ "$OS_NAME" == Darwin ]]; then
  prepare_homebrew_path
fi
prepare_homebrew_node_path
prepare_uv_path
PYTHON_COMMAND="$(find_python_313 || true)"
if [[ -z "$PYTHON_COMMAND" ]]; then
  if [[ "$INSTALL_PREREQUISITES" != true ]]; then
    fail 'Python 3.13 was not found. Install it or rerun bash setup.sh --install-prerequisites.'
  fi
  if [[ "$OS_NAME" == Darwin ]]; then
    ensure_homebrew
    printf 'Installing Python 3.13 through Homebrew...\n'
    brew install python@3.13
  else
    install_linux_python
  fi
  PYTHON_COMMAND="$(find_python_313 || true)"
  [[ -n "$PYTHON_COMMAND" ]] || fail "Python 3.13 was installed but is unavailable. Open a new terminal and rerun bash setup.sh."
fi

if ! node_and_npm_compatible; then
  if [[ "$OS_NAME" == Linux ]]; then
    prepare_nvm_node_path
  fi
fi

if ! node_and_npm_compatible; then
  if [[ "$INSTALL_PREREQUISITES" != true ]]; then
    fail 'Compatible Node.js and npm were not found. Install Node.js 20.19+ or 22.12+, or rerun bash setup.sh --install-prerequisites.'
  fi
  if [[ "$OS_NAME" == Darwin ]]; then
    ensure_homebrew
    printf 'Installing Node.js 24 through Homebrew...\n'
    brew install node@24
    prepare_homebrew_node_path
  else
    install_linux_node
  fi
  node_and_npm_compatible || fail "Node.js was installed but is unavailable. Open a new terminal and rerun bash setup.sh."
fi

if ! command -v docker >/dev/null 2>&1; then
  if [[ "$INSTALL_PREREQUISITES" == true || "$INSTALL_DOCKER" == true ]]; then
    if [[ "$OS_NAME" == Darwin ]]; then
      ensure_homebrew
      printf 'Installing Docker Desktop through Homebrew...\n'
      brew install --cask docker-desktop
      printf '[WARN] Open Docker Desktop once to accept its terms and finish first-run setup before running the app.\n'
    else
      install_linux_docker
    fi
  else
    printf '[WARN] Docker was not found. Rerun bash setup.sh --install-docker or install it manually.\n' >&2
  fi
elif [[ "$OS_NAME" == Linux ]] && ! docker compose version >/dev/null 2>&1; then
  if [[ "$INSTALL_PREREQUISITES" == true || "$INSTALL_DOCKER" == true ]]; then
    sudo apt-get install -y docker-compose-plugin ||
      fail 'Docker is installed without Compose. Install the Docker Compose plugin from the official Docker repository.'
  else
    printf '[WARN] Docker Compose plugin was not found. Rerun bash setup.sh --install-docker.\n' >&2
  fi
fi

if [[ "$OS_NAME" == Linux && "$ENABLE_DOCKER_GROUP" == true ]]; then
  enable_linux_docker_group
elif [[ "$OS_NAME" == Linux && ( "$INSTALL_PREREQUISITES" == true || "$INSTALL_DOCKER" == true ) ]] && ! docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
  printf '[WARN] Docker may require group access. Rerun with --enable-docker-group only if you accept its root-equivalent privileges, then log out and back in.\n' >&2
fi

if [[ "$OS_NAME" == Darwin && "$INSTALL_PREREQUISITES" == true ]] && ! command -v git >/dev/null 2>&1; then
  ensure_homebrew
  printf 'Installing Git through Homebrew...\n'
  brew install git
fi

VENV_PYTHON="$PROJECT_ROOT/.venv/bin/python"
if [[ ! -x "$VENV_PYTHON" ]]; then
  if [[ -e "$PROJECT_ROOT/.venv" ]]; then
    fail "The existing .venv is incompatible with macOS/Linux. Move it aside and rerun bash setup.sh."
  fi
  printf 'Creating Python virtual environment...\n'
  if [[ "$OS_NAME" == Linux ]] && command -v uv >/dev/null 2>&1; then
    uv venv --python "$PYTHON_COMMAND" "$PROJECT_ROOT/.venv"
  else
    "$PYTHON_COMMAND" -m venv "$PROJECT_ROOT/.venv"
  fi
else
  venv_version="$("$VENV_PYTHON" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || true)"
  [[ "$venv_version" == 3.13 ]] || fail "The existing .venv does not use Python 3.13. Move it aside and rerun bash setup.sh."
fi

printf 'Installing Python dependencies...\n'
if "$VENV_PYTHON" -m pip --version >/dev/null 2>&1; then
  "$VENV_PYTHON" -m pip install -r "$PROJECT_ROOT/requirements.txt"
elif command -v uv >/dev/null 2>&1; then
  uv pip install --python "$VENV_PYTHON" -r "$PROJECT_ROOT/requirements.txt"
else
  fail 'The virtual environment has no pip. Install pip for Python 3.13 or rerun with --install-prerequisites.'
fi

printf 'Installing frontend dependencies...\n'
(cd -- "$PROJECT_ROOT/apps/web" && npm ci)

if [[ ! -e "$PROJECT_ROOT/.env" ]]; then
  [[ -f "$PROJECT_ROOT/.env.example" ]] || fail "Missing .env.example in the project root."
  session_secret="$("$VENV_PYTHON" -c 'import secrets; print(secrets.token_urlsafe(48))')"
  umask 077
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      SESSION_SECRET=*) printf 'SESSION_SECRET=%s\n' "$session_secret" ;;
      *) printf '%s\n' "$line" ;;
    esac
  done < "$PROJECT_ROOT/.env.example" > "$PROJECT_ROOT/.env"
  printf 'Created .env from .env.example with a unique session secret.\n'
else
  printf 'Existing .env preserved.\n'
fi

show_oauth_status
if ! command -v docker >/dev/null 2>&1; then
  printf '[WARN] Docker CLI is still unavailable. Complete Docker first-run setup or open a new terminal before using bash run.sh.\n' >&2
elif ! docker compose version >/dev/null 2>&1; then
  printf '[WARN] Docker Compose is unavailable. Complete Docker first-run setup or update Docker before using bash run.sh.\n' >&2
fi
printf 'Setup complete. Add your OAuth credentials to .env, then run bash run.sh.\n'
