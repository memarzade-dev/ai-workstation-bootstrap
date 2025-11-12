#!/usr/bin/env python3
"""
memory_check.py — Simple memory allocation test

Allocates tensors to test memory behavior and prints memory usage.
"""

import torch
import psutil


def show_mem(prefix: str = ""):
    vm = psutil.virtual_memory()
    print(f"{prefix} RAM used: {vm.used/(1024**3):.2f} GB / {vm.total/(1024**3):.2f} GB")


def main():
    show_mem("Before")
    x = torch.randn(10000, 10000)
    show_mem("After CPU alloc")
    if torch.cuda.is_available():
        y = torch.randn(10000, 10000, device='cuda')
        show_mem("After CUDA alloc")
        del y
        torch.cuda.empty_cache()
        show_mem("After CUDA free")
    del x
    show_mem("After CPU free")


if __name__ == "__main__":
    main()