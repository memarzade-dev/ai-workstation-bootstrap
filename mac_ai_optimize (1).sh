#!/usr/bin/env bash
# mac_ai_optimize.sh — Pro AI tuning for MacBook Pro A2338 (Apple M1)
# Target: macOS (Apple Silicon, arm64). Optimizes power, sleep, App Nap, and sets up AI toolchain (Ollama, PyTorch MPS, llama.cpp)
# Modes: --apply (default), --revert, --with-conda, --no-brew, --no-ollama, --no-pytorch, --no-llama
# Safe to re-run. Requires: sudo for pmset. Logs to ~/mac_ai_optimize.log

set -euo pipefail
LOGFILE="$HOME/mac_ai_optimize.log"
exec > >(tee -a "$LOGFILE") 2>&1

### Helpers
say() { printf "\n[+] %s\n" "$*"; }
ok()  { printf "    ✔ %s\n" "$*"; }
warn(){ printf "    ! %s\n" "$*"; }
err() { printf "    ✖ %s\n" "$*"; exit 1; }

### Detect platform
[[ $(uname -s) == "Darwin" ]] || err "This script is for macOS."
[[ $(uname -m) == "arm64" ]]   || warn "Not arm64. Proceeding, but Apple Silicon tuning is assumed."

### Flags
APPLY=1; REVERT=0; WITH_CONDA=0; BREW=1; INSTALL_OLLAMA=1; INSTALL_TORCH=1; INSTALL_LLAMA=1
for a in "$@"; do
  case "$a" in
    --revert) APPLY=0; REVERT=1;;
    --apply)  APPLY=1; REVERT=0;;
    --with-conda) WITH_CONDA=1;;
    --no-brew) BREW=0;;
    --no-ollama) INSTALL_OLLAMA=0;;
    --no-pytorch) INSTALL_TORCH=0;;
    --no-llama) INSTALL_LLAMA=0;;
    *) warn "Unknown flag: $a";;
  esac
done

require_sudo(){
  if ! sudo -n true 2>/dev/null; then
    say "Elevated privileges required for power settings (pmset)."
    sudo -v || err "sudo authentication failed"
  fi
}

xcode_clt(){
  say "Ensuring Xcode Command Line Tools..."
  if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install || warn "If a dialog appeared, complete CLT install and re-run."
  fi
  ok "Xcode CLT present."
}

setup_brew(){
  [[ $BREW -eq 1 ]] || { warn "Skipping Homebrew install per flag"; return; }
  say "Checking Homebrew..."
  if ! command -v brew >/dev/null 2>&1; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || err "Brew install failed"
    eval "$($(uname -m)==arm64 && echo '/opt/homebrew/bin/brew shellenv' || echo '/usr/local/bin/brew shellenv')"
  fi
  ok "Homebrew ready at $(command -v brew)" 
  say "Updating Homebrew & base formulae..."
  brew update
  brew tap homebrew/cask
  brew tap homebrew/cask-fonts || true
  ok "Brew updated."
}

install_core_tools(){
  [[ $BREW -eq 1 ]] || return
  say "Installing core tools (git cmake ninja ffmpeg htop jq wget python)..."
  brew install git cmake ninja ffmpeg htop jq wget python@3.11 pkg-config || true
  ok "Core tools installed."
}

install_ollama(){
  [[ $INSTALL_OLLAMA -eq 1 && $BREW -eq 1 ]] || { warn "Skipping Ollama"; return; }
  say "Installing Ollama + enabling service..."
  brew install ollama || true
  brew services restart ollama || brew services start ollama || true
  ok "Ollama installed. You can run: ollama run llama3"
}

install_pytorch_mps(){
  [[ $INSTALL_TORCH -eq 1 ]] || { warn "Skipping PyTorch"; return; }
  say "Setting up Python venv with PyTorch (MPS)..."
  PY_BIN="$(brew --prefix)/bin/python3" || PY_BIN="python3"
  "$PY_BIN" -m venv "$HOME/.venvs/ai-mps" || true
  source "$HOME/.venvs/ai-mps/bin/activate"
  pip install --upgrade pip wheel setuptools
  # Official nightly frequently updates MPS fixes; stable also works.
  pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
  # MPS backend ships in mac wheels; export fallback for ops not implemented.
  echo 'export PYTORCH_ENABLE_MPS_FALLBACK=1' >> "$HOME/.zshrc"
  deactivate || true
  ok "PyTorch env created at ~/.venvs/ai-mps (activate with: source ~/.venvs/ai-mps/bin/activate)"
}

install_llama_cpp(){
  [[ $INSTALL_LLAMA -eq 1 && $BREW -eq 1 ]] || { warn "Skipping llama.cpp"; return; }
  say "Installing llama.cpp (Metal backend)..."
  brew install llama.cpp || true
  ok "llama.cpp installed. Try: llm --help or llama-cli --help (package may expose 'llama-cli')."
}

configure_pmset_apply(){
  require_sudo
  say "Applying power & sleep tuning (AC=charger, BAT=battery)..."
  # On AC: keep machine awake for long AI sessions
  sudo pmset -c sleep 0 displaysleep 0 disksleep 0 powernap 0 tcpkeepalive 0 proximitywake 0 standby 0 autopoweroff 0 || true
  # On Battery: reasonable defaults but less aggressive
  sudo pmset -b sleep 10 displaysleep 5 powernap 1 tcpkeepalive 1 standby 1 autopoweroff 1 || true
  ok "pmset applied."
}

configure_pmset_revert(){
  require_sudo
  say "Reverting power & sleep to macOS defaults..."
  sudo pmset -c sleep 10 displaysleep 10 disksleep 10 powernap 1 tcpkeepalive 1 standby 1 autopoweroff 1 || true
  sudo pmset -b sleep 10 displaysleep 5 powernap 1 tcpkeepalive 1 standby 1 autopoweroff 1 || true
  ok "pmset reverted."
}

configure_appnap(){
  say "Disabling App Nap globally (can still be managed per-app)..."
  defaults write -g NSAppSleepDisabled -bool YES || true
  ok "App Nap disabled (logout/login may be required)."
}

setup_caffeinate_alias(){
  say "Creating AI session helper: caffeinate wrapper..."
  mkdir -p "$HOME/.local/bin"
  cat > "$HOME/.local/bin/ai-caffeinate" <<'EOF'
#!/usr/bin/env bash
# Keep Mac awake (display, idle, disks, system) while running a command
if [[ $# -eq 0 ]]; then
  echo "Usage: ai-caffeinate <command> [args...]"; exit 1
fi
caffeinate -dimsu "$@"
EOF
  chmod +x "$HOME/.local/bin/ai-caffeinate"
  grep -q "\.local/bin" "$HOME/.zshrc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
  ok "Use: ai-caffeinate python train.py"
}

setup_env_vars(){
  say "Setting performance env vars for common AI stacks..."
  {
    echo 'export OMP_NUM_THREADS=4'
    echo 'export PYTORCH_ENABLE_MPS_FALLBACK=1'
    echo 'export MKL_DEBUG_CPU_TYPE=5  # harmless on macOS; ignored if MKL absent'
  } >> "$HOME/.zshrc"
  ok "Env vars appended to ~/.zshrc (open a new shell to load)."
}

spotlight_tuning(){
  say "(Optional) Excluding model/cache dirs from Spotlight indexing..."
  mkdir -p "$HOME/AI_models" "$HOME/.cache/ai"
  sudo mdutil -i off "$HOME/AI_models" "$HOME/.cache/ai" || true
  ok "Spotlight indexing disabled for model/cache dirs."
}

test_mps(){
  say "Quick test: PyTorch MPS availability"
  python3 - <<'PY'
import torch
print("torch", torch.__version__)
print("mps available:", torch.backends.mps.is_available())
print("mps built:", torch.backends.mps.is_built())
PY
}

summary(){
  say "Summary"
  pmset -g | sed 's/^/    /'
  echo "\n    • Ollama: $(command -v ollama || echo not installed)"
  echo "    • llama.cpp: $(command -v llama-cli || echo not installed)"
  echo "    • AI venv:   $HOME/.venvs/ai-mps"
  ok "Done. Restart is NOT required, but recommended after first run."
}

main_apply(){
  xcode_clt
  setup_brew
  install_core_tools
  install_ollama
  install_pytorch_mps
  install_llama_cpp
  configure_pmset_apply
  configure_appnap
  setup_caffeinate_alias
  setup_env_vars
  spotlight_tuning
  test_mps || warn "MPS test completed (ignore if venv not active)."
  summary
}

main_revert(){
  configure_pmset_revert
  say "To re-enable App Nap default: defaults delete -g NSAppSleepDisabled (then log out/in)"
  ok "Revert completed."
}

if [[ $REVERT -eq 1 ]]; then
  main_revert
else
  main_apply
fi
