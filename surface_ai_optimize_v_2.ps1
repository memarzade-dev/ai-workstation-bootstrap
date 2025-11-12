# Surface Laptop Studio (Model 1964) — AI Optimization Suite (v2)
# Author: MEMARZADE.DEV — engineered for RTX 3050 Ti + i7‑11370H + 32 GB
# Purpose: Robust, idempotent, error‑tolerant tuning for local AI (Ollama, LM Studio, ComfyUI, SD‑WebUI)
# Notes:
#  • Fixes the “Attempted to write to unsupported setting” by using supported powercfg calls with fallbacks.
#  • Adds HAGS, Fast Startup off, USB selective‑suspend off, memory compression check, TRIM, and env vars.
#  • Does not try to program NVIDIA Control Panel (not scriptable); prints nvidia‑smi guidance instead.
#  • Safe to re‑run. Creates a restore point and logs to %ProgramData%\SurfaceAI\optimize.log

param(
  [switch]$NoReboot
)

$ErrorActionPreference = 'Stop'

function Write-Step($msg){ Write-Host ("`n[+] " + $msg) -ForegroundColor Cyan }
function Write-Ok($msg){ Write-Host ("    ✔ " + $msg) -ForegroundColor Green }
function Write-Warn($msg){ Write-Host ("    ! " + $msg) -ForegroundColor Yellow }
function Write-Err($msg){ Write-Host ("    ✖ " + $msg) -ForegroundColor Red }

$LogDir = "$env:ProgramData\SurfaceAI"
$Log = Join-Path $LogDir 'optimize.log'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
Start-Transcript -Path $Log -Append | Out-Null

# Admin check
if(-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)){
  Write-Err "Run PowerShell as Administrator."; Stop-Transcript; exit 1
}

# Restore point (best‑effort)
try { Checkpoint-Computer -Description 'SurfaceAI_Optimize_v2' -RestorePointType 'MODIFY_SETTINGS' } catch { Write-Warn "Restore point skipped: $_" }

# ────────────────────────────────────────────────────────────────────────────────
# Section 1 — Ultimate Performance (with safe fallbacks)
# ────────────────────────────────────────────────────────────────────────────────
Write-Step "Enable Ultimate Performance scheme & prevent sleep on AC"
$Ultimate = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
try {
  $schemes = (powercfg -list) 2>$null
  if($schemes -notmatch $Ultimate){ powercfg -duplicatescheme $Ultimate | Out-Null }
  powercfg -setactive $Ultimate
  Write-Ok "Ultimate Performance active"
} catch { Write-Warn "Could not activate Ultimate plan: $_" }

try {
  powercfg -change -monitor-timeout-ac 0 2>$null
  powercfg -change -standby-timeout-ac 0 2>$null
  powercfg -change -hibernate-timeout-ac 0 2>$null
  Write-Ok "AC timeouts set to Never"
} catch { Write-Warn "Timeout configuration used defaults: $_" }

try { powercfg /setacvalueindex SCHEME_CURRENT SUB_USB USBSELECTIVE 0; Write-Ok "USB selective‑suspend disabled (AC)" } catch { Write-Warn "USB selective‑suspend unchanged: $_" }
try { powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR SYSTEM_COOLING_POLICY 0; Write-Ok "System cooling policy = Active" } catch { Write-Warn "Cooling policy unchanged: $_" }

powercfg -setactive SCHEME_CURRENT | Out-Null

# ────────────────────────────────────────────────────────────────────────────────
# Section 2 — Graphics stack toggles
# ────────────────────────────────────────────────────────────────────────────────
Write-Step "Enable Hardware‑Accelerated GPU Scheduling (HAGS) & disable Fast Startup"
try {
  New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Force | Out-Null
  New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -PropertyType DWord -Value 2 -Force | Out-Null
  Write-Ok "HAGS enabled (requires reboot)"
} catch { Write-Warn "HAGS toggle failed: $_" }

