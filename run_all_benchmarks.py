#!/usr/bin/env python3
"""
run_all_benchmarks.py — Aggregate runner for AI Workstation benchmarks
Version 3.0.0 | Author: memarzade-dev

What it does
------------
• Collects detailed system info (OS, Python, Torch, CUDA/MPS, CPU/RAM, GPU list)
• Runs matrix multiplication benchmark (4k×4k by default) on CUDA/MPS/CPU
• Captures GPU and system memory stats
• Saves structured outputs to JSON and CSV (one row per run) under benchmarks/results/
• Safe on systems without GPU (falls back to CPU)

Usage
-----
python benchmarks/run_all_benchmarks.py \
  --device auto|cuda|mps|cpu \
  --size 4096 \
  --runs 3 \
  --outdir benchmarks/results \
  --pretty

Outputs
-------
benchmarks/results/
  ├── <timestamp>_summary.json     # all data (system + memory + bench)
  ├── <timestamp>_bench.csv        # per-run timing/gflops
  └── <timestamp>_system.csv       # key/value snapshot
"""
import argparse
import csv
import json
import os
import platform
import sys
import time
from dataclasses import asdict, dataclass
from datetime import datetime
from typing import Any, Dict, List, Optional

# Optional deps
try:
    import torch  # type: ignore
except Exception as e:
    print("[FATAL] PyTorch is not installed:", e)
    sys.exit(1)

try:
    import psutil  # type: ignore
except Exception as e:
    print("[WARN] psutil not available — system RAM/disk/network stats will be limited:", e)
    psutil = None  # type: ignore

# --------------------------- Helpers ---------------------------

def ts() -> str:
    return datetime.utcnow().strftime("%Y-%m-%dT%H-%M-%SZ")


def bytes_to_gb(n: int) -> float:
    return round(n / (1024 ** 3), 2)


# --------------------------- Data classes ---------------------------

@dataclass
class GPUInfo:
    name: str
    memory_gb: Optional[float]
    capability: Optional[str]


@dataclass
class SystemSnapshot:
    timestamp: str
    os: str
    os_release: str
    arch: str
    python: str
    torch: str
    cuda_available: bool
    mps_available: bool
    cuda_version: Optional[str]
    cpu_logical: Optional[int]
    cpu_physical: Optional[int]
    ram_total_gb: Optional[float]
    ram_available_gb: Optional[float]
    gpus: List[GPUInfo]


@dataclass
class BenchRun:
    run_idx: int
    device: str
    size: int
    time_s: float
    gflops: float


@dataclass
class BenchSummary:
    device: str
    size: int
    runs: int
    times_s: List[float]
    gflops: List[float]
    time_avg_s: float
    time_best_s: float
    gflops_avg: float
    gflops_best: float


# --------------------------- Probes ---------------------------

def get_gpus() -> List[GPUInfo]:
    gpus: List[GPUInfo] = []
    try:
        if torch.cuda.is_available():
            for i in range(torch.cuda.device_count()):
                p = torch.cuda.get_device_properties(i)
                gpus.append(GPUInfo(name=p.name, memory_gb=round(p.total_memory/(1024**3),2), capability=f"{p.major}.{p.minor}"))
        elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
            gpus.append(GPUInfo(name="Apple MPS (Metal)", memory_gb=None, capability=None))
    except Exception as e:
        gpus.append(GPUInfo(name=f"<error: {e}", memory_gb=None, capability=None))
    return gpus


def get_system_snapshot() -> SystemSnapshot:
    ram_total = ram_avail = None
    cpu_logical = cpu_physical = None
    if psutil:
        try:
            vm = psutil.virtual_memory()
            ram_total = bytes_to_gb(vm.total)
            ram_avail = bytes_to_gb(vm.available)
        except Exception:
            pass
        try:
            cpu_logical = psutil.cpu_count(logical=True)
            cpu_physical = psutil.cpu_count(logical=False)
        except Exception:
            pass

    # CUDA version through torch (more reliable than nvcc presence on many setups)
    cuda_ver = getattr(torch.version, "cuda", None)

    return SystemSnapshot(
        timestamp=datetime.utcnow().isoformat()+"Z",
        os=platform.system(),
        os_release=platform.release(),
        arch=platform.machine(),
        python=sys.version.split()[0],
        torch=torch.__version__,
        cuda_available=torch.cuda.is_available(),
        mps_available=getattr(torch.backends.mps, "is_available", lambda: False)(),
        cuda_version=cuda_ver,
        cpu_logical=cpu_logical,
        cpu_physical=cpu_physical,
        ram_total_gb=ram_total,
        ram_available_gb=ram_avail,
        gpus=get_gpus(),
    )


def pick_device(pref: str) -> torch.device:
    pref = pref.lower()
    if pref != "auto":
        return torch.device(pref)
    if torch.cuda.is_available():
        return torch.device("cuda")
    if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
        return torch.device("mps")
    return torch.device("cpu")


