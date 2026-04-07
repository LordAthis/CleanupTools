# ================================================
# Takarito.ps1  -  v0.2
# ================================================

$ErrorActionPreference = 'SilentlyContinue'
$ScriptPath = $MyInvocation.MyCommand.Path
$Drive = Split-Path $ScriptPath -Parent

$LogFolder = Join-Path $Drive "Log"
if (-not (Test-Path $LogFolder)) { New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $LogFolder "Takarito_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Write-Log { param([string]$Msg, [string]$Color="White"); Write-Host $Msg -ForegroundColor $Color; "$((Get-Date -Format 'HH:mm:ss')) | $Msg" | Out-File $LogFile -Append -Encoding UTF8 }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "Admin jogkérés..." "Yellow"
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

Write-Log "TAKARITO v0.2 indul..." "Green"

$items = Get-ChildItem $Drive -Force | Where-Object { $_.FullName -ne $ScriptPath }

foreach ($item in $items) {
    Write-Log "Törlés: $($item.Name)" "White"
    Remove-Item $item.FullName -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
}

Write-Log "TAKARÍTÁS KÉSZ!" "Green"
Write-Host "`nNyomj ENTER-t..." -ForegroundColor DarkGray
Read-Host
