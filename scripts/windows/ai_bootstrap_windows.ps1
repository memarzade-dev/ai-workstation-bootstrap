# Windows AI Workstation Bootstrapper
# Version: 2.0.0

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
Write-Output "Starting Windows AI Workstation Bootstrap..."

function Ensure-Command {
    param([string]$Cmd)
    $null -ne (Get-Command $Cmd -ErrorAction SilentlyContinue)
}

if (-not (Ensure-Command "git")) {
    Write-Output "Installing Git via winget..."
    winget install --id Git.Git -e --silent
}

if (-not (Ensure-Command "python")) {
    Write-Output "Installing Python via winget..."
    winget install --id Python.Python.3 -e --silent
}

if (-not (Ensure-Command "code")) {
    Write-Output "Installing VSCode via winget..."
    winget install --id Microsoft.VisualStudioCode -e --silent
}

$venvPath = "$PSScriptRoot\..\..\venv"
if (-not (Test-Path $venvPath)) {
    Write-Output "Creating Python venv at $venvPath"
    python -m venv $venvPath
}

Write-Output "Activating venv and installing requirements..."
& "$venvPath\Scripts\Activate.ps1"
pip install --upgrade pip
pip install -r "$PSScriptRoot\..\..\requirements.txt"

Write-Output "Bootstrap complete. You can now run benchmark scripts under python\benchmarks."