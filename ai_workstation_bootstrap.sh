#!/usr/bin/env bash
# ai_workstation_bootstrap.sh — Cross‑platform AI workstation bootstrapper
# Platforms: macOS (Apple Silicon/Intel), Linux (Debian/Ubuntu, RHEL/Fedora, Arch), Windows (via generated PowerShell)
# Author: memarzade-dev (prepared by assistant)
# Version: 2.0.0
#
# Goals
#  - Detect OS/arch and apply best‑practice setup for local AI workloads (LLM + Diffusion, dev toolchain)
#  - Idempotent (safe to re-run), verbose logging, reversible where possible
#  - macOS: pmset tuning, App Nap toggle, Spotlight exclusion (+ .metadata_never_index fallback), Homebrew toolchain,
#           Ollama service, Python venv w/ PyTorch (MPS on Apple Silicon), optional Conda, llama.cpp
#  - Linux: package manager toolchain, NVIDIA driver/CUDA detection, Ollama, Python venv w/ PyTorch (CPU/CUDA), llama.cpp build
#  - Windows: generate and execute PowerShell script using winget/choco, install Ollama, Python + PyTorch (CPU/CUDA),
#             set power plan High performance, add keep‑awake helper, optional WSL setup hint
#
# Flags
#   --revert             : revert tunings (where possible)
#   --no-ollama          : skip Ollama install
#   --no-pytorch         : skip Python venv + PyTorch stack
#   --no-llama           : skip llama.cpp
#   --with-conda         : also set up Miniforge/Conda env `ai`
#   --models-dir <dir>   : directory for models & caches (default: ~/Models)
#   --venv-dir <dir>     : Python venv path (default: ~/.venvs/ai)
#   --yes                : non‑interactive where possible
#
# Usage
#   chmod +x ai_workstation_bootstrap.sh
#   ./ai_workstation_bootstrap.sh
#   ./ai_workstation_bootstrap.sh --revert
set -euo pipefail
IFS=$'\n\t'

VER="2.0.0"
LOG_FILE="$HOME/ai_workstation_bootstrap.log"
MODELS_DIR="$HOME/Models"
VENV_DIR="$HOME/.venvs/ai"
DO_OLLAMA=1
DO_PYTORCH=1
DO_LLAMA=1
WITH_CONDA=0
REVERT=0
ASSUME_YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --revert) REVERT=1; shift ;;
    --no-ollama) DO_OLLAMA=0; shift ;;
    --no-pytorch) DO_PYTORCH=0; shift ;;
    --no-llama) DO_LLAMA=0; shift ;;
    --with-conda) WITH_CONDA=1; shift ;;
    --models-dir) MODELS_DIR="${2:-$MODELS_DIR}"; shift 2 ;;
    --venv-dir) VENV_DIR="${2:-$VENV_DIR}"; shift 2 ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    -h|--help) sed -n '1,120p' "$0"; exit 0 ;;
    *) echo "[WARN] Unknown arg: $1"; shift ;;
  esac
done

exec > >(tee -a "$LOG_FILE") 2>&1
START_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "\n=== ai_workstation_bootstrap v$VER start @ $START_TS ==="

OS="$(uname -s)"
ARCH="$(uname -m)"

has_cmd(){ command -v "$1" >/dev/null 2>&1; }
ensure_dir(){ mkdir -p "$1"; }
confirm(){ [[ $ASSUME_YES -eq 1 ]] && return 0; read -r -p "$1 [Y/n] " ans; [[ -z "$ans" || "$ans" =~ ^[Yy]$ ]]; }

# ---------------------- macOS section ----------------------
apply_macos(){
  echo "[macOS] Detected $ARCH"

  # sudo cache if needed
  if ! sudo -n true 2>/dev/null; then echo "[macOS] sudo requested for power/indexing"; sudo -v; fi

  # Power profiles
  echo "[macOS] Backing up pmset custom profile"; sudo pmset -g custom > "$HOME/.pmset.custom.backup" || true
  echo "[macOS] Apply AC performance profile"; sudo pmset -c sleep 0 displaysleep 0 disksleep 0 powernap 0 tcpkeepalive 1 ttyskeepawake 1 autopoweroff 0
  echo "[macOS] Apply battery conservative profile"; sudo pmset -b sleep 10 displaysleep 5 powernap 1 tcpkeepalive 1 autopoweroff 1

  # App Nap (global) — can be noisy if toggled per-app; use global override
  echo "[macOS] Disabling global App Nap"; defaults write -g NSAppSleepDisabled -bool YES || true

  # Spotlight exclusion with fallback
  ensure_dir "$MODELS_DIR"
  echo "[macOS] Spotlight: trying mdutil -i off $MODELS_DIR"
  if ! sudo mdutil -i off "$MODELS_DIR"; then
    echo "[macOS] mdutil failed; using .metadata_never_index + xattr"
    touch "$MODELS_DIR/.metadata_never_index" || true
    xattr -w com.apple.metadata:com_apple_backup_excludeItem com.apple.backupd "$MODELS_DIR" || true
  fi

  # Brew toolchain
  if has_cmd brew; then echo "[macOS] Homebrew present"; brew update || true; else
    echo "[macOS] Installing Homebrew";
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)";
    eval "$($(brew --prefix)/bin/brew shellenv)"
  fi
  echo "[macOS] Installing toolchain"; brew install git cmake python jq wget gnu-sed || true

  # Ollama
  if [[ $DO_OLLAMA -eq 1 ]]; then
    if has_cmd ollama; then echo "[macOS] Ollama present: $(ollama --version 2>/dev/null || echo)"; else brew install ollama; fi
    brew services start ollama || true
  fi

  # Python venv + PyTorch
  if [[ $DO_PYTORCH -eq 1 ]]; then
    ensure_dir "$(dirname "$VENV_DIR")"
    PYBIN="$(brew --prefix)/bin/python3" || PYBIN=python3
    if [[ ! -d "$VENV_DIR" ]]; then "$PYBIN" -m venv "$VENV_DIR"; fi
    source "$VENV_DIR/bin/activate"
    python -m pip install --upgrade pip wheel setuptools
    # IMPORTANT: On macOS arm64, default PyPI wheels include MPS; DO NOT force extra-index to CPU wheels
    echo "[macOS] Installing PyTorch (MPS) + stack"
    pip install --upgrade torch torchvision torchaudio
    pip install --upgrade transformers accelerate tokenizers safetensors
    # bitsandbytes on macOS runs CPU‑only; install optional
    if confirm "Install bitsandbytes (CPU‑only on macOS)?"; then pip install bitsandbytes; fi
    if ! grep -q 'PYTORCH_ENABLE_MPS_FALLBACK' "$VENV_DIR/bin/activate"; then echo 'export PYTORCH_ENABLE_MPS_FALLBACK=1' >> "$VENV_DIR/bin/activate"; fi
    python - <<'PY'
import torch
print('[MPS] available =', torch.backends.mps.is_available())
print('[MPS] built     =', torch.backends.mps.is_built())
PY
    deactivate || true
  fi

  # llama.cpp
  if [[ $DO_LLAMA -eq 1 ]]; then
    echo "[macOS] Installing llama.cpp (Metal)"; brew install llama.cpp || true
  fi

  # keep‑awake helper
  ensure_dir "$HOME/bin"
  cat > "$HOME/bin/ai-caffeinate" <<'SH'
#!/usr/bin/env bash
/usr/bin/caffeinate -dimsu "$@"
SH
  chmod +x "$HOME/bin/ai-caffeinate"
  [[ -f "$HOME/.zprofile" ]] || touch "$HOME/.zprofile"
  grep -q 'PATH="$HOME/bin' "$HOME/.zprofile" || echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zprofile"

  echo "[macOS] Done. Models dir: $MODELS_DIR"
}

revert_macos(){
  echo "[macOS] Reverting tunings"
  sudo pmset -c sleep 30 displaysleep 15 disksleep 10 powernap 1 tcpkeepalive 1 autopoweroff 1 || true
  sudo pmset -b sleep 15 displaysleep 5 powernap 1 tcpkeepalive 1 autopoweroff 1 || true
  defaults delete -g NSAppSleepDisabled >/dev/null 2>&1 || true
  if [[ -d "$MODELS_DIR" ]]; then sudo mdutil -i on "$MODELS_DIR" || true; rm -f "$MODELS_DIR/.metadata_never_index" || true; fi
  rm -f "$HOME/bin/ai-caffeinate" || true
}

# ---------------------- Linux section ----------------------
install_linux_packages(){
  if has_cmd apt-get; then
    sudo apt-get update -y
    sudo apt-get install -y git build-essential cmake python3 python3-venv python3-pip jq wget curl pkg-config
  elif has_cmd dnf; then
    sudo dnf install -y git gcc-c++ make cmake python3 python3-virtualenv python3-pip jq wget curl
  elif has_cmd pacman; then
    sudo pacman -Sy --noconfirm git base-devel cmake python python-virtualenv python-pip jq wget curl
  else
    echo "[Linux] Unsupported package manager; install git/cmake/python/jq/wget manually"; fi
}

detect_nvidia(){
  if has_cmd nvidia-smi; then echo 1; else echo 0; fi
}

apply_linux(){
  echo "[Linux] Detected $ARCH"
  install_linux_packages

  # Ollama
  if [[ $DO_OLLAMA -eq 1 ]]; then
    if has_cmd ollama; then echo "[Linux] Ollama present"; else curl -fsSL https://ollama.com/install.sh | sh; fi
    # systemd service typically installed by script
    sudo systemctl enable --now ollama || true
  fi

  # Python venv + PyTorch
  if [[ $DO_PYTORCH -eq 1 ]]; then
    ensure_dir "$(dirname "$VENV_DIR")"
    PYBIN=python3
    "$PYBIN" -m venv "$VENV_DIR" 2>/dev/null || true
    source "$VENV_DIR/bin/activate"
    python -m pip install --upgrade pip wheel setuptools
    if [[ $(detect_nvidia) -eq 1 ]]; then
      CUDA_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1 || true)
      echo "[Linux] NVIDIA detected; installing CUDA PyTorch wheels"
      pip install --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 || \
      pip install --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 || \
      pip install --upgrade torch torchvision torchaudio  # fallback
    else
      echo "[Linux] No NVIDIA; installing CPU wheels"
      pip install --upgrade torch torchvision torchaudio
    fi
    pip install --upgrade transformers accelerate tokenizers safetensors bitsandbytes
    python - <<'PY'
import torch
print('[CUDA] available =', torch.cuda.is_available())
print('[Device] count    =', torch.cuda.device_count())
print('[Device] name0    =', torch.cuda.get_device_name(0) if torch.cuda.is_available() else None)
PY
    deactivate || true
  fi

  # llama.cpp build (portable)
  if [[ $DO_LLAMA -eq 1 ]]; then
    if has_cmd llama-cli; then echo "[Linux] llama.cpp present"; else
      echo "[Linux] Building llama.cpp from source (default flags)"
      WORK="$HOME/.cache/llama.cpp"; ensure_dir "$WORK"; cd "$WORK"
      if [[ ! -d llama.cpp ]]; then git clone --depth=1 https://github.com/ggerganov/llama.cpp.git; fi
      cd llama.cpp && make -j$(nproc) ; sudo install -m 0755 ./llama-cli /usr/local/bin/llama-cli 2>/dev/null || cp ./llama-cli "$HOME/.local/bin/" || true
      cd - >/dev/null || true
    fi
  fi

  # keep‑awake helper (caffeinate alt)
  ensure_dir "$HOME/bin"
  cat > "$HOME/bin/ai-caffeinate" <<'SH'
#!/usr/bin/env bash
# Linux keep-awake: inhibit sleep via systemd-inhibit
exec systemd-inhibit --what=sleep:idle --why="AI task" "$@"
SH
  chmod +x "$HOME/bin/ai-caffeinate"
  echo "[Linux] Done. Models dir: $MODELS_DIR"
}

revert_linux(){
  echo "[Linux] Nothing critical to revert (no global power tweaks were applied)."
  rm -f "$HOME/bin/ai-caffeinate" || true
}

# ---------------------- Windows section ----------------------
# We generate a PowerShell script and execute it if possible
apply_windows(){
  local PS1_FILE="$HOME/ai_bootstrap_windows.ps1"
  cat > "$PS1_FILE" <<'PS1'
# ai_bootstrap_windows.ps1 — Windows 10/11 workstation bootstrap
# Requires: Run as admin for power plan and winget installs (or accept prompts)
$ErrorActionPreference = 'Continue'
$Host.UI.RawUI.WindowTitle = 'AI Workstation Bootstrap (Windows)'

function Have($cmd){ return (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null }
function Log($msg){ Write-Host "[WIN] $msg" }

# Power: High performance
try { powercfg -SETACTIVE SCHEME_MIN; Log 'Power plan set to High performance' } catch { Log "Power plan error: $_" }

# winget
if (-not (Have 'winget')) { Log 'winget not found; please install App Installer from Microsoft Store.' }

# Tools
if (Have 'winget') {
  winget install -e --id Git.Git --silent --accept-source-agreements --accept-package-agreements
  winget install -e --id Kitware.CMake --silent --accept-source-agreements --accept-package-agreements
  winget install -e --id Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements
}

# Ollama
if (-not (Have 'ollama')) {
  if (Have 'winget') { winget install -e --id Ollama.Ollama --silent --accept-source-agreements --accept-package-agreements }
}
try { Start-Process -FilePath 'powershell' -ArgumentList 'Start-Service ollama' -Verb RunAs } catch {}

# Python venv + PyTorch (CUDA if NVIDIA present)
$venv = "$env:USERPROFILE\.venvs\ai"
py -3.12 -m venv $venv
& "$venv\Scripts\python.exe" -m pip install --upgrade pip wheel setuptools

$hasNvidia = (Get-Command nvidia-smi -ErrorAction SilentlyContinue) -ne $null
if ($hasNvidia) {
  & "$venv\Scripts\pip.exe" install --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
} else {
  & "$venv\Scripts\pip.exe" install --upgrade torch torchvision torchaudio
}
& "$venv\Scripts\pip.exe" install --upgrade transformers accelerate tokenizers safetensors bitsandbytes

# Quick device print
& "$venv\Scripts\python.exe" - << 'PY'
import torch
print('[CUDA] available =', torch.cuda.is_available())
print('[Device] count    =', torch.cuda.device_count())
print('[Device] name0    =', torch.cuda.get_device_name(0) if torch.cuda.is_available() else None)
PY

# Keep-awake helper
$helper = "$env:USERPROFILE\bin\ai-caffeinate.cmd"
New-Item -ItemType Directory -Force -Path (Split-Path $helper) | Out-Null
Set-Content -Path $helper -Value '@echo off\npowershell -Command Start-Process powercfg -Verb runAs -ArgumentList "/requests" >NUL\npowershell -Command $host.Runspace.Open() >NUL\n%*' -Encoding ASCII
Log "Done. Venv: $venv"
PS1
  echo "[Windows] Generated PowerShell at $PS1_FILE"
  if command -v powershell.exe >/dev/null 2>&1; then
    echo "[Windows] Invoking PowerShell (you may need to approve prompts)"
    powershell.exe -ExecutionPolicy Bypass -File "$PS1_FILE" || true
  else
    echo "[Windows] Please run: powershell -ExecutionPolicy Bypass -File $PS1_FILE"
  fi
}

revert_windows(){
  echo "[Windows] Revert: you may switch power plan back in Control Panel. No global changes persisted by this script."
}

# ---------------------- dispatch ----------------------

if [[ $REVERT -eq 1 ]]; then
  case "$OS" in
    Darwin) revert_macos ;;
    Linux)  revert_linux ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT) revert_windows ;;
    *) echo "[ERR] Unsupported OS for revert: $OS" ;;
  esac
else
  case "$OS" in
    Darwin) apply_macos ;;
    Linux)  apply_linux ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT) apply_windows ;;
    *) echo "[ERR] Unsupported OS: $OS"; exit 2 ;;
  esac
fi

END_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "=== ai_workstation_bootstrap end @ $END_TS ===\nLog: $LOG_FILE\nModels: $MODELS_DIR\nVenv: $VENV_DIR"