def torch_matmul_bench(device: torch.device, size: int, runs: int) -> BenchSummary:
    # Allocate once
    a = torch.randn((size, size), device=device)
    b = torch.randn((size, size), device=device)

    # Warm-up (important for CUDA kernels & MPS JIT)
    for _ in range(2):
        _ = a @ b
        if device.type == "cuda":
            torch.cuda.synchronize()

    times: List[float] = []
    gfs: List[float] = []

    for r in range(runs):
        start = time.time()
        _ = a @ b
        if device.type == "cuda":
            torch.cuda.synchronize()
        end = time.time()
        t = end - start
        # FLOPs ~ 2*N^3 for matmul of square matrices
        gflops = (2 * (size ** 3)) / (t * 1e9)
        times.append(t)
        gfs.append(gflops)

    return BenchSummary(
        device=str(device),
        size=size,
        runs=runs,
        times_s=times,
        gflops=gfs,
        time_avg_s=sum(times)/len(times),
        time_best_s=min(times),
        gflops_avg=sum(gfs)/len(gfs),
        gflops_best=max(gfs),
    )


def gpu_memory_stats() -> Dict[str, Any]:
    if torch.cuda.is_available():
        free, total = torch.cuda.mem_get_info()
        return {
            "backend": "cuda",
            "free_gb": bytes_to_gb(free),
            "total_gb": bytes_to_gb(total),
            "device_count": torch.cuda.device_count(),
            "devices": [torch.cuda.get_device_name(i) for i in range(torch.cuda.device_count())],
        }
    elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
        return {"backend": "mps", "note": "Metal reports shared memory; exact free/total not available"}
    else:
        return {"backend": "cpu", "note": "No accelerator detected"}


# --------------------------- I/O helpers ---------------------------

def ensure_dir(p: str) -> None:
    os.makedirs(p, exist_ok=True)


def write_json(path: str, obj: Any, pretty: bool=False) -> None:
    with open(path, "w", encoding="utf-8") as f:
        if pretty:
            json.dump(obj, f, indent=2, ensure_ascii=False)
        else:
            json.dump(obj, f, separators=(",", ":"), ensure_ascii=False)


def write_system_csv(path: str, snap: SystemSnapshot) -> None:
    # flatten to key/value
    rows = []
    d = asdict(snap)
    for k, v in d.items():
        if k == "gpus":
            for idx, g in enumerate(v):
                for gk, gv in g.items():
                    rows.append({"key": f"gpu[{idx}].{gk}", "value": gv})
        else:
            rows.append({"key": k, "value": v})
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["key", "value"])
        w.writeheader()
        w.writerows(rows)


def write_bench_csv(path: str, runs: List[BenchRun]) -> None:
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["run_idx", "device", "size", "time_s", "gflops"])
        w.writeheader()
        for r in runs:
            w.writerow(asdict(r))


# --------------------------- Main ---------------------------

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--device", default="auto", choices=["auto", "cuda", "mps", "cpu"]) 
    ap.add_argument("--size", type=int, default=4096)
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--outdir", default="benchmarks/results")
    ap.add_argument("--pretty", action="store_true")
    args = ap.parse_args()

    ensure_dir(args.outdir)
    stamp = ts()

    # 1) snapshot
    snap = get_system_snapshot()

    # 2) choose device and run bench
    device = pick_device(args.device)
    summary = torch_matmul_bench(device=device, size=args.size, runs=args.runs)

    # 3) memory stats
    mem = gpu_memory_stats()

    # 4) compose report
    bench_runs: List[BenchRun] = [
        BenchRun(run_idx=i+1, device=summary.device, size=summary.size, time_s=summary.times_s[i], gflops=summary.gflops[i])
        for i in range(summary.runs)
    ]

    report: Dict[str, Any] = {
        "timestamp": datetime.utcnow().isoformat()+"Z",
        "system": asdict(snap),
        "memory": mem,
        "bench": {
            "device": summary.device,
            "size": summary.size,
            "runs": summary.runs,
            "time_avg_s": summary.time_avg_s,
            "time_best_s": summary.time_best_s,
            "gflops_avg": summary.gflops_avg,
            "gflops_best": summary.gflops_best,
            "per_run": [asdict(r) for r in bench_runs],
        }
    }

    # 5) write files
    json_path = os.path.join(args.outdir, f"{stamp}_summary.json")
    csv_bench_path = os.path.join(args.outdir, f"{stamp}_bench.csv")
    csv_sys_path = os.path.join(args.outdir, f"{stamp}_system.csv")

    write_json(json_path, report, pretty=args.pretty)
    write_bench_csv(csv_bench_path, bench_runs)
    write_system_csv(csv_sys_path, snap)

    # 6) stdout summary
    print("\n=== Benchmark Summary ===")
    print(f"Device     : {summary.device}")
    print(f"Size       : {summary.size} × {summary.size}")
    print(f"Runs       : {summary.runs}")
    print(f"Time avg   : {summary.time_avg_s:.3f} s | best {summary.time_best_s:.3f} s")
    print(f"GFLOPS avg : {summary.gflops_avg:.2f} | best {summary.gflops_best:.2f}")
    print("Outputs    :")
    print("  ", json_path)
    print("  ", csv_bench_path)
    print("  ", csv_sys_path)

if __name__ == "__main__":
    main()