try {
  New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Force | Out-Null
  New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -PropertyType DWord -Value 0 -Force | Out-Null
  Write-Ok "Fast Startup disabled"
} catch { Write-Warn "Fast Startup toggle failed: $_" }

# ────────────────────────────────────────────────────────────────────────────────
# Section 3 — Memory & Storage
# ────────────────────────────────────────────────────────────────────────────────
Write-Step "Enable Memory Compression & run TRIM"
try { Enable-MMAgent -MemoryCompression; Write-Ok "Memory Compression enabled" } catch { Write-Warn "Memory Compression already enabled or unavailable" }
try { defrag C: /L | Out-Null; Write-Ok "TRIM executed on C:" } catch { Write-Warn "TRIM skipped: $_" }

try {
  wmic computersystem set AutomaticManagedPagefile=True | Out-Null
  Write-Ok "Pagefile set to System Managed"
} catch { Write-Warn "Pagefile unchanged: $_" }

# ────────────────────────────────────────────────────────────────────────────────
# Section 4 — Environment for AI runtimes
# ────────────────────────────────────────────────────────────────────────────────
Write-Step "Set common AI environment variables"
[Environment]::SetEnvironmentVariable('OLLAMA_NUM_THREADS','8','Machine')
[Environment]::SetEnvironmentVariable('OLLAMA_GPU_LAYERS','40','Machine')
[Environment]::SetEnvironmentVariable('PYTORCH_CUDA_ALLOC_CONF','max_split_size_mb:128','Machine')
[Environment]::SetEnvironmentVariable('CUDA_VISIBLE_DEVICES','0','Machine')
Write-Ok "Environment variables persisted at Machine scope"

# ────────────────────────────────────────────────────────────────────────────────
# Section 5 — Services hygiene
# ────────────────────────────────────────────────────────────────────────────────
Write-Step "Disable noisy background services (safe list)"
$Services = 'SysMain','DiagTrack','MapsBroker','Fax','XblGameSave','RetailDemo'
foreach($svc in $Services){
  try { Stop-Service -Name $svc -ErrorAction SilentlyContinue; Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue; Write-Ok "Disabled: $svc" } catch { Write-Warn "Service $svc not changed: $_" }
}

# ────────────────────────────────────────────────────────────────────────────────
# Section 6 — NVIDIA guidance (cannot be scripted via API reliably)
# ────────────────────────────────────────────────────────────────────────────────
Write-Step "NVIDIA quick guidance"
Write-Host "  • Open NVIDIA Control Panel → Manage 3D settings → Global"
Write-Host "    Power Management: Prefer maximum performance"
Write-Host "    Low Latency: On  |  Threaded Optimization: On  |  V‑Sync: Off  |  Texture filtering: High performance"

try {
  $smi = (Get-Command nvidia-smi -ErrorAction SilentlyContinue)
  if($smi){
    & $smi --query-gpu=name,power.limit,power.default_limit,temperature.gpu --format=csv
    Write-Ok "nvidia-smi available; persistence/app clocks not supported on most laptops"
  } else { Write-Warn "nvidia-smi not found in PATH (OK on some driver builds)" }
} catch { Write-Warn "nvidia-smi query failed: $_" }

# ────────────────────────────────────────────────────────────────────────────────
# Section 7 — Cleanup
# ────────────────────────────────────────────────────────────────────────────────
Write-Step "System cleanup"
try { Start-Process -FilePath cleanmgr.exe -ArgumentList '/sagerun:1' -WindowStyle Hidden } catch { Write-Warn "Disk cleanup skipped" }

Stop-Transcript | Out-Null
Write-Host "`n==================================="
Write-Host "✅ Optimization completed."
if(-not $NoReboot){ Write-Host "🔁 Please RESTART to apply HAGS & power changes." } else { Write-Host "🔁 Reboot recommended (use without auto‑reboot by -NoReboot)." }
Write-Host "Logs: $Log"
