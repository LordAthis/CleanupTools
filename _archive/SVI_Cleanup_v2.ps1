# ================================================
# SVI TELJES KIÜRÍTŐ v2.1
# Logok mindig a .\Log mappába + kérésed szerint
# ================================================

$ErrorActionPreference = 'SilentlyContinue'
$ScriptPath = $MyInvocation.MyCommand.Path

# Admin jogkérés
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Admin jogkérés..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

$Drive = "E:"
$SVIFolder = "$Drive\System Volume Information"

# ========================
# LOG MAPPA KEZELÉS
# ========================
$LogFolder = Join-Path $Drive "Log"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path $LogFolder "SVI_Cleanup_v2_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Write-Log { 
    param([string]$Msg, [string]$Color="White")
    Write-Host $Msg -ForegroundColor $Color
    "$((Get-Date -Format 'HH:mm:ss')) | $Msg" | Out-File $LogFile -Append -Encoding UTF8 
}

# Log indítás
"=============================================================" | Out-File $LogFile -Encoding UTF8
"SVI TELJES KIÜRÍTÉS v2.1 - $(Get-Date)" | Out-File $LogFile -Append -Encoding UTF8
"Log mappa: $LogFolder" | Out-File $LogFile -Append -Encoding UTF8
"=============================================================`n" | Out-File $LogFile -Append -Encoding UTF8

Write-Log "SVI teljes kiürítés indul az $Drive meghajtón..." "Green"

# 1. Shadow copies törlése
Write-Log "`n1. Shadow copies törlése..." "Yellow"
vssadmin delete shadows /for=$Drive /all /quiet | Out-Null
Write-Log "   Shadow copies törölve." "Green"

# 2. Shadow storage csökkentése
Write-Log "`n2. Shadow storage minimalizálása (300 MB)..." "Yellow"
vssadmin resize shadowstorage /for=$Drive /on=$Drive /maxsize=300MB | Out-Null

# 3. Teljes SVI törlés
Write-Log "`n3. System Volume Information mappa TELJES törlése..." "Yellow"

takeown /F "$SVIFolder" /R /A /D Y | Out-Null
icacls "$SVIFolder" /grant "*S-1-5-32-544:F" /T /C /Q | Out-Null
attrib -s -h -r "$SVIFolder\*.*" /S /D | Out-Null

rd "$SVIFolder" /s /q 2>&1 | Out-File $LogFile -Append -Encoding UTF8

# Windows újracsinálja
Start-Sleep -Seconds 3
if (-not (Test-Path $SVIFolder)) {
    New-Item -Path $SVIFolder -ItemType Directory -Force | Out-Null
    Write-Log "   SVI mappa sikeresen újralétrehozva (üresen)!" "Green"
} else {
    Write-Log "   SVI mappa már létezik (Windows újracsinálta)" "Green"
}

Write-Log "`nKÉSZ! Ellenőrizd a szabad helyet." "Green"
Write-Log "Log mentve: $LogFile" "Cyan"
Write-Log "Ha nem változott a foglaltság, indítsd újra a gépet!" "Yellow"

Write-Host "`nNyomj ENTER-t a kilépéshez..." -ForegroundColor DarkGray
Read-Host