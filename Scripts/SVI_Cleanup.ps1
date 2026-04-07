# ================================================
# SVI_Cleanup.ps1 - 0.2 verzió
# ================================================

$ErrorActionPreference = 'SilentlyContinue'
$ScriptPath = $MyInvocation.MyCommand.Path
$Drive = Split-Path $ScriptPath -Parent

$LogFolder = Join-Path $Drive "Log"
if (-not (Test-Path $LogFolder)) { New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $LogFolder "SVI_Cleanup_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Write-Log { param([string]$Msg, [string]$Color="White"); Write-Host $Msg -ForegroundColor $Color; "$((Get-Date -Format 'HH:mm:ss')) | $Msg" | Out-File $LogFile -Append -Encoding UTF8 }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "Admin jogkérés..." "Yellow"
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

$SVIFolder = "$Drive\System Volume Information"

Write-Log "SVI teljes kiürítés indul..." "Green"

# Shadow Copies törlése
Write-Log "1. Shadow Copies törlése..." "Yellow"
vssadmin delete shadows /for=$Drive /all /quiet | Out-Null

# Storage csökkentése
Write-Log "2. Shadow Storage minimalizálása (300MB)..." "Yellow"
vssadmin resize shadowstorage /for=$Drive /on=$Drive /maxsize=300MB | Out-Null

# Teljes SVI törlés
Write-Log "3. System Volume Information teljes törlése..." "Yellow"
takeown /F "$SVIFolder" /R /A /D Y | Out-Null
icacls "$SVIFolder" /grant "*S-1-5-32-544:F" /T /C /Q | Out-Null
attrib -s -h -r "$SVIFolder" /S /D | Out-Null
rd "$SVIFolder" /s /q 2>&1 | Out-File $LogFile -Append -Encoding UTF8

Start-Sleep -Seconds 2
if (-not (Test-Path $SVIFolder)) {
    New-Item -Path $SVIFolder -ItemType Directory -Force | Out-Null
    Write-Log "SVI mappa újralétrehozva (üres)" "Green"
}

Write-Log "SVI tisztítás kész!" "Green"
Write-Log "Log: $LogFile" "Cyan"
Write-Host "`nNyomj ENTER-t..." -ForegroundColor DarkGray
Read-Host
