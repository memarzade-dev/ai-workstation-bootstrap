### 🧩 benchmarks/system_info.py — System and Environment Diagnostics

#!/usr/bin/env python3
"""
system_info.py — Hardware and Environment Information Reporter
Version 3.0.0 | Author: memarzade-dev

This script prints a detailed overview of the system hardware, OS, GPU devices,
Python environment, and AI library versions to verify correct setup.
"""

import platform
import os
import sys
import torch
import subprocess
import psutil
from datetime import datetime

def get_gpu_info():
    gpus = []
    try:
        if torch.cuda.is_available():
            for i in range(torch.cuda.device_count()):
                props = torch.cuda.get_device_properties(i)
                gpus.append({
                    "name": props.name,
                    "memory": f"{props.total_memory / (1024**3):.2f} GB",
                    "capability": f"{props.major}.{props.minor}"
                })
        elif torch.backends.mps.is_available():
            gpus.append({"name": "Apple MPS (Metal)", "memory": "Shared", "capability": "N/A"})
    except Exception as e:
        gpus.append({"error": str(e)})
    return gpus

def run_cmd(cmd):
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, shell=True, timeout=5)
        return result.stdout.strip()
    except Exception:
        return "N/A"

def get_cuda_version():
    if torch.cuda.is_available():
        try:
            return run_cmd("nvcc --version | grep release") or torch.version.cuda or "Detected via PyTorch"
        except Exception:
            return "Unknown"
    return "N/A"

def get_python_packages():
    try:
        out = run_cmd("pip list | grep -E 'torch|transformers|accelerate|bitsandbytes'")
        return out or "No AI packages detected."
    except Exception:
        return "Cannot fetch package list."

def bytes_to_gb(n):
    return round(n / (1024**3), 2)

def get_memory_info():
    vm = psutil.virtual_memory()
    sm = psutil.swap_memory()
    return {
        "total": f"{bytes_to_gb(vm.total)} GB",
        "available": f"{bytes_to_gb(vm.available)} GB",
        "swap": f"{bytes_to_gb(sm.total)} GB"
    }

def main():
    print("=== System Information Report ===")
    print(f"Timestamp: {datetime.utcnow().isoformat()}Z")
    print(f"OS: {platform.system()} {platform.release()} | Arch: {platform.machine()}")
    print(f"Python: {sys.version.split()[0]}")
    print(f"User: {os.getenv('USER') or os.getenv('USERNAME')}")
    print(f"Working Dir: {os.getcwd()}")
    
    print("\n--- Memory ---")
    mem = get_memory_info()
    for k,v in mem.items():
        print(f"{k.capitalize()}: {v}")

    print("\n--- GPU / Accelerator ---")
    for gpu in get_gpu_info():
        for key,val in gpu.items():
            print(f"{key}: {val}")
        print()

    print("--- CUDA / Backend ---")
    print(f"CUDA Version: {get_cuda_version()}")
    print(f"Torch Version: {torch.__version__}")
    print(f"MPS Available: {torch.backends.mps.is_available() if hasattr(torch.backends,'mps') else 'N/A'}")
    print(f"CUDA Available: {torch.cuda.is_available()}")

    print("\n--- Installed AI Packages ---")
    print(get_python_packages())

    print("\n--- CPU Info ---")
    print(f"Processor: {platform.processor()}")
    print(f"Logical cores: {psutil.cpu_count(logical=True)} | Physical cores: {psutil.cpu_count(logical=False)}")
    print(f"Load Avg: {psutil.getloadavg() if hasattr(psutil,'getloadavg') else 'N/A'}")

    print("\n--- Network Interfaces ---")
    for name, addrs in psutil.net_if_addrs().items():
        print(f"{name}: {', '.join(a.address for a in addrs if a.family.name == 'AF_INET')} ")

    print("\n--- Disk Usage ---")
    for p in psutil.disk_partitions():
        try:
            u = psutil.disk_usage(p.mountpoint)
            print(f"{p.device} {p.mountpoint}: {bytes_to_gb(u.used)} GB used / {bytes_to_gb(u.total)} GB total")
        except PermissionError:
            continue

    print("\n=== End of Report ===")

if __name__ == "__main__":
    main()

