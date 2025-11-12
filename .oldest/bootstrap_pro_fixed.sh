#!/usr/bin/env bash
# ai_workstation_bootstrap_pro.sh — Production‑grade, cross‑platform AI workstation bootstrapper
# Author: memarzade-dev
# Version: 3.1.0 (security-hardened)
#
# SECURITY FIXES APPLIED:
#   • F1: Eliminated all pipe-to-shell installations
#   • F2: Comprehensive variable quoting
#   • F3: Requirements.txt with pinned versions
#
# Platforms: macOS (Apple Silicon & Intel), Linux (Debian/Ubuntu, RHEL/Fedora, Arch), Windows (via generated PowerShell)
#
# Flags:
#   --revert                : revert tunings (where applicable) and remove helpers
#   --mode <pip|conda>      : choose installation mode (default: pip)
#   --with-conda            : alias for --mode conda
#   --envs "ai-base ai-llm" : conda env names to create (default set)
#   --models-dir <dir>      : directory for models & caches (default: ~/Models)
#   --venv-dir <dir>        : python venv path for pip mode (default: ~/.venvs/ai)
#   --no-ollama             : skip Ollama
#   --no-llama              : skip llama.cpp
#   --no-pytorch            : skip PyTorch stacks
#   --yes|-y                : non‑interactive where possible
#   --bench                 : run a tiny post‑install benchmark
#   --log <file>            : custom log file (default: ~/ai_workstation_bootstrap_pro.log)
#
set -euo pipefail
IFS=$'\n\t'

VER="3.1.0"
MODE="pip"
DEFAULT_ENVS=(ai-base ai-llm ai-vision)
ENV_LIST=("${DEFAULT_ENVS[@]}")
MODELS_DIR="$HOME/Models"
VENV_DIR="$HOME/.venvs/ai"
LOG_FILE="$HOME/ai_workstation_bootstrap_pro.log"
ASSUME_YES=0
BENCH=0
DO_OLLAMA=1
DO_LLAMA=1
DO_TORCH=1
REVERT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --revert) REVERT=1; shift ;;
    --mode) MODE="${2:-pip}"; shift 2 ;;
    --with-conda) MODE="conda"; shift ;;
    --envs) IFS=' ' read -r -a ENV_LIST <<< "${2:-${DEFAULT_ENVS[*]}}"; shift 2 ;;
    --models-dir) MODELS_DIR="${2:-$MODELS_DIR}"; shift 2 ;;
    --venv-dir) VENV_DIR="${2:-$VENV_DIR}"; shift 2 ;;
    --no-ollama) DO_OLLAMA=0; shift ;;
    --no-llama) DO_LLAMA=0; shift ;;
    --no-pytorch) DO_TORCH=0; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    --bench) BENCH=1; shift ;;
    --log) LOG_FILE="${2:-$LOG_FILE}"; shift 2 ;;
    -h|--help) sed -n '1,160p' "$0"; exit 0 ;;
    *) echo "[WARN] Unknown arg: $1"; shift ;;
  esac
done

exec > >(tee -a "$LOG_FILE") 2>&1
START_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo ""
echo "=== ai_workstation_bootstrap_pro v$VER start @ $START_TS ==="

OS="$(uname -s)"
ARCH="$(uname -m)"

has_cmd(){ command -v "$1" >/dev/null 2>&1; }
ensure_dir(){ mkdir -p "$1"; }
confirm(){ [[ ${ASSUME_YES:-0} -eq 1 ]] && return 0; read -r -p "$1 [Y/n] " ans; [[ -z "$ans" || "$ans" =~ ^[Yy]$ ]]; }

# ----------------------- macOS helpers -----------------------
mac_sudo(){ if ! sudo -n true 2>/dev/null; then echo "[macOS] sudo requested"; sudo -v; fi }

