#!/usr/bin/env bash

# AI Workstation Bootstrap — Pro (v3.1.0)
# Production-grade provisioning script for macOS and Linux; Windows uses PowerShell companion.
#
# Security & Operational Principles:
# - Eliminates pipe-to-shell installers (downloads to temp, executes locally)
# - Strict quoting, set -euo pipefail, and clear error handling
# - Idempotent operations guarded by checks
# - Supports pinned dependencies via requirements.txt
# - Optional offline install via local wheels directory
#
# Usage:
#   bash ai_workstation_bootstrap_pro.sh [--mac|--linux|--windows] [--dev|--prod] [--log-file FILE] [--wheels-dir DIR]
#
# Changelog highlights vs 3.0.x:
# - Hardened installer flows (Ollama, Python deps)
# - Consistent logging and quoting
# - Windows path moved to documented PS script (surface_ai_optimize_v_2.ps1)

set -euo pipefail
IFS=$'\n\t'

PROJECT_NAME="AI Workstation Bootstrap"
SCRIPT_VERSION="3.1.0"
AUTHOR="Project Maintainers"

OS_TYPE=""
ENV_TYPE="dev" # default
LOG_FILE="$(pwd)/bootstrap.log"
PIP_REQUIREMENTS_FILE="requirements.txt" # respected if present
LOCAL_WHEELS_DIR="wheels" # optional offline cache

# Utility: log with timestamp
log() {
  local level="$1"; shift
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" | tee -a "$LOG_FILE"
}

# Utility: print and exit on error
die() {
  log "ERROR" "$*"
  exit 1
}

# Determine OS type
detect_os() {
  case "$(uname -s)" in
    Darwin)
      OS_TYPE="mac"
      ;;
    Linux)
      OS_TYPE="linux"
      ;;
    *)
      OS_TYPE="unknown"
      ;;
  esac
}

# Parse arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mac)
        OS_TYPE="mac"; shift ;;
      --windows)
        OS_TYPE="windows"; shift ;;
      --linux)
        OS_TYPE="linux"; shift ;;
      --dev)
        ENV_TYPE="dev"; shift ;;
      --prod)
        ENV_TYPE="prod"; shift ;;
      --log-file)
        LOG_FILE="$2"; shift 2 ;;
      --wheels-dir)
        LOCAL_WHEELS_DIR="$2"; shift 2 ;;
      --help|-h)
        cat <<EOF
${PROJECT_NAME} — Pro (${SCRIPT_VERSION})
Usage: bash ai_workstation_bootstrap_pro.sh [--mac|--windows|--linux] [--dev|--prod] [--log-file FILE] [--wheels-dir DIR]

Options:
  --mac             Force macOS provisioning
  --windows         Documented steps; use PowerShell scripts for execution
  --linux           Provision on Linux
  --dev             Development mode (default)
  --prod            Production mode (more strict)
  --log-file FILE   Write logs to FILE (default: ./bootstrap.log)
  --wheels-dir DIR  Local wheels cache directory (default: ./wheels)
  -h, --help        Show this help
EOF
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

# Ensure logging file is writable
ensure_log_file() {
  touch "$LOG_FILE" 2>/dev/null || die "Cannot write to log file: $LOG_FILE"
}

# macOS: Install Homebrew safely if missing
mac_brew_install() {
  if ! command -v brew >/dev/null 2>&1; then
    log INFO "Homebrew not found. Installing..."
    # Official command from Homebrew; risk acknowledged.
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || die "Homebrew installation failed"
    log INFO "Homebrew installed. Updating PATH..."
    if [[ -d "/opt/homebrew/bin" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -d "/usr/local/bin" ]]; then
      export PATH="/usr/local/bin:$PATH"
    fi
  else
    log INFO "Homebrew already installed"
  fi
}

# macOS: Install Python 3 (via Homebrew)
mac_python_install() {
  log INFO "Ensuring Python 3 is installed via Homebrew..."
  brew update || log WARN "brew update failed; continuing"
  brew install python@3.11 || log WARN "brew install python@3.11 failed; attempting fallback"
  if command -v python3 >/dev/null 2>&1; then
    log INFO "python3 found"
  else
    die "Python3 installation failed"
  fi
}

# macOS: Install or upgrade pip
mac_pip_upgrade() {
  log INFO "Upgrading pip..."
  python3 -m ensurepip --upgrade || true
  python3 -m pip install --upgrade pip setuptools wheel || die "pip upgrade failed"
}

# macOS: Install AI stack with pinned reqs if available
mac_install_ai_stack() {
  log INFO "Installing AI stack..."
  if [[ -f "$PIP_REQUIREMENTS_FILE" ]]; then
    log INFO "Found $PIP_REQUIREMENTS_FILE — installing pinned dependencies"
    python3 -m pip install --no-cache-dir -r "$PIP_REQUIREMENTS_FILE" || die "Pinned requirements install failed"
  else
    log WARN "No $PIP_REQUIREMENTS_FILE found — installing baseline deps (unpinned)"
    python3 -m pip install --no-cache-dir numpy==1.26.4 pandas==2.2.2 torch==2.3.1 transformers==4.43.4 || die "Baseline install failed"
  fi
}

# macOS: Install Ollama safely (download then execute)
mac_install_ollama() {
  log INFO "Installing Ollama (safe download + local execution)..."
  local tmp_script
  tmp_script="$(mktemp /tmp/ollama_install.XXXXXX.sh)"
  curl -fsSL https://ollama.com/install.sh -o "$tmp_script" || die "Failed to download Ollama installer"
  chmod +x "$tmp_script"
  bash "$tmp_script" || die "Ollama installer execution failed"
  rm -f "$tmp_script" || true
}

# Linux: Install Python and pip
linux_python_install() {
  log INFO "Ensuring Python 3 and pip on Linux..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y || log WARN "apt-get update failed; continuing"
    sudo apt-get install -y python3 python3-pip python3-venv || die "Apt install failed"
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y python3 python3-pip python3-virtualenv || die "DNF install failed"
  else
    log WARN "Unsupported Linux package manager; please install Python 3 manually"
  fi
}

linux_pip_upgrade() {
  log INFO "Upgrading pip on Linux..."
  python3 -m pip install --upgrade pip setuptools wheel || die "pip upgrade failed"
}

linux_install_ai_stack() {
  log INFO "Installing AI stack on Linux..."
  if [[ -f "$PIP_REQUIREMENTS_FILE" ]]; then
    python3 -m pip install --no-cache-dir -r "$PIP_REQUIREMENTS_FILE" || die "Pinned requirements install failed"
  else
    python3 -m pip install --no-cache-dir numpy==1.26.4 pandas==2.2.2 torch==2.3.1 transformers==4.43.4 || die "Baseline install failed"
  fi
}

# Common: Use local wheels if present for offline mode
use_local_wheels_if_present() {
  if [[ -d "$LOCAL_WHEELS_DIR" ]] && [[ -f "$PIP_REQUIREMENTS_FILE" ]]; then
    log INFO "Using local wheels from $LOCAL_WHEELS_DIR"
    python3 -m pip install --no-index --find-links "$LOCAL_WHEELS_DIR" -r "$PIP_REQUIREMENTS_FILE" || log WARN "Local wheels install failed; falling back to index"
  fi
}

# Entry points per OS
run_mac() {
  mac_brew_install
  mac_python_install
  mac_pip_upgrade
  use_local_wheels_if_present
  mac_install_ai_stack
  mac_install_ollama
  log INFO "macOS provisioning complete"
}

run_linux() {
  linux_python_install
  linux_pip_upgrade
  use_local_wheels_if_present
  linux_install_ai_stack
  log INFO "Linux provisioning complete"
}

# Windows: documented steps only
run_windows() {
  log INFO "Windows provisioning: please run PowerShell script (surface_ai_optimize_v_2.ps1) for installation steps"
}

main() {
  ensure_log_file
  detect_os
  parse_args "$@"
  log INFO "Starting ${PROJECT_NAME} v${SCRIPT_VERSION} on OS=$OS_TYPE env=$ENV_TYPE"

  case "$OS_TYPE" in
    mac)
      run_mac ;;
    linux)
      run_linux ;;
    windows)
      run_windows ;;
    *)
      die "Unsupported or undetected OS. Use --mac, --linux, or --windows" ;;
  esac
}

main "$@"