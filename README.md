# AI Workstation Benchmark Suite

**Version:** 3.1.0 (Production)

Translations: [Farsi (FA)](docs/README-FA.md) · [Arabic (AR)](docs/README-AR.md) · [Chinese (ZH)](docs/README-ZH.md) · [Russian (RU)](docs/README-RU.md) · [German (DE)](docs/README-DE.md)

This repository contains performance and diagnostic benchmarks for the AI Workstation Bootstrap environment. It validates CUDA/MPS/CPU acceleration and provides reproducible metrics across macOS, Linux, and Windows installations, aligned with the hardened v3.1.0 project structure.

---

## 🧠 Overview

These benchmarks evaluate:

* Matrix multiplication (4k × 4k) performance in PyTorch.
* GPU / MPS availability and speed.
* Memory usage and throughput.
* CPU fallback performance for non-accelerated systems.

---

## 📂 Directory Structure

```
python/
├── benchmarks/
│   ├── torch_bench.py      # Core matrix-multiplication performance test (auto-detects CUDA/MPS/CPU)
│   └── memory_check.py     # Memory allocation test and RAM usage stats
└── system_info.py          # Hardware and environment diagnostics
```

---

## ⚙️ Requirements

Before running, activate your AI environment:

### For pip-venv mode

```bash
source ~/.venvs/ai/bin/activate
```

### For Conda-first mode

```bash
conda activate ai-base     # or ai-llm / ai-vision
```

Install pinned dependencies (recommended):

```bash
pip install -r requirements.txt
```

Alternatively, ensure `torch` and `psutil` are installed at minimum:

```bash
pip install torch psutil
```

---

## 🚀 Quick Start

### Run the primary matrix multiplication benchmark

```bash
python python/benchmarks/torch_bench.py
```

### Measure memory statistics

```bash
python python/benchmarks/memory_check.py
```

### System info and library versions

```bash
python python/system_info.py
```

---

## 📈 Example Output

```
[torch_bench] Running on: cuda (auto-detected)
[torch_bench] Elapsed: 1.82s | c.mean=0.0123
[memory_check] Before RAM used: 8.12 GB / 32.00 GB
[memory_check] After CPU alloc: 9.95 GB / 32.00 GB
[system_info] OS: Ubuntu 24.04 | Arch: x86_64 | Python: 3.11
[system_info] Torch: 2.x | CUDA Available: True | MPS Available: False
```

On macOS (MPS backend):

```
[torch_bench] Running on: mps
Matmul 4k×4k completed in 2.43 s (CPU fallback ran automatically if MPS unavailable)
```

---

## 📊 Metrics Interpretation

| Metric   | Description                                            |
| -------- | ------------------------------------------------------ |
| Time (s) | Execution time for one 4k×4k matrix multiplication     |
| GFLOPS   | Billion floating-point operations per second (approx.) |
| Device   | PyTorch backend used (CUDA / MPS / CPU)                |

---

## 🧪 Extended Benchmarks

Device selection is automatic: the benchmark tries CUDA first (if available), then MPS (macOS), otherwise CPU.

To force CPU-only on a CUDA system:

```bash
CUDA_VISIBLE_DEVICES="" python python/benchmarks/torch_bench.py
```

To run multiple trials, simply invoke the script several times and average the results. Multi-GPU matmul is not implemented in the simple torch_bench.py; for advanced multi-GPU tests, consider extending the script or using PyTorch distributed utilities.

---

## 🧰 Tips

* Run `torch_bench.py` multiple times and average results for accuracy.
* If GPU utilization is low, verify drivers and `nvidia-smi` output.
* On macOS, ensure Metal support is enabled in PyTorch (`torch.backends.mps.is_available()`).
* Disable Spotlight indexing on your models directory to avoid IO bottlenecks.

Optional: Use the hardened bootstrap to prepare your environment quickly:

```bash
bash scripts/bootstraps/ai_workstation_bootstrap_pro.sh
```

For a single command to run and collect all benchmarks, use:

```bash
python python/run_all_benchmarks.py --device auto --size 4096 --runs 3 --outdir benchmarks/results --pretty
```

---

## 🧾 License

MIT License — © 2025 memarzade-dev