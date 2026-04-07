# ================================================
# NTFS_Reset.ps1 - 0.2 verzió
# ================================================

$ErrorActionPreference = 'SilentlyContinue'
$ScriptPath = $MyInvocation.MyCommand.Path
$Drive = Split-Path $ScriptPath -Parent

$LogFolder = Join-Path $Drive "Log"
if (-not (Test-Path $LogFolder)) { New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $LogFolder "NTFS_Reset_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Write-Log { param([string]$Msg, [string]$Color="White"); Write-Host $Msg -ForegroundColor $Color; "$((Get-Date -Format 'HH:mm:ss')) | $Msg" | Out-File $LogFile -Append -Encoding UTF8 }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "Admin jogkérés..." "Yellow"
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

Write-Log "NTFS Reset indul ($Drive)..." "Green"

Stop-Service "WSearch","VSS" -Force -ErrorAction SilentlyContinue

Write-Log "USN Journal törlése..." "Yellow"
fsutil usn deletejournal /D $Drive | Out-Null

$SVI = "$Drive\System Volume Information"
takeown /F "$SVI" /R /A /D Y | Out-Null
icacls "$SVI" /grant "*S-1-5-32-544:F" /T /C /Q | Out-Null
rd "$SVI" /s /q 2>&1 | Out-File $LogFile -Append -Encoding UTF8

Start-Sleep -Seconds 2
if (-not (Test-Path $SVI)) { New-Item -Path $SVI -ItemType Directory -Force | Out-Null }

vssadmin resize shadowstorage /for=$Drive /on=$Drive /maxsize=300MB | Out-Null

Write-Log "NTFS Reset kész! Ajánlott: újraindítás" "Green"
Write-Log "Log: $LogFile" "Cyan"
Write-Host "`nNyomj ENTER-t..." -ForegroundColor DarkGray
Read-Host
