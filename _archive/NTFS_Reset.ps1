# ================================================
# NTFS RESET + USN JOURNAL + SVI TELJES KIÜRÍTÉS v1.0
# Logok mindig a .\Log mappában
# ================================================

$ErrorActionPreference = 'SilentlyContinue'
$ScriptPath = $MyInvocation.MyCommand.Path

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Admin jogkérés..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

$Drive = "E:"

# Log mappa
$LogFolder = Join-Path $Drive "Log"
if (-not (Test-Path $LogFolder)) { New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $LogFolder "NTFS_Reset_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Write-Log { param([string]$Msg, [string]$Color="White"); Write-Host $Msg -ForegroundColor $Color; "$((Get-Date -Format 'HH:mm:ss')) | $Msg" | Out-File $LogFile -Append -Encoding UTF8 }

"=============================================================" | Out-File $LogFile -Encoding UTF8
"NTFS RESET + SVI TELJES KIÜRÍTÉS v1.0 - $(Get-Date)" | Out-File $LogFile -Append -Encoding UTF8
"=============================================================`n" | Out-File $LogFile -Append -Encoding UTF8

Write-Log "NTFS Reset indul az $Drive meghajtón..." "Green"

# 1. Szolgáltatások leállítása
Write-Log "`n1. Szolgáltatások leállítása (Indexing, System Restore)..." "Yellow"
Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
Stop-Service -Name "VSS" -Force -ErrorAction SilentlyContinue

# 2. USN Journal törlése
Write-Log "`n2. USN Journal teljes törlése..." "Yellow"
fsutil usn deletejournal /D $Drive | Out-Null
Write-Log "   USN Journal törölve." "Green"

# 3. SVI teljes kiirtása
Write-Log "`n3. System Volume Information teljes törlése..." "Yellow"
$SVI = "$Drive\System Volume Information"
takeown /F "$SVI" /R /A /D Y | Out-Null
icacls "$SVI" /grant "*S-1-5-32-544:F" /T /C /Q | Out-Null
attrib -s -h -r "$SVI" /S /D | Out-Null
rd "$SVI" /s /q 2>&1 | Out-File $LogFile -Append -Encoding UTF8

Start-Sleep -Seconds 2
if (-not (Test-Path $SVI)) {
    New-Item -Path $SVI -ItemType Directory -Force | Out-Null
    Write-Log "   SVI mappa újralétrehozva (üresen)" "Green"
}

# 4. Shadow storage minimálisra
Write-Log "`n4. Shadow storage minimalizálása..." "Yellow"
vssadmin resize shadowstorage /for=$Drive /on=$Drive /maxsize=300MB | Out-Null

Write-Log "`nKÉSZ! Ajánlott: indítsd újra a gépet a változások érvényesítéséhez." "Green"
Write-Log "Log mentve: $LogFile" "Cyan"

Write-Host "`nNyomj ENTER-t a kilépéshez (és utána újraindítás ajánlott)..." -ForegroundColor DarkGray
Read-Host