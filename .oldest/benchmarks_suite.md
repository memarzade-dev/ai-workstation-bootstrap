### 📊 benchmarks/README.md — AI Workstation Benchmarks (English)

# AI Workstation Benchmark Suite

**Version:** 3.0.0 (Production)

This directory contains performance and diagnostic benchmarks for the AI Workstation Bootstrap environment. The purpose is to validate GPU / MPS / CPU acceleration and provide reproducible metrics across macOS, Linux, and Windows installations.

---

## 🧠 Overview

These benchmarks evaluate:
- Matrix multiplication (4k × 4k) performance in PyTorch.
- GPU / MPS availability and speed.
- Memory usage and throughput.
- CPU fallback performance for non-accelerated systems.

---

## 📂 Directory Structure
```
benchmarks/
├── torch_bench.py          # Core matrix-multiplication performance test
├── memory_check.py         # GPU memory usage & stats
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

Ensure `torch` and `psutil` are installed:
```bash
pip install torch psutil
```

---

## 🚀 Quick Start

### Run the primary matrix multiplication benchmark
```bash
python benchmarks/torch_bench.py --device auto
```

### Measure memory statistics
```bash
python benchmarks/memory_check.py
```

### System info and library versions
```bash
python benchmarks/system_info.py
```

---

## 📈 Example Output
```
[torch_bench] Device: cuda:0 (NVIDIA RTX 4070)
[torch_bench] Matmul 4096x4096: 1.82 sec → 1846 GFLOPS
[memory_check] GPU Memory: 10.8 GB free / 12 GB total
[system_info] OS: Ubuntu 24.04 LTS | CUDA 12.1 | PyTorch 2.9.1
```

On macOS (MPS backend):
```
[torch_bench] Device: mps
[MPS] available = True | built = True
Matmul 4k×4k completed in 2.43 s (CPU fallback: 9.12 s)
```

---

## 📊 Metrics Interpretation

| Metric | Description |
|---------|--------------|
| Time (s) | Execution time for one 4k×4k matrix multiplication |
| GFLOPS | Billion floating-point operations per second (approx.) |
| Device | PyTorch backend used (CUDA / MPS / CPU) |

---

## 🧪 Extended Benchmarks

To compare different backends:
```bash
python benchmarks/torch_bench.py --device cuda
python benchmarks/torch_bench.py --device cpu
python benchmarks/torch_bench.py --device mps
```

For multi-GPU testing:
```bash
CUDA_VISIBLE_DEVICES=0,1 python benchmarks/torch_bench.py --multi-gpu
```

---

## 🧰 Tips

- Run `torch_bench.py` multiple times and average results for accuracy.
- If GPU utilization is low, verify drivers and `nvidia-smi` output.
- On macOS, ensure Metal support is enabled in PyTorch (`torch.backends.mps.is_available()`).
- Disable Spotlight indexing on your models directory to avoid IO bottlenecks.

---

## 🧾 License
MIT License — © 2025 memarzade-dev

---


### 🧮 benchmarks/torch_bench.py — Core PyTorch Benchmark

```python
#!/usr/bin/env python3
"""
torch_bench.py — AI Workstation Matrix Multiplication Benchmark
Version 3.0.0 | Author: memarzade-dev
"""

import argparse
import time
import torch
import platform

parser = argparse.ArgumentParser(description="PyTorch 4k×4k matrix multiplication benchmark.")
parser.add_argument("--device", type=str, default="auto", help="Device: auto, cuda, mps, or cpu")
parser.add_argument("--multi-gpu", action="store_true", help="Enable multi-GPU parallel benchmark")
args = parser.parse_args()

def choose_device():
    if args.device != "auto":
        return torch.device(args.device)
    if torch.cuda.is_available():
        return torch.device("cuda")
    elif torch.backends.mps.is_available():
        return torch.device("mps")
    else:
        return torch.device("cpu")

device = choose_device()
print(f"[torch_bench] Running on device: {device}")

size = 4096
a = torch.randn((size, size), device=device)
b = torch.randn((size, size), device=device)

# Warm-up
for _ in range(2):
    _ = a @ b
    if device.type == 'cuda':
        torch.cuda.synchronize()

# Benchmark
start = time.time()
_ = a @ b
if device.type == 'cuda':
    torch.cuda.synchronize()
end = time.time()

elapsed = end - start
gflops = (2 * size ** 3) / (elapsed * 1e9)

print(f"[torch_bench] Device: {device}")
print(f"[torch_bench] Size: {size}×{size}")
print(f"[torch_bench] Time: {elapsed:.3f}s")
print(f"[torch_bench] Approx. {gflops:.2f} GFLOPS")

if args.multi_gpu and torch.cuda.device_count() > 1:
    print(f"[torch_bench] Multi-GPU mode enabled ({torch.cuda.device_count()} GPUs)")
    from torch.nn.parallel import DataParallel
    model = lambda x, y: x @ y
    dp = DataParallel(model)
    start = time.time()
    _ = dp(a, b)
    torch.cuda.synchronize()
    end = time.time()
    print(f"[torch_bench] Multi-GPU time: {end-start:.3f}s")

print("[torch_bench] Done.")
```

---

### 📟 benchmarks/memory_check.py — GPU Memory Benchmark

```python
#!/usr/bin/env python3
"""
memory_check.py — GPU memory usage diagnostic
Version 3.0.0 | Author: memarzade-dev
"""
import torch
import psutil

def bytes_to_gb(x):
    return round(x / (1024 ** 3), 2)

def show_gpu_info():
    if torch.cuda.is_available():
        free, total = torch.cuda.mem_get_info()
        print(f"[memory_check] GPU Memory: {bytes_to_gb(free)} GB free / {bytes_to_gb(total)} GB total")
        print(f"[memory_check] GPU Count: {torch.cuda.device_count()}")
        for i in range(torch.cuda.device_count()):
            print(f"  - {i}: {torch.cuda.get_device_name(i)}")
    elif torch.backends.mps.is_available():
        print("[memory_check] Using MPS backend (Metal)")
    else:
        print("[memory_check] No GPU detected, using CPU fallback.")

def show_system_memory():
    vm = psutil.virtual_memory()
    print(f"[system_memory] Total: {bytes_to_gb(vm.total)} GB | Free: {bytes_to_gb(vm.available)} GB")

if __name__ == "__main__":
    print("=== memory_check start ===")
    show_gpu_info()
    show_system_memory()
    print("=== memory_check end ===")
```

