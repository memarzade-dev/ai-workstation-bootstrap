### 📘 README-FA.md — راهنمای کامل فارسی نسخه ۳.۰.۰

# بوت‌استرپر ایستگاه کاری هوش مصنوعی (AI Workstation Bootstrap)

**نسخه:** ۳.۰.۰ (پایدار – Production)  
**سازنده:** memarzade-dev  
**سیستم‌های پشتیبانی‌شده:** macOS (Intel / ARM)، Linux (Ubuntu، Fedora، Arch)، Windows 10/11  
**معماری‌ها:** x86_64 و arm64  
**مجوز:** MIT

---

## 🎯 هدف پروژه

این اسکریپت وظیفه دارد هر سیستم عامل دسکتاپ یا سرور را به یک **ایستگاه کاری کامل برای هوش مصنوعی و مدل‌های زبانی بزرگ (LLM)** تبدیل کند.

ویژگی‌ها:
- تشخیص خودکار سیستم عامل، معماری و GPU
- پشتیبانی از دو حالت نصب: **Conda-first** (Miniforge) و **pip‑venv**
- نصب کامل کتابخانه‌های PyTorch، Transformers، Accelerate، bitsandbytes
- نصب ابزارهای LLM: Ollama، llama.cpp
- بهینه‌سازی مصرف انرژی، مدیریت Spotlight و App Nap در macOS
- سیستم Keep-Awake (`ai-caffeinate`) برای اجرای بلندمدت مدل‌ها
- بازگشت امن (revert) بدون تغییرات تخریبی
- ثبت کامل گزارش در مسیر `~/ai_workstation_bootstrap_pro.log`

---

## ⚙️ ویژگی‌های کلیدی

| دسته | توضیح |
|-------|--------|
| شناسایی سخت‌افزار | تشخیص GPU، معماری، سیستم عامل، منابع آزاد و مشغول |
| محیط نصب | انتخاب بین Conda-first (Miniforge) یا Pip Virtualenv |
| موتورهای یادگیری | نصب PyTorch با CUDA، MPS یا CPU به‌صورت خودکار |
| ابزارهای LLM | نصب Ollama و llama.cpp با تنظیم GPU مناسب |
| بهینه‌سازی سیستم | غیرفعال‌سازی App Nap، تنظیم Power Profile و Spotlight |
| بنچمارک | تست عملکرد GPU/MPS با ضرب ماتریسی ۴۰۹۶×۴۰۹۶ |
| بازگشت امن | اجرای `--revert` برای برگرداندن تنظیمات |
| چندمحیطی | ایجاد محیط‌های مستقل برای LLM، بینایی، و یادگیری پایه |

---

## 🚀 اجرای سریع

### macOS و Linux
```bash
chmod +x ./ai_workstation_bootstrap_pro.sh
./ai_workstation_bootstrap_pro.sh --bench
```

### Windows
در **Git Bash** یا **WSL** اجرا شود:
```bash
./ai_workstation_bootstrap_pro.sh
```
اسکریپت فایل PowerShell `ai_bootstrap_windows.ps1` را به‌صورت خودکار می‌سازد و اجرا می‌کند.

---

## 🧩 حالت‌ها

### حالت پیش‌فرض (Pip‑Venv)
```bash
./ai_workstation_bootstrap_pro.sh
```

### حالت Conda-first
```bash
./ai_workstation_bootstrap_pro.sh --mode conda --envs "ai-base ai-llm ai-vision"
```

### تنظیم مسیرها
```bash
./ai_workstation_bootstrap_pro.sh --models-dir ~/Models --venv-dir ~/.venvs/ai
```

### غیر فعال‌سازی ماژول‌ها
```bash
./ai_workstation_bootstrap_pro.sh --no-ollama --no-llama --no-pytorch
```

### بازگردانی تنظیمات
```bash
./ai_workstation_bootstrap_pro.sh --revert
```

---

## 🧠 بنچمارک

فعال‌سازی:
```bash
./ai_workstation_bootstrap_pro.sh --bench
```

نمونه خروجی:
```
[GPU] NVIDIA RTX 4070 detected
[CUDA] Version: 12.1 | PyTorch backend: True
[Benchmark] MatMul 4096x4096 → 2125 GFLOPS
```

روی macOS:
```
[MPS] available = True
[MPS] built = True
```

---

## 📦 ساختار دایرکتوری
```
~/
├── .venvs/ai/
├── miniforge3/
├── Models/
├── bin/ai-caffeinate
├── ai_bootstrap_windows.ps1
└── ai_workstation_bootstrap_pro.log
```

---

## 🧰 گزینه‌های خط فرمان

| گزینه | توضیح |
|--------|--------|
| `--mode conda` | اجرای نصب با Miniforge |
| `--envs "ai-base ai-llm"` | تعریف محیط‌های Conda |
| `--models-dir` | مسیر دلخواه برای مدل‌ها |
| `--venv-dir` | مسیر دلخواه برای Pip-Venv |
| `--no-ollama` | صرف‌نظر از نصب Ollama |
| `--no-llama` | صرف‌نظر از نصب llama.cpp |
| `--no-pytorch` | صرف‌نظر از نصب PyTorch |
| `--revert` | بازگشت تنظیمات سیستم |
| `--bench` | اجرای تست عملکرد |
| `--yes` | اجرا بدون پرسش تأیید |

---

## ⚡ مدیریت انرژی و کارایی

### macOS
- `pmset` برای حالت متصل به برق → جلوگیری از Sleep
- `App Nap` غیرفعال می‌شود
- Spotlight برای مسیر مدل‌ها خاموش می‌شود

### Linux
- تغییرات حداقلی؛ ابزار `systemd-inhibit` برای نگه‌داشت سیستم بیدار

### Windows
- Power Plan روی حالت High Performance تنظیم می‌شود.

---

## 🔐 امنیت و بازگردانی

- هیچ فایل سیستمی بازنویسی نمی‌شود.
- تغییرات قابل بازگشت با `--revert`.
- اجرای sudo فقط هنگام نیاز به دسترسی سیستمی.

---

## 📈 نقشه راه آینده
- پشتیبانی از Flash Attention و KV Cache برای Ollama
- حالت Docker برای محیط‌های بازتولیدپذیر
- افزوده‌شدن ابزارهای پایش GPU و Torch Profiler
- بنچمارک مدل‌های Whisper و Stable Diffusion
- حالت SSH نصب از راه دور برای سرورهای چندنودی

---

## 📜 مجوز
این پروژه تحت مجوز MIT ارائه می‌شود.

---


### 📊 benchmarks/README.md — مستندات بنچمارک

# AI Workstation Benchmarks

این پوشه شامل تست‌های عملکردی برای PyTorch، CUDA و MPS است. هدف این تست‌ها اندازه‌گیری کارایی ماتریس‌ضرب، حافظه GPU و سرعت محاسبه مدل‌های زبانی است.

#### فایل‌ها:
```
benchmarks/
├── torch_bench.py       # بنچمارک ضرب ماتریس در GPU/MPS/CPU
├── memory_check.py      # اندازه‌گیری حافظه آزاد GPU
└── system_info.py       # گزارش سخت‌افزار و نسخه‌های کتابخانه‌ها
```

#### اجرای سریع:
```bash
source ~/.venvs/ai/bin/activate
python benchmarks/torch_bench.py
```

#### نمونه خروجی:
```
Device: cuda:0 (NVIDIA RTX 4070)
Matmul 4096x4096: 1.82 sec → 1846 GFLOPS
Memory Free: 10.8 GB / 12 GB
```

#### تست MPS در macOS:
```bash
python benchmarks/torch_bench.py --device mps
```
خروجی نمونه:
```
[MPS] backend built = True
[MPS] available = True
Time: 2.43s for 4k×4k
```

---


### 🧾 CHANGELOG.md — تاریخچه تغییرات

# تغییرات نسخه‌ها

## v3.0.0 (Production, 2025‑11‑12)
- اضافه‌شدن حالت Conda‑first واقعی با Miniforge
- ساخت چند محیط مستقل (ai‑base، ai‑llm، ai‑vision)
- بازنویسی کامل اسکریپت با ساختار ماژولار و توابع اختصاصی برای هر سیستم‌عامل
- رفع خطای Spotlight در macOS (mdutil → fallback)
- افزودن بنچمارک داخلی (--bench)
- پشتیبانی کامل از CUDA 12.1 و MPS
- ساخت فایل PowerShell برای Windows به‌صورت خودکار
- بهینه‌سازی Power Profile و App Nap
- افزودن سیستم لاگ کامل و قابلیت revert ایمن

## v2.5.0
- بازنویسی ساختار نصب PyTorch برای macOS ARM
- اصلاح نصب Ollama از Brew
- پشتیبانی اولیه از llama.cpp

## v2.0.0
- معرفی بنچمارک Torch اولیه
- افزودن installer برای Windows
- لاگینگ پایه‌ای و گزارش منابع

## v1.0.0
- انتشار اولیه اسکریپت با تمرکز روی macOS و Linux

---


### 💻 installers/windows/ai_bootstrap_windows.ps1 — نسخه PowerShell کامل

```powershell
# ai_bootstrap_windows.ps1 — Windows AI Workstation Bootstrap
# Version 3.0.0 | Author: memarzade-dev

$ErrorActionPreference = 'Continue'
function Have($cmd){ return (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null }
function Log($m){ Write-Host "[WIN] $m" }

# Power plan configuration
try {
    powercfg -SETACTIVE SCHEME_MIN
    Log 'Power plan set to High Performance'
} catch { Log 'Unable to modify power plan' }

# Install dependencies
if (-not (Have 'winget')) {
    Log 'winget not found. Install App Installer from Microsoft Store.'
} else {
    winget install -e --id Git.Git --silent --accept-source-agreements --accept-package-agreements
    winget install -e --id Kitware.CMake --silent --accept-source-agreements --accept-package-agreements
    winget install -e --id Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements
    winget install -e --id Ollama.Ollama --silent --accept-source-agreements --accept-package-agreements
}

# Start Ollama service
try { Start-Service ollama; Log 'Ollama service started' } catch { Log 'Could not start Ollama service' }

# Python virtual environment
$venv = "$env:USERPROFILE\.venvs\ai"
py -3.12 -m venv $venv
& "$venv\Scripts\python.exe" -m pip install --upgrade pip wheel setuptools

# Install PyTorch
$hasNvidia = (Get-Command nvidia-smi -ErrorAction SilentlyContinue) -ne $null
if ($hasNvidia) {
    & "$venv\Scripts\pip.exe" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
} else {
    & "$venv\Scripts\pip.exe" install torch torchvision torchaudio
}

# Core AI libraries
& "$venv\Scripts\pip.exe" install transformers accelerate tokenizers safetensors bitsandbytes

# Sanity check
& "$venv\Scripts\python.exe" - << 'PY'
import torch
print('[CUDA available] =', torch.cuda.is_available())
print('[Device count] =', torch.cuda.device_count())
if torch.cuda.is_available():
    print('[Device name] =', torch.cuda.get_device_name(0))
else:
    print('[Fallback device] = CPU')
PY

# Keep-awake helper
$helper = "$env:USERPROFILE\bin\ai-caffeinate.cmd"
New-Item -ItemType Directory -Force -Path (Split-Path $helper) | Out-Null
Set-Content -Path $helper -Value '@echo off\npowershell -Command Start-Sleep -Seconds 999999' -Encoding ASCII

Log "Setup complete. Virtual environment: $venv"
```

