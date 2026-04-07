# ================================================
# Chkdsk_Auto.ps1  -  v0.1
# ================================================

$ErrorActionPreference = 'SilentlyContinue'
$ScriptPath = $MyInvocation.MyCommand.Path
$Drive = Split-Path $ScriptPath -Parent

$LogFolder = Join-Path $Drive "Log"
if (-not (Test-Path $LogFolder)) { New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $LogFolder "Chkdsk_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Write-Log { param([string]$Msg, [string]$Color="White"); Write-Host $Msg -ForegroundColor $Color; "$((Get-Date -Format 'HH:mm:ss')) | $Msg" | Out-File $LogFile -Append -Encoding UTF8 }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "Admin jogkérés..." "Yellow"
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

$Target = Read-Host "Cél (pl. E:) [E:]"
if ([string]::IsNullOrWhiteSpace($Target)) { $Target = "E:" }

Write-Log "CHKDSK indul: $Target (v0.1)" "Green"

$choice = Read-Host "1=Csak ellenőrzés | 2=Kérdezős | 3=Automatikus [3]"
$params = if ($choice -eq "1") { "/scan" } elseif ($choice -eq "2") { "/f /r" } else { "/f /r /x" }

chkdsk $Target $params.Split() 2>&1 | Out-File $LogFile -Append -Encoding UTF8

Write-Log "CHKDSK kész." "Green"
Write-Host "`nNyomj ENTER-t..." -ForegroundColor DarkGray
Read-Host
