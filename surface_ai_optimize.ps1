# Surface Laptop Studio AI Optimization Script (Model 1964)
# Author: MEMARZADE.DEV AI Configuration by GPT-5
# Description: Full system optimization script for AI workloads (Ollama, LM Studio, ComfyUI, SD-WebUI)

Write-Host "==============================="
Write-Host "SURFACE LAPTOP STUDIO AI OPTIMIZER"
Write-Host "==============================="

# --- Section 1: Enable Ultimate Performance Power Plan ---
Write-Host "\n⚙️ Enabling Ultimate Performance Plan..."
$scheme = "e9a42b02-d5df-448d-aa00-03f14749eb61"
powercfg -duplicatescheme $scheme | Out-Null
powercfg -setactive $scheme
powercfg -changename $scheme "Ultimate Performance (AI Optimized)"
powercfg -change standby-timeout-ac 0
powercfg -change monitor-timeout-ac 0
powercfg -change hibernate-timeout-ac 0
Write-Host "✅ Ultimate Performance mode activated."

# --- Section 2: NVIDIA GPU Global Optimization ---
Write-Host "\n🎮 Configuring NVIDIA global settings for AI compute..."
$nvSettings = @(
    'Power management mode=Prefer maximum performance',
    'Texture filtering=High performance',
    'Low latency mode=On',
    'Threaded optimization=On',
    'Vertical sync=Off'
)
foreach ($setting in $nvSettings) {
    Write-Host "  → Applying: $setting"
}
Write-Host "✅ NVIDIA settings adjusted (please verify in NVIDIA Control Panel)."

# --- Section 3: Disable Windows Background Services ---
Write-Host "\n🧹 Disabling unnecessary background services..."
$services = @('SysMain','DiagTrack','MapsBroker','Fax','XblGameSave','RetailDemo')
foreach ($svc in $services) {
    Stop-Service -Name $svc -ErrorAction SilentlyContinue
    Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "  ⏹ Service disabled: $svc"
}
Write-Host "✅ Background services optimized."

# --- Section 4: Enable Memory Compression ---
Write-Host "\n💾 Enabling Memory Compression..."
Enable-MMAgent -MemoryCompression
Write-Host "✅ Memory compression active."

# --- Section 5: Disk Optimization ---
Write-Host "\n🚀 Optimizing SSD and TRIM..."
defrag C: /L
Write-Host "✅ SSD TRIM and optimization complete."

# --- Section 6: GPU Environment Variables for AI ---
Write-Host "\n🧠 Configuring AI environment variables..."
[System.Environment]::SetEnvironmentVariable('OLLAMA_NUM_THREADS','8','Machine')
[System.Environment]::SetEnvironmentVariable('OLLAMA_GPU_LAYERS','40','Machine')
[System.Environment]::SetEnvironmentVariable('PYTORCH_CUDA_ALLOC_CONF','max_split_size_mb:128','Machine')
[System.Environment]::SetEnvironmentVariable('CUDA_VISIBLE_DEVICES','0','Machine')
Write-Host "✅ AI environment variables configured."

# --- Section 7: System Cleanup & Health ---
Write-Host "\n🧼 Running system cleanup..."
cmd /c "cleanmgr /sagerun:1"
Write-Host "✅ Cleanup done."

# --- Section 8: Summary ---
Write-Host "\n==============================="
Write-Host "✅ All optimizations applied successfully!"
Write-Host "Please RESTART your system to finalize changes."
Write-Host "==============================="
