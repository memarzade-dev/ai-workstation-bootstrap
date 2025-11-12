#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
System Audit with Self-Installer
--------------------------------
• Cross‑platform: Windows, macOS, Linux
• Generates a single CSV (`system_audit.csv`) with rich records
• Auto‑installs required Python packages (psutil; wmi on Windows)

Schema (CSV columns):
category, key, name, value, unit, extra

Run:
  python system_audit_installer.py

Notes:
- Uses only stdlib + psutil (+ wmi on Windows) and system commands.
- No admin is strictly required; privileged data gracefully degrades.
"""

from __future__ import annotations
import csv
import json
import os
import platform
import shutil
import socket
import subprocess
import sys
import time
from datetime import datetime
from typing import Dict, Any, List, Tuple

# -----------------------------
# Self-installer for dependencies
# -----------------------------
REQUIRED = ["psutil"]
if platform.system() == "Windows":
    REQUIRED.append("wmi")


def ensure_packages(packages: List[str]) -> None:
    py = sys.executable
    for pkg in packages:
        try:
            __import__(pkg)
        except Exception:
            print(f"[installer] Installing missing package: {pkg} ...")
            try:
                subprocess.check_call([py, "-m", "pip", "install", "--upgrade", pkg])
            except Exception as e:
                print(f"[installer] WARNING: Failed to install {pkg}: {e}")
                # Continue; collectors will handle missing modules gracefully.


ensure_packages(REQUIRED)

# Safe imports after attempted install
try:
    import psutil  # type: ignore
except Exception:
    psutil = None  # type: ignore

try:
    import wmi  # type: ignore
except Exception:
    wmi = None  # type: ignore

# -----------------------------
# Helpers
# -----------------------------

def run(cmd: List[str], timeout: int = 30) -> Tuple[int, str, str]:
    """Run a command, return (rc, stdout, stderr)."""
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout, text=True)
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    except Exception as e:
        return 1, "", str(e)


def add(rows: List[List[str]], category: str, key: str, name: str, value: Any, unit: str = "", extra: Any = ""):
    rows.append([category, key, name, str(value), unit, json.dumps(extra, ensure_ascii=False) if isinstance(extra, (dict, list)) else str(extra)])


# -----------------------------
# Collectors
# -----------------------------

def collect_basic(rows: List[List[str]]):
    add(rows, "meta", "timestamp", "UTC Timestamp", datetime.utcnow().isoformat() + "Z")
    add(rows, "meta", "hostname", "Hostname", socket.gethostname())
    add(rows, "meta", "fqdn", "FQDN", socket.getfqdn())
    add(rows, "os", "system", "OS", platform.system())
    add(rows, "os", "release", "OS Release", platform.release())
    add(rows, "os", "version", "OS Version", platform.version())
    add(rows, "os", "kernel", "Kernel", platform.uname().release)
    add(rows, "python", "python", "Python", sys.version.split(" ")[0])


def collect_cpu(rows: List[List[str]]):
    try:
        uname = platform.uname()
        add(rows, "cpu", "machine", "Machine", uname.machine)
        add(rows, "cpu", "processor", "Processor String", platform.processor())
        # Logical/physical
        if psutil:
            add(rows, "cpu", "physical_cores", "Physical Cores", psutil.cpu_count(logical=False) or "")
            add(rows, "cpu", "logical_cores", "Logical Cores", psutil.cpu_count(logical=True) or "")
            try:
                freq = psutil.cpu_freq()
                if freq:
                    add(rows, "cpu", "freq_current", "CPU Frequency Current", round(freq.current, 2), "MHz")
                    add(rows, "cpu", "freq_max", "CPU Frequency Max", round(freq.max or 0, 2), "MHz")
            except Exception:
                pass
            # CPU utilization snapshot
            try:
                usage = psutil.cpu_percent(interval=1.0)
                add(rows, "cpu", "usage", "CPU Usage", usage, "%")
            except Exception:
                pass
        # Windows-specific brand/model
        if platform.system() == "Windows":
            rc, out, _ = run(["wmic", "cpu", "get", "Name,NumberOfCores,NumberOfLogicalProcessors", "/format:csv"])
            if rc == 0 and out:
                lines = [l for l in out.splitlines() if l.strip()][1:]
                for i, line in enumerate(lines):
                    cols = [c.strip() for c in line.split(",")]
                    if len(cols) >= 4:
                        _, cores, name, logical = cols[:4]
                        add(rows, "cpu", f"win_cpu_{i}", "WMIC CPU", name, extra={"cores": cores, "logical": logical})
        elif platform.system() == "Darwin":
            # macOS detailed brand
            rc, out, _ = run(["sysctl", "-n", "machdep.cpu.brand_string"])
            if rc == 0:
                add(rows, "cpu", "brand", "CPU Brand", out)
    except Exception as e:
        add(rows, "error", "cpu", "CPU Collector Error", str(e))


def collect_memory(rows: List[List[str]]):
    try:
        if psutil:
            vm = psutil.virtual_memory()
            add(rows, "memory", "total", "RAM Total", vm.total, "bytes")
            add(rows, "memory", "available", "RAM Available", vm.available, "bytes")
            add(rows, "memory", "used", "RAM Used", vm.used, "bytes")
            add(rows, "memory", "percent", "RAM Used %", vm.percent, "%")
            sm = psutil.swap_memory()
            add(rows, "swap", "total", "Swap Total", sm.total, "bytes")
            add(rows, "swap", "used", "Swap Used", sm.used, "bytes")
            add(rows, "swap", "percent", "Swap Used %", sm.percent, "%")
    except Exception as e:
        add(rows, "error", "memory", "Memory Collector Error", str(e))


def collect_disks(rows: List[List[str]]):
    try:
        if psutil:
            for part in psutil.disk_partitions(all=False):
                usage = None
                try:
                    usage = psutil.disk_usage(part.mountpoint)
                except Exception:
                    pass
                add(rows, "disk", part.device, "Partition", part.mountpoint, extra={
                    "fstype": part.fstype,
                    "opts": part.opts,
                    "total": getattr(usage, 'total', None),
                    "used": getattr(usage, 'used', None),
                    "free": getattr(usage, 'free', None),
                    "percent": getattr(usage, 'percent', None),
                })
        # Linux block devices
        if platform.system() == "Linux":
            rc, out, _ = run(["lsblk", "-J", "-o", "NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,MODEL"])  # JSON
            if rc == 0 and out:
                try:
                    data = json.loads(out)
                    add(rows, "disk", "lsblk", "lsblk", "ok", extra=data)
                except Exception:
                    pass
    except Exception as e:
        add(rows, "error", "disks", "Disk Collector Error", str(e))


def collect_gpu(rows: List[List[str]]):
    try:
        s = platform.system()
        if s == "Windows":
            rc, out, _ = run(["wmic", "path", "win32_VideoController", "get", "Name,AdapterRAM,DriverVersion,DriverDate", "/format:csv"])
            if rc == 0 and out:
                for i, line in enumerate([l for l in out.splitlines() if l.strip()][1:]):
                    cols = [c.strip() for c in line.split(",")]
                    if len(cols) >= 5:
                        _, ram, name, drv_ver, drv_date = cols[:5]
                        add(rows, "gpu", f"gpu_{i}", name, ram, "bytes", extra={"driver": drv_ver, "date": drv_date})
        elif s == "Darwin":
            rc, out, _ = run(["system_profiler", "SPDisplaysDataType", "-json"], timeout=60)
            if rc == 0 and out:
                try:
                    data = json.loads(out)
                    gpus = data.get("SPDisplaysDataType", [])
                    for i, g in enumerate(gpus):
                        add(rows, "gpu", f"gpu_{i}", g.get("_name", "GPU"), g.get("spdisplays_vram", ""), extra=g)
                except Exception:
                    pass
        else:  # Linux
            # lspci VGA
            rc, out, _ = run(["bash", "-lc", "lspci | grep -i 'vga\|3d' || true"]) 
            if out:
                for i, line in enumerate(out.splitlines()):
                    add(rows, "gpu", f"gpu_{i}", "PCI GPU", line)
            # nvidia-smi
            if shutil.which("nvidia-smi"):
                rc, out, _ = run(["nvidia-smi", "--query-gpu=name,memory.total,driver_version", "--format=csv,noheader"])
                if rc == 0 and out:
                    for i, line in enumerate(out.splitlines()):
                        name, mem, drv = [c.strip() for c in line.split(",")]
                        add(rows, "gpu", f"nvidia_{i}", name, mem, extra={"driver": drv})
    except Exception as e:
        add(rows, "error", "gpu", "GPU Collector Error", str(e))


def collect_net(rows: List[List[str]]):
    try:
        if psutil:
            addrs = psutil.net_if_addrs()
            stats = psutil.net_if_stats()
            io = psutil.net_io_counters(pernic=True)
            for name, addlist in addrs.items():
                stat = stats.get(name)
                iostat = io.get(name)
                add(rows, "net", name, "Interface", "up" if (stat and stat.isup) else "down", extra={
                    "speed_mbps": getattr(stat, 'speed', None),
                    "mtu": getattr(stat, 'mtu', None),
                    "addresses": [{
                        "family": str(a.family),
                        "address": a.address,
                        "netmask": a.netmask,
                        "broadcast": getattr(a, 'broadcast', None)
                    } for a in addlist],
                    "io": {
                        "bytes_sent": getattr(iostat, 'bytes_sent', None),
                        "bytes_recv": getattr(iostat, 'bytes_recv', None)
                    }
                })
    except Exception as e:
        add(rows, "error", "net", "Network Collector Error", str(e))


def collect_processes(rows: List[List[str]]):
    try:
        if not psutil:
            return
        procs = []
        for p in psutil.process_iter(attrs=["pid", "name", "username", "cpu_percent", "memory_percent"]):
            info = p.info
            procs.append(info)
        # Take top 10 by CPU and MEM
        top_cpu = sorted(procs, key=lambda x: x.get("cpu_percent", 0), reverse=True)[:10]
        top_mem = sorted(procs, key=lambda x: x.get("memory_percent", 0), reverse=True)[:10]
        add(rows, "proc", "top_cpu", "Top CPU Procs", "10", extra=top_cpu)
        add(rows, "proc", "top_mem", "Top MEM Procs", "10", extra=top_mem)
    except Exception as e:
        add(rows, "error", "proc", "Process Collector Error", str(e))


def collect_drivers(rows: List[List[str]]):
    try:
        s = platform.system()
        if s == "Windows":
            # Prefer PowerShell for installed drivers
            ps_cmd = [
                "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
                "Get-WmiObject Win32_PnPSignedDriver | Select-Object DeviceName,DriverVersion,DriverDate,Manufacturer | ConvertTo-Json"
            ]
            rc, out, err = run(ps_cmd, timeout=120)
            if rc == 0 and out:
                try:
                    data = json.loads(out)
                    add(rows, "drivers", "pnpsigned", "PNP Signed Drivers", "ok", extra=data)
                except Exception:
                    pass
            else:
                # Fallback: pnputil enumeration (Windows 10+); may not exist on Win7
                rc, out, _ = run(["pnputil", "/enum-drivers"], timeout=120)
                if rc == 0 and out:
                    add(rows, "drivers", "pnputil", "PnPUtil", "ok", extra=out)
        elif s == "Darwin":
            rc, out, _ = run(["system_profiler", "SPExtensionsDataType", "-json"], timeout=120)
            if rc == 0 and out:
                try:
                    data = json.loads(out)
                    add(rows, "drivers", "kexts", "Kernel Extensions", "ok", extra=data)
                except Exception:
                    pass
        else:  # Linux
            rc, out, _ = run(["lsmod"])  # kernel modules
            if rc == 0:
                add(rows, "drivers", "lsmod", "Kernel Modules", "ok", extra=out)
    except Exception as e:
        add(rows, "error", "drivers", "Drivers Collector Error", str(e))


def collect_software(rows: List[List[str]]):
    try:
        s = platform.system()
        if s == "Windows":
            ps = [
                "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
                "Get-ItemProperty HKLM:Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*;",
                "Get-ItemProperty HKLM:Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\* |",
                "Select-Object DisplayName,DisplayVersion,Publisher,InstallDate | ConvertTo-Json"
            ]
            rc, out, _ = run(ps, timeout=180)
            if rc == 0 and out:
                try:
                    data = json.loads(out)
                    add(rows, "software", "installed", "Installed Apps", "ok", extra=data)
                except Exception:
                    pass
        elif s == "Darwin":
            rc, out, _ = run(["system_profiler", "SPApplicationsDataType", "-json"], timeout=180)
            if rc == 0 and out:
                try:
                    data = json.loads(out)
                    add(rows, "software", "apps", "Applications", "ok", extra=data)
                except Exception:
                    pass
        else:  # Linux
            if shutil.which("dpkg"):
                rc, out, _ = run(["bash", "-lc", "dpkg -l | awk 'NR>5 {print $2, $3}'"], timeout=180)
                if rc == 0:
                    add(rows, "software", "dpkg", "Deb Packages", "ok", extra=out)
            elif shutil.which("rpm"):
                rc, out, _ = run(["bash", "-lc", "rpm -qa --qf '%{NAME} %{VERSION}-%{RELEASE}\n'"], timeout=180)
                if rc == 0:
                    add(rows, "software", "rpm", "RPM Packages", "ok", extra=out)
    except Exception as e:
        add(rows, "error", "software", "Software Collector Error", str(e))


def collect_power_battery(rows: List[List[str]]):
    try:
        s = platform.system()
        if s == "Windows":
            rc, out, _ = run(["wmic", "path", "Win32_Battery", "get", "*", "/format:csv"])  # may be empty on desktops
            if rc == 0 and out:
                add(rows, "power", "battery", "Battery (WMIC)", "ok", extra=out)
        elif s == "Darwin":
            rc, out, _ = run(["pmset", "-g", "batt"])
            if rc == 0:
                add(rows, "power", "battery", "pmset batt", "ok", extra=out)
        else:
            rc, out, _ = run(["bash", "-lc", "upower -i $(upower -e | grep BAT | head -n1) 2>/dev/null || true"]) 
            if out:
                add(rows, "power", "battery", "upower", "ok", extra=out)
    except Exception as e:
        add(rows, "error", "power", "Power Collector Error", str(e))


def collect_sensors(rows: List[List[str]]):
    try:
        if psutil and hasattr(psutil, "sensors_temperatures"):
            temps = psutil.sensors_temperatures(fahrenheit=False)
            if temps:
                add(rows, "sensors", "temperatures", "Temperatures", "ok", extra={k: [t._asdict() for t in v] for k, v in temps.items()})
    except Exception as e:
        add(rows, "error", "sensors", "Sensors Collector Error", str(e))


# -----------------------------
# Main
# -----------------------------

def main():
    rows: List[List[str]] = []
    collect_basic(rows)
    collect_cpu(rows)
    collect_memory(rows)
    collect_disks(rows)
    collect_gpu(rows)
    collect_net(rows)
    collect_processes(rows)
    collect_drivers(rows)
    collect_software(rows)
    collect_power_battery(rows)
    collect_sensors(rows)

    out_file = os.path.abspath("system_audit.csv")
    with open(out_file, "w", newline='', encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["category", "key", "name", "value", "unit", "extra"])
        writer.writerows(rows)

    print(f"\n[done] Wrote {len(rows)} records to: {out_file}")
    print("Tip: Open in Excel/Numbers and filter by 'category'.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("Interrupted by user.")
    except Exception as e:
        print(f"[fatal] {e}")
        sys.exit(1)
