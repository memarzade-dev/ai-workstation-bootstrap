#!/usr/bin/env bash
# mac_ai_optimize.sh — Apple Silicon (M1/M2/M3) AI workstation bootstrapper
# Author: memarzade-dev (prepared by assistant)
# Version: 1.2.0
#
# What it does (idempotent and safe to re-run):
#  - Tunes power/sleep for plugged-in AI sessions (revertable)
#  - Optionally disables global App Nap (revertable)
#  - Installs Homebrew and core toolchain (git, cmake, python, wget, jq)
#  - Installs Ollama and enables it as a service
#  - Creates a Python venv with PyTorch (MPS backend) + transformers + accelerate
#  - Installs llama.cpp via Homebrew
#  - Creates a helper `ai-caffeinate` wrapper to keep Mac awake while running a command
#  - Excludes model/cache folders from Spotlight indexing (revertable)
#  - Logs everything to ~/mac_ai_optimize.log
#
# Flags:
#   --revert           : restore conservative defaults (power, App Nap, Spotlight, remove ai-caffeinate)
#   --no-brew          : skip Homebrew/toolchain
#   --no-ollama        : skip Ollama install
#   --no-pytorch       : skip Python venv + PyTorch
#   --no-llama         : skip llama.cpp install
#   --no-appnap        : do NOT touch App Nap (leave as-is)
#   --with-conda       : also install Miniforge (Conda) and create env `ai` with PyTorch (MPS)
#   --models-dir <dir> : directory for models & caches (default: ~/Models)
#
# Usage:
#   chmod +x mac_ai_optimize.sh
#   ./mac_ai_optimize.sh
#   ./mac_ai_optimize.sh --revert
#
set -euo pipefail
IFS=$'\n\t'

LOG_FILE="$HOME/mac_ai_optimize.log"
MODELS_DIR="$HOME/Models"
DO_BREW=1
DO_OLLAMA=1
DO_PYTORCH=1
DO_LLAMA=1
TOUCH_APPNAP=1
WITH_CONDA=0
REVERT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --revert) REVERT=1; shift ;;
    --no-brew) DO_BREW=0; shift ;;
    --no-ollama) DO_OLLAMA=0; shift ;;
    --no-pytorch) DO_PYTORCH=0; shift ;;
    --no-llama) DO_LLAMA=0; shift ;;
    --no-appnap) TOUCH_APPNAP=0; shift ;;
    --with-conda) WITH_CONDA=1; shift ;;
    --models-dir) MODELS_DIR="${2:-$MODELS_DIR}"; shift 2 ;;
    -h|--help) sed -n '1,80p' "$0"; exit 0 ;;
    *) echo "[WARN] Unknown arg: $1"; shift ;;
  esac
done

# -------------- logging wrapper --------------
exec > >(tee -a "$LOG_FILE") 2>&1
START_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "\n=== mac_ai_optimize start @ $START_TS ==="

# -------------- sanity checks --------------
if [[ $(uname -s) != "Darwin" ]]; then
  echo "[FATAL] This script is for macOS (Apple Silicon)."; exit 1
fi
ARCH=$(uname -m)
if [[ "$ARCH" != "arm64" ]]; then
  echo "[WARN] Non-Apple-Silicon arch reported: $ARCH. Continuing anyway."
fi

# ensure sudo once if needed later
function ensure_sudo() {
  if ! sudo -n true 2>/dev/null; then
    echo "[INFO] Asking for sudo once (used for pmset/spotlight tweaks)"
    sudo -v
  fi
}

# -------------- helpers --------------
function ensure_dir() { mkdir -p "$1"; }
function has_cmd() { command -v "$1" >/dev/null 2>&1; }
function brew_prefix() { brew --prefix 2>/dev/null || echo "/opt/homebrew"; }

# -------------- power tuning (apply) --------------
function apply_power() {
  ensure_sudo
  echo "[POWER] Backing up current pmset custom profile"
  sudo pmset -g custom > "$HOME/.pmset.custom.backup" || true

  echo "[POWER] Applying plugged-in (AC) performance profile"
  sudo pmset -c sleep 0 displaysleep 0 disksleep 0 powernap 0 tcpkeepalive 1 ttyskeepawake 1 autopoweroff 0

  echo "[POWER] Applying battery conservative profile"
  sudo pmset -b sleep 10 displaysleep 5 powernap 1 tcpkeepalive 1 autopoweroff 1
}

# -------------- power tuning (revert) --------------
function revert_power() {
  ensure_sudo
  echo "[POWER] Reverting pmset to conservative defaults"
  # We cannot perfectly restore vendor defaults universally; set sane defaults
  sudo pmset -c sleep 30 displaysleep 15 disksleep 10 powernap 1 tcpkeepalive 1 autopoweroff 1
  sudo pmset -b sleep 15 displaysleep 5 powernap 1 tcpkeepalive 1 autopoweroff 1
}

# -------------- App Nap --------------
function apply_appnap() {
  echo "[APPNAP] Disabling global App Nap (revertable)"
  defaults write -g NSAppSleepDisabled -bool YES || true
}
function revert_appnap() {
  echo "[APPNAP] Enabling App Nap (remove override)"
  defaults delete -g NSAppSleepDisabled >/dev/null 2>&1 || true
}

# -------------- Spotlight exclusions --------------
function apply_spotlight() {
  ensure_dir "$MODELS_DIR"
  echo "[SPOTLIGHT] Disabling indexing for: $MODELS_DIR"
  ensure_sudo
  sudo mdutil -i off "$MODELS_DIR" || true
}
function revert_spotlight() {
  if [[ -d "$MODELS_DIR" ]]; then
    echo "[SPOTLIGHT] Re-enabling indexing: $MODELS_DIR"
    ensure_sudo
    sudo mdutil -i on "$MODELS_DIR" || true
  fi
}

# -------------- Homebrew & toolchain --------------
function install_brew() {
  if has_cmd brew; then
    echo "[BREW] Homebrew found: $(brew --version | head -n1)"
    brew update || true
  else
    echo "[BREW] Installing Homebrew (non-interactive)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$($(brew_prefix)/bin/brew shellenv)"
  fi

  echo "[BREW] Installing toolchain packages"
  brew install git cmake python jq wget gnu-sed || true
  eval "$($(brew_prefix)/bin/brew shellenv)"
}

# -------------- Ollama --------------
function install_ollama() {
  if has_cmd ollama; then
    echo "[OLLAMA] Already installed: $(ollama --version 2>/dev/null || echo present)"
  else
    echo "[OLLAMA] Installing via Homebrew"
    brew install ollama
  fi
  echo "[OLLAMA] Enabling service"
  brew services start ollama || true
}

# -------------- Python venv + PyTorch MPS --------------
VENV_DIR="$HOME/.venvs/ai"
function install_pytorch() {
  PYBIN="$(brew --prefix)/bin/python3" || PYBIN="python3"
  ensure_dir "$(dirname "$VENV_DIR")"
  if [[ ! -d "$VENV_DIR" ]]; then
    echo "[PYTHON] Creating venv at $VENV_DIR"
    "$PYBIN" -m venv "$VENV_DIR"
  fi
  source "$VENV_DIR/bin/activate"
  python -m pip install --upgrade pip wheel setuptools
  # PyTorch (MPS) is provided via pip wheels for macOS arm64
  echo "[PYTORCH] Installing torch/torchvision/torchaudio + transformers/accelerate"
  pip install --upgrade torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl
  pip install --upgrade transformers accelerate bitsandbytes tokenizers safetensors
  # MPS fallback env for this venv
  ACTIVATE_SNIPPET='export PYTORCH_ENABLE_MPS_FALLBACK=1'
  if ! grep -q 'PYTORCH_ENABLE_MPS_FALLBACK' "$VENV_DIR/bin/activate"; then
    echo "$ACTIVATE_SNIPPET" >> "$VENV_DIR/bin/activate"
  fi
  # quick MPS test
  python - <<'PY'
import torch
print('[MPS] available =', torch.backends.mps.is_available())
print('[MPS] built =', torch.backends.mps.is_built())
PY
  deactivate || true
}

# -------------- Miniforge/Conda (optional) --------------
function install_conda() {
  local MF_DIR="$HOME/miniforge3"
  if [[ -d "$MF_DIR" ]]; then
    echo "[CONDA] Miniforge present: $MF_DIR"
  else
    echo "[CONDA] Installing Miniforge (arm64)"
    curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-arm64.sh -o /tmp/miniforge.sh
    bash /tmp/miniforge.sh -b -p "$MF_DIR"
  fi
  source "$MF_DIR/etc/profile.d/conda.sh"
  conda update -y -n base -c conda-forge conda
  if ! conda env list | grep -q '^ai\s'; then
    echo "[CONDA] Creating env 'ai' (PyTorch MPS)"
    conda create -y -n ai -c conda-forge python=3.11 pytorch torchvision torchaudio
  fi
}

# -------------- llama.cpp --------------
function install_llamacpp() {
  echo "[LLAMA.CPP] Installing via Homebrew (Metal build)"
  brew install llama.cpp || true
  # symlink helper if needed
  if ! has_cmd llama-cli && [[ -x "$(brew --prefix)/bin/llama-cli" ]]; then
    ln -sf "$(brew --prefix)/bin/llama-cli" "$HOME/bin/llama-cli" 2>/dev/null || true
  fi
}

# -------------- ai-caffeinate helper --------------
function install_ai_caffeinate() {
  ensure_dir "$HOME/bin"
  cat > "$HOME/bin/ai-caffeinate" <<'SH'
#!/usr/bin/env bash
# Keep Mac awake while running the given command (display, idle, system, disk)
/usr/bin/caffeinate -dimsu "$@"
SH
  chmod +x "$HOME/bin/ai-caffeinate"
  if ! grep -q 'export PATH="$HOME/bin' "$HOME/.zprofile" 2>/dev/null; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zprofile"
  fi
}

function remove_ai_caffeinate() {
  rm -f "$HOME/bin/ai-caffeinate" 2>/dev/null || true
}

# -------------- main flows --------------
function apply_all() {
  apply_power
  [[ $TOUCH_APPNAP -eq 1 ]] && apply_appnap || echo "[APPNAP] Skipped"
  apply_spotlight
  if [[ $DO_BREW -eq 1 ]]; then install_brew; else echo "[BREW] Skipped"; fi
  if [[ $DO_OLLAMA -eq 1 ]]; then install_ollama; else echo "[OLLAMA] Skipped"; fi
  if [[ $DO_PYTORCH -eq 1 ]]; then install_pytorch; else echo "[PYTORCH] Skipped"; fi
  if [[ $WITH_CONDA -eq 1 ]]; then install_conda; fi
  if [[ $DO_LLAMA -eq 1 ]] ; then install_llamacpp; else echo "[LLAMA.CPP] Skipped"; fi
  install_ai_caffeinate
  echo "[DONE] Apply complete. Models dir: $MODELS_DIR | Log: $LOG_FILE"
  echo "Try:  ollama run llama3   or   source $VENV_DIR/bin/activate"
}

function revert_all() {
  revert_power
  [[ $TOUCH_APPNAP -eq 1 ]] && revert_appnap || echo "[APPNAP] Skipped"
  revert_spotlight
  remove_ai_caffeinate
  echo "[DONE] Revert finished. You may want to stop Ollama: brew services stop ollama"
}

# -------------- dispatch --------------
if [[ $REVERT -eq 1 ]]; then
  revert_all
else
  apply_all
fi

END_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "=== mac_ai_optimize end @ $END_TS ==="
