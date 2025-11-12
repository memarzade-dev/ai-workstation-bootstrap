# 🧠 AI Workstation Bootstrap — Universal Setup Script (v3.0.0)

**Author:** [memarzade-dev](https://github.com/memarzade-dev)
**Supported Systems:** macOS (Intel & Apple Silicon), Linux (Ubuntu, Fedora, Arch), Windows 10/11
**Architectures:** x86_64 / arm64
**License:** MIT
**Version:** 3.0.0 (Production-Ready)

---

## 🌍 Overview

`ai_workstation_bootstrap_pro.sh` is a **universal AI environment bootstrapper** that transforms any macOS, Linux, or Windows system into a ready-to-train workstation for:

* **Large Language Models (LLMs)**
* **Computer Vision / Diffusion / Stable Diffusion**
* **AI Frameworks (PyTorch / Transformers / Ollama / llama.cpp)**

The script auto-detects your OS and hardware, installs the optimal AI stack, and configures your system for safe, high-performance workloads. It’s fully idempotent — you can re-run it anytime without side effects — and supports both **Conda-first** and **pip-venv** environments.

---

## ⚙️ Core Features

| Category              | Description                                                                                      |
| --------------------- | ------------------------------------------------------------------------------------------------ |
| 🔍 Detection          | Auto-detect OS, architecture, GPU (MPS/CUDA/CPU), and available resources                        |
| 🧱 Environment        | Choose between Conda-first (Miniforge) or classic pip-venv                                       |
| 🔌 AI Frameworks      | Installs PyTorch (MPS/CUDA/CPU auto), Transformers, Accelerate, bitsandbytes                     |
| 🧠 LLM Tooling        | Installs Ollama, llama.cpp, and sets GPU flags automatically                                     |
| 💤 Power Optimization | macOS: pmset + App Nap tuning; Linux: power-safe; Windows: High Performance plan                 |
| 🗂 Spotlight          | macOS Spotlight indexing is disabled for model directories with fallback `.metadata_never_index` |
| ☕ Keep Awake          | Adds `ai-caffeinate` helper (`caffeinate` or `systemd-inhibit`)                                  |
| 🔁 Safe Revert        | `--revert` restores all modified settings                                                        |
| 🧩 Multi-env Support  | Create multiple Conda environments (`ai-base`, `ai-llm`, `ai-vision`, etc.)                      |
| 📊 Benchmark Mode     | `--bench` runs a GPU/MPS sanity test and a 4k matmul performance check                           |
| 📜 Full Logging       | All steps logged to `~/ai_workstation_bootstrap_pro.log`                                         |

---

## 🚀 Quick Start

### macOS / Linux

```bash
chmod +x ./ai_workstation_bootstrap_pro.sh
./ai_workstation_bootstrap_pro.sh --bench
```

### Windows

Run via **Git Bash** or **WSL**:

```bash
./ai_workstation_bootstrap_pro.sh
```

The script automatically generates and runs `ai_bootstrap_windows.ps1`.

---

## 🧩 Modes & Examples

### 1. Default (pip-venv)

Creates `~/.venvs/ai` and installs PyTorch + Transformers.

```bash
./ai_workstation_bootstrap_pro.sh
```

### 2. Conda-first with multiple environments

Creates Miniforge and environments for specific domains.

```bash
./ai_workstation_bootstrap_pro.sh --mode conda --envs "ai-base ai-llm ai-vision"
```

### 3. Customize directories

```bash
./ai_workstation_bootstrap_pro.sh --models-dir ~/Models --venv-dir ~/.venvs/ai
```

### 4. Disable certain components

```bash
./ai_workstation_bootstrap_pro.sh --no-ollama --no-llama --no-pytorch
```

### 5. Full revert

```bash
./ai_workstation_bootstrap_pro.sh --revert
```

---

## 🧠 Benchmarks

Run with:

```bash
./ai_workstation_bootstrap_pro.sh --bench
```

### Output Example

```
[GPU] NVIDIA RTX 4070 detected
[CUDA] Version: 12.1 | PyTorch backend: True
[Benchmark] MatMul 4096x4096 → 2125 GFLOPS
```

On macOS:

```
[MPS] available = True
[MPS] built = True
```

---

## 🧮 Environment Details

| OS            | Framework Backend   | Install Method      | Notes                                     |
| ------------- | ------------------- | ------------------- | ----------------------------------------- |
| macOS (ARM)   | MPS (Metal)         | pip or conda        | Automatic MPS fallback                    |
| Linux (x86)   | CUDA (if available) | pip or conda        | Detects NVIDIA driver, installs CUDA 12.1 |
| Linux (ARM64) | CPU                 | pip                 | Fallback CPU build                        |
| Windows       | CUDA or DirectML    | powershell + winget | Requires Python 3.12, NVIDIA driver 535+  |

---

## 📁 Folder Layout

```
~/
├── .venvs/                 # Pip virtual environments
│   └── ai/                 # Default venv (pip mode)
├── miniforge3/             # Conda base installation (if --mode conda)
├── Models/                 # Model cache folder (Spotlight disabled)
├── bin/
│   └── ai-caffeinate       # Keep-awake helper
├── ai_bootstrap_windows.ps1 # Windows equivalent
└── ai_workstation_bootstrap_pro.log
```

---

## 🧰 Command-line Flags

| Flag                      | Description                         |
| ------------------------- | ----------------------------------- |
| `--mode conda`            | Use Conda-first mode (Miniforge)    |
| `--envs "ai-base ai-llm"` | Define Conda environments to create |
| `--models-dir <path>`     | Custom models directory             |
| `--venv-dir <path>`       | Custom pip venv directory           |
| `--no-ollama`             | Skip Ollama installation            |
| `--no-llama`              | Skip llama.cpp installation         |
| `--no-pytorch`            | Skip PyTorch installation           |
| `--revert`                | Restore system defaults             |
| `--bench`                 | Run GPU/MPS sanity and matmul test  |
| `--yes`                   | Non-interactive mode                |
| `--logfile <path>`        | Custom log output path              |

---

## ⚡ Power Management

### macOS

* `pmset` tuned for AI sessions on charger (no sleep).
* `App Nap` globally disabled (`defaults write -g NSAppSleepDisabled -bool YES`).
* Revert resets these to energy-saving defaults.

### Linux

* Leaves system policies unchanged.
* Adds helper `systemd-inhibit` for awake tasks.

### Windows

* Switches Power Plan to “High Performance” temporarily.

---

## 🧰 Benchmark Suite (Optional Extension)

Use the built-in `--bench` flag or run manually:

```bash
source ~/.venvs/ai/bin/activate   # or conda activate ai-llm
python - <<'PY'
import torch, time
a = torch.randn(4096, 4096, device="cuda" if torch.cuda.is_available() else "mps")
b = torch.randn(4096, 4096, device=a.device)
torch.cuda.synchronize() if torch.cuda.is_available() else None
start = time.time(); (a @ b); torch.cuda.synchronize() if torch.cuda.is_available() else None
print(f"Matmul test done in {time.time()-start:.3f}s on {a.device}")
PY
```

---

## 🔐 Security & Revert Safety

* No system files overwritten.
* Modifications (pmset, App Nap, Spotlight) logged and revertible.
* macOS system changes require `sudo`; Linux/Windows do not.
* All environment setups are **per-user** (no root installs).

---

## 🧩 Future Roadmap

* 🪶 Integrate **Ollama Flash Attention** and **KV Cache tuning** (`OLLAMA_KV_CACHE_TYPE=q8_0`)
* 🔁 Optional **Docker** mode for reproducible AI dev environments
* 🔍 Include **nvtop / gpustat / torch.profiler** tools
* 🧬 Benchmark expansion for SD / Whisper / TTS
* 🌐 Remote setup via SSH (multi-node training bootstrap)

---

## 🧑‍💻 Contributing

1. Fork the repo
2. Edit `ai_workstation_bootstrap_pro.sh` or add new platform installers
3. Run locally with `--dry-run` to test
4. Submit PR to `main` branch with changelog notes

---

## 🪄 License

MIT License — freely usable for personal or commercial setups.
Attribution appreciated:
**© 2025 memarzade-dev**