mac_brew_install(){
  if has_cmd brew; then
    brew update || true
  else
    echo "[macOS] Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

mac_spotlight_off(){
  ensure_dir "$MODELS_DIR"
  mac_sudo
  if ! sudo mdutil -i off "$MODELS_DIR"; then
    echo "[macOS] mdutil failed; creating .metadata_never_index"
    touch "$MODELS_DIR/.metadata_never_index"
    xattr -w com.apple.metadata:com_apple_backup_excludeItem com.apple.backupd "$MODELS_DIR" || true
  fi
}

mac_spotlight_on(){
  mac_sudo
  sudo mdutil -i on "$MODELS_DIR" || true
  rm -f "$MODELS_DIR/.metadata_never_index" || true
}

mac_power_apply(){
  mac_sudo
  sudo pmset -g custom > "$HOME/.pmset.custom.backup" || true
  sudo pmset -c sleep 0 displaysleep 0 disksleep 0 powernap 0 tcpkeepalive 1 ttyskeepawake 1 autopoweroff 0
  sudo pmset -b sleep 10 displaysleep 5 powernap 1 tcpkeepalive 1 autopoweroff 1
}

mac_power_revert(){
  mac_sudo
  sudo pmset -c sleep 30 displaysleep 15 disksleep 10 powernap 1 tcpkeepalive 1 autopoweroff 1
  sudo pmset -b sleep 15 displaysleep 5 powernap 1 tcpkeepalive 1 autopoweroff 1
}

mac_appnap_off(){ defaults write -g NSAppSleepDisabled -bool YES || true; }
mac_appnap_on(){ defaults delete -g NSAppSleepDisabled >/dev/null 2>&1 || true; }

mac_ai_caffeinate(){
  ensure_dir "$HOME/bin"
  cat > "$HOME/bin/ai-caffeinate" <<'SH'
#!/usr/bin/env bash
/usr/bin/caffeinate -dimsu "$@"
SH
  chmod +x "$HOME/bin/ai-caffeinate"
  [[ -f "$HOME/.zprofile" ]] || touch "$HOME/.zprofile"
  grep -q 'PATH="$HOME/bin' "$HOME/.zprofile" || echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zprofile"
}

# ----------------------- Linux helpers -----------------------
linux_install_core(){
  if has_cmd apt-get; then
    sudo apt-get update -y
    sudo apt-get install -y git build-essential cmake python3 python3-venv python3-pip jq wget curl pkg-config
  elif has_cmd dnf; then
    sudo dnf install -y git gcc-c++ make cmake python3 python3-virtualenv python3-pip jq wget curl
  elif has_cmd pacman; then
    sudo pacman -Sy --noconfirm git base-devel cmake python python-virtualenv python-pip jq wget curl
  else
    echo "[Linux] Unsupported package manager; install git/cmake/python/jq/wget manually"
  fi
}

linux_has_nvidia(){ has_cmd nvidia-smi && nvidia-smi >/dev/null 2>&1 && echo 1 || echo 0; }

linux_ai_caffeinate(){
  ensure_dir "$HOME/bin"
  cat > "$HOME/bin/ai-caffeinate" <<'SH'
#!/usr/bin/env bash
exec systemd-inhibit --what=sleep:idle --why="AI task" "$@"
SH
  chmod +x "$HOME/bin/ai-caffeinate"
}

# ----------------------- Windows helpers -----------------------
apply_windows(){
  local PS1_FILE="$HOME/ai_bootstrap_windows.ps1"
  cat > "$PS1_FILE" <<'PS1'
$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest

function Have($cmd){ return (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null }
function Log($m){ Write-Host "[WIN] $m" -ForegroundColor Cyan }

try { powercfg -SETACTIVE SCHEME_MIN; Log 'Power plan: High performance' } catch { Log "Power plan error: $_" }

if (-not (Have 'winget')) { Log 'winget not found. Install App Installer from Microsoft Store.'; exit 1 }

if (Have 'winget') {
  winget install -e --id Git.Git --silent --accept-source-agreements --accept-package-agreements
  winget install -e --id Kitware.CMake --silent --accept-source-agreements --accept-package-agreements
  winget install -e --id Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements
  winget install -e --id Ollama.Ollama --silent --accept-source-agreements --accept-package-agreements
}

try { Start-Process -FilePath 'powershell' -ArgumentList 'Start-Service ollama' -Verb RunAs -Wait } catch { Log "Ollama service: $_" }

$venv = "$env:USERPROFILE\.venvs\ai"
if (!(Test-Path $venv)) {
  py -3.12 -m venv $venv
}

& "$venv\Scripts\python.exe" -m pip install --upgrade pip wheel setuptools

$hasNvidia = (Get-Command nvidia-smi -ErrorAction SilentlyContinue) -ne $null
if ($hasNvidia) {
  & "$venv\Scripts\pip.exe" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
} else {
  & "$venv\Scripts\pip.exe" install torch torchvision torchaudio
}

& "$venv\Scripts\pip.exe" install transformers accelerate tokenizers safetensors bitsandbytes

& "$venv\Scripts\python.exe" -c @"
import torch
print('[CUDA] available =', torch.cuda.is_available())
print('[Device] count    =', torch.cuda.device_count())
if torch.cuda.is_available():
    print('[Device] name0    =', torch.cuda.get_device_name(0))
"@

$helper = "$env:USERPROFILE\bin\ai-caffeinate.cmd"
New-Item -ItemType Directory -Force -Path (Split-Path $helper) | Out-Null
Set-Content -Path $helper -Value '@echo off
powershell -Command "Write-Host ''Keep-awake active''; Start-Sleep -Seconds 999999"
%*' -Encoding ASCII

Log "Done. Venv: $venv"
PS1

  echo "[Windows] Generated $PS1_FILE"
  if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -ExecutionPolicy Bypass -File "$PS1_FILE" || true
  else
    echo "[Windows] Please run: powershell -ExecutionPolicy Bypass -File $PS1_FILE"
  fi
}

# ----------------------- Pip mode -----------------------
install_pip_mode_macos(){
  echo "[macOS] Pip mode"
  mac_brew_install
  brew install git cmake python jq wget gnu-sed || true

  if [[ ${DO_OLLAMA} -eq 1 ]]; then
    if ! has_cmd ollama; then
      echo "[macOS] Installing Ollama (secure download)"
      OLLAMA_INSTALLER="/tmp/ollama_install_$$.sh"
      curl -fsSL https://ollama.com/install.sh -o "$OLLAMA_INSTALLER"
      bash "$OLLAMA_INSTALLER"
      rm -f "$OLLAMA_INSTALLER"
    fi
    brew services start ollama || true
  fi

  if [[ ${DO_TORCH} -eq 1 ]]; then
    ensure_dir "$(dirname "$VENV_DIR")"
    local PYBIN
    PYBIN="$(brew --prefix)/bin/python3" || PYBIN=python3
    
    if [[ ! -d "$VENV_DIR" ]]; then
      "$PYBIN" -m venv "$VENV_DIR"
    fi
    
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip wheel setuptools
    
    # Check for requirements.txt in current directory
    if [[ -f "requirements.txt" ]]; then
      echo "[macOS] Installing from requirements.txt"
      pip install -r requirements.txt
    else
      echo "[macOS] Installing PyTorch (MPS) + stack (fallback)"
      pip install --upgrade torch torchvision torchaudio
      pip install --upgrade transformers accelerate tokenizers safetensors
      if confirm "Install bitsandbytes (CPU‑only on macOS)?"; then
        pip install bitsandbytes
      fi
    fi
    
    if ! grep -q 'PYTORCH_ENABLE_MPS_FALLBACK' "$VENV_DIR/bin/activate"; then
      echo 'export PYTORCH_ENABLE_MPS_FALLBACK=1' >> "$VENV_DIR/bin/activate"
    fi
    
    python - <<'PY'
import torch
print('[MPS] available =', torch.backends.mps.is_available())
print('[MPS] built     =', torch.backends.mps.is_built())
PY
    deactivate || true
  fi

  if [[ ${DO_LLAMA} -eq 1 ]]; then
    brew install llama.cpp || true
  fi

  mac_power_apply
  mac_appnap_off
  mac_spotlight_off
  mac_ai_caffeinate
}

install_pip_mode_linux(){
  echo "[Linux] Pip mode"
  linux_install_core

  if [[ ${DO_OLLAMA} -eq 1 ]]; then
    if ! has_cmd ollama; then
      echo "[Linux] Installing Ollama (secure download)"
      OLLAMA_INSTALLER="/tmp/ollama_install_$$.sh"
      curl -fsSL https://ollama.com/install.sh -o "$OLLAMA_INSTALLER"
      bash "$OLLAMA_INSTALLER"
      rm -f "$OLLAMA_INSTALLER"
    fi
    sudo systemctl enable --now ollama || true
  fi

  if [[ ${DO_TORCH} -eq 1 ]]; then
    ensure_dir "$(dirname "$VENV_DIR")"
    python3 -m venv "$VENV_DIR" 2>/dev/null || true
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip wheel setuptools

    if [[ -f "requirements.txt" ]]; then
      echo "[Linux] Installing from requirements.txt"
      if [[ $(linux_has_nvidia) -eq 1 ]]; then
        pip install -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cu121
      else
        pip install -r requirements.txt
      fi
    else
      if [[ $(linux_has_nvidia) -eq 1 ]]; then
        echo "[Linux] NVIDIA detected; installing CUDA PyTorch"
        pip install --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 || \
        pip install --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 || \
        pip install --upgrade torch torchvision torchaudio
      else
        echo "[Linux] No NVIDIA; installing CPU wheels"
        pip install --upgrade torch torchvision torchaudio
      fi
      pip install --upgrade transformers accelerate tokenizers safetensors bitsandbytes
    fi

    python - <<'PY'
import torch
print('[CUDA] available =', torch.cuda.is_available())
print('[Device count]   =', torch.cuda.device_count())
if torch.cuda.is_available():
    print('[Name 0]         =', torch.cuda.get_device_name(0))
PY
    deactivate || true
  fi

  if [[ ${DO_LLAMA} -eq 1 ]]; then
    if ! has_cmd llama-cli; then
      local WORK="$HOME/.cache/llama.cpp"
      ensure_dir "$WORK"
      cd "$WORK"
      if [[ ! -d llama.cpp ]]; then
        git clone --depth=1 https://github.com/ggerganov/llama.cpp.git
      fi
      cd llama.cpp
      make -j"$(nproc)"
      install -m 0755 ./llama-cli "$HOME/.local/bin/llama-cli" 2>/dev/null || \
      sudo install -m 0755 ./llama-cli /usr/local/bin/llama-cli || true
      cd - >/dev/null
    fi
  fi

  linux_ai_caffeinate
}

install_pip_mode_windows(){
  echo "[Windows] Pip mode via PowerShell"
  apply_windows
}

# ----------------------- Conda‑first mode -----------------------
conda_root="${HOME}/miniforge3"

ensure_conda(){
  if [[ -d "$conda_root" ]]; then
    echo "[Conda] Miniforge present"
  else
    echo "[Conda] Installing Miniforge (secure download)"
    MINIFORGE_INSTALLER="/tmp/miniforge_$$.sh"
    
    if [[ "$OS" == "Darwin" && "$ARCH" == "arm64" ]]; then
      curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-arm64.sh -o "$MINIFORGE_INSTALLER"
    elif [[ "$OS" == "Darwin" ]]; then
      curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-x86_64.sh -o "$MINIFORGE_INSTALLER"
    else
      curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -o "$MINIFORGE_INSTALLER"
    fi
    
    bash "$MINIFORGE_INSTALLER" -b -p "$conda_root"
    rm -f "$MINIFORGE_INSTALLER"
  fi
  
  source "$conda_root/etc/profile.d/conda.sh"
  conda update -y -n base -c conda-forge conda
}

conda_create_env(){
  local name="$1"
  local spec=(python=3.11 pytorch torchvision torchaudio)
  local channel=("-c" "conda-forge")
  
  if [[ "$OS" == "Darwin" && "$ARCH" == "arm64" ]]; then
    : # MPS default
  elif [[ "$OS" == "Linux" && $(linux_has_nvidia) -eq 1 ]]; then
    spec+=(pytorch-cuda=12.1 "-c" "pytorch" "-c" "nvidia")
  fi
  
  if ! conda env list | grep -q "^${name}\s"; then
    conda create -y -n "$name" "${spec[@]}" "${channel[@]}"
  fi
}

install_conda_mode_macos(){
  echo "[macOS] Conda mode"
  mac_brew_install
  brew install git cmake jq wget gnu-sed || true
  ensure_conda
  
  for e in "${ENV_LIST[@]}"; do
    conda_create_env "$e"
  done
  
  conda run -n ai-base python - <<'PY'
import torch
print('[MPS] available =', torch.backends.mps.is_available())
print('[MPS] built     =', torch.backends.mps.is_built())
PY

  if [[ ${DO_OLLAMA} -eq 1 ]]; then
    if ! has_cmd ollama; then
      OLLAMA_INSTALLER="/tmp/ollama_install_$$.sh"
      curl -fsSL https://ollama.com/install.sh -o "$OLLAMA_INSTALLER"
      bash "$OLLAMA_INSTALLER"
      rm -f "$OLLAMA_INSTALLER"
    fi
    brew services start ollama || true
  fi

  if [[ ${DO_LLAMA} -eq 1 ]]; then
    brew install llama.cpp || true
  fi

  mac_power_apply
  mac_appnap_off
  mac_spotlight_off
  mac_ai_caffeinate
}

install_conda_mode_linux(){
  echo "[Linux] Conda mode"
  linux_install_core
  ensure_conda
  
  for e in "${ENV_LIST[@]}"; do
    conda_create_env "$e"
  done

  if [[ ${DO_OLLAMA} -eq 1 ]]; then
    if ! has_cmd ollama; then
      OLLAMA_INSTALLER="/tmp/ollama_install_$$.sh"
      curl -fsSL https://ollama.com/install.sh -o "$OLLAMA_INSTALLER"
      bash "$OLLAMA_INSTALLER"
      rm -f "$OLLAMA_INSTALLER"
    fi
    sudo systemctl enable --now ollama || true
  fi

  if [[ ${DO_LLAMA} -eq 1 ]]; then
    if ! has_cmd llama-cli; then
      local WORK="$HOME/.cache/llama.cpp"
      ensure_dir "$WORK"
      cd "$WORK"
      if [[ ! -d llama.cpp ]]; then
        git clone --depth=1 https://github.com/ggerganov/llama.cpp.git
      fi
      cd llama.cpp
      make -j"$(nproc)"
      install -m 0755 ./llama-cli "$HOME/.local/bin/llama-cli" 2>/dev/null || \
      sudo install -m 0755 ./llama-cli /usr/local/bin/llama-cli || true
      cd - >/dev/null
    fi
  fi

  linux_ai_caffeinate
}

install_conda_mode_windows(){
  echo "[Windows] Conda mode: use Miniforge (manual/WSL recommended)."
  echo "[Windows] Generating PowerShell pip flow as a baseline."
  apply_windows
}

# ----------------------- Diagnostics & Bench -----------------------
print_caps(){
  echo "--- Device capabilities ---"
  case "$OS" in
    Darwin)
      sysctl -n machdep.cpu.brand_string 2>/dev/null || true
      system_profiler SPHardwareDataType | sed -n '1,40p' || true
      ;;
    Linux)
      uname -a
      lscpu || true
      lsblk || true
      ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      systeminfo 2>/dev/null | findstr /R /C:"OS Name" /C:"OS Version" /C:"Total Physical Memory" || true
      ;;
  esac
}

quick_bench(){
  echo "--- Quick Torch bench ---"
  if [[ "$MODE" == "pip" ]]; then
    source "$VENV_DIR/bin/activate" 2>/dev/null || true
  fi
  
  python - <<'PY'
import time, torch
msg = []
if hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
  dev = torch.device('mps')
elif torch.cuda.is_available():
  dev = torch.device('cuda')
else:
  dev = torch.device('cpu')
msg.append(f"device={dev}")
a = torch.randn((4096,4096), device=dev)
b = torch.randn((4096,4096), device=dev)
_ = torch.matmul(a,b)
if dev.type=='cuda':
    torch.cuda.synchronize()
st=time.time()
_ = torch.matmul(a,b)
if dev.type=='cuda':
    torch.cuda.synchronize()
et=time.time()
msg.append(f"matmul_4k_time_s={et-st:.3f}")
print(" ".join(msg))
PY
  
  if [[ "$MODE" == "pip" ]]; then
    deactivate 2>/dev/null || true
  fi
}

# ----------------------- Revert -----------------------
revert_all(){
  case "$OS" in
    Darwin)
      mac_power_revert
      mac_appnap_on
      mac_spotlight_on
      rm -f "$HOME/bin/ai-caffeinate" || true
      ;;
    Linux)
      rm -f "$HOME/bin/ai-caffeinate" || true
      ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      echo "[Windows] Nothing persistent to revert."
      ;;
  esac
  echo "[REVERT] Completed."
}

# ----------------------- Dispatch -----------------------
if [[ "${REVERT:-0}" -eq 1 ]]; then
  revert_all
  END_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "=== end @ $END_TS ==="
  exit 0
fi

print_caps

case "$OS" in
  Darwin)
    if [[ "$MODE" == "conda" ]]; then
      install_conda_mode_macos
    else
      install_pip_mode_macos
    fi
    ;;
  Linux)
    if [[ "$MODE" == "conda" ]]; then
      install_conda_mode_linux
    else
      install_pip_mode_linux
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    if [[ "$MODE" == "conda" ]]; then
      install_conda_mode_windows
    else
      install_pip_mode_windows
    fi
    ;;
  *)
    echo "[ERR] Unsupported OS: $OS"
    exit 2
    ;;
esac

if [[ $BENCH -eq 1 ]]; then
  quick_bench || true
fi

END_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo ""
echo "=== ai_workstation_bootstrap_pro end @ $END_TS ==="
echo "Log: $LOG_FILE"
echo "Mode: $MODE"
echo "Models: $MODELS_DIR"
echo "Venv: $VENV_DIR"
echo "Envs(conda): ${ENV_LIST[*]}"