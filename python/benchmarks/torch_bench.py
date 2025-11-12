#!/usr/bin/env python3
"""
torch_bench.py — Quick GPU/CPU matrix multiplication benchmark

Measures throughput of a large matrix multiplication on CPU and, if available,
on CUDA/MPS GPUs. Useful for sanity-checking performance.
"""

import time
import torch


def bench(device: str = "cpu", size: int = 4096):
    print(f"Running torch matmul benchmark on {device} (size={size})...")
    dev = torch.device(device)
    a = torch.randn(size, size, device=dev)
    b = torch.randn(size, size, device=dev)
    torch.cuda.synchronize() if dev.type == 'cuda' else None

    start = time.perf_counter()
    c = a @ b
    torch.cuda.synchronize() if dev.type == 'cuda' else None
    elapsed = time.perf_counter() - start

    print(f"Elapsed: {elapsed:.3f}s | c.mean={c.mean().item():.4f}")


def main():
    bench("cpu")
    if torch.cuda.is_available():
        bench("cuda")
    elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
        bench("mps")


if __name__ == "__main__":
    main()