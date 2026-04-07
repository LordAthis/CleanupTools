# ================================================
# CHKDSK AGRESSZÍV + LOGOLÓ SCRIPT v1.0
# Teljes logolás, opciók, mappára/egész meghajtóra is
# ================================================

$ErrorActionPreference = 'SilentlyContinue'
$ScriptPath = $MyInvocation.MyCommand.Path

# ========================
# ADMIN JOGKÉRÉS
# ========================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Admin jogkérés folyamatban..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

# ========================
# CÉL MEGADÁSA
# ========================
$Target = Read-Host "Add meg a meghajtót vagy mappát (pl. E: vagy E:\valami) [E:]"
if ([string]::IsNullOrWhiteSpace($Target)) { $Target = "E:" }

$DriveLetter = if ($Target -match '^([A-Z]):') { $matches[1] + ":" } else { $Target }

$LogFile = Join-Path (Split-Path $ScriptPath -Parent) "CHKDSK_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
    "$((Get-Date -Format 'HH:mm:ss')) | $Message" | Out-File $LogFile -Append -Encoding UTF8
}

"=============================================================" | Out-File $LogFile -Encoding UTF8
"          CHKDSK LOG - $(Get-Date)" | Out-File $LogFile -Append -Encoding UTF8
"Cél: $Target" | Out-File $LogFile -Append -Encoding UTF8
"=============================================================`n" | Out-File $LogFile -Append -Encoding UTF8

Write-Log "CHKDSK script elindult. Log: $LogFile" "Green"
Write-Log "Cél: $Target" "Cyan"

# ========================
# MÓD VÁLASZTÁS
# ========================
Write-Host "`nVálassz módot:" -ForegroundColor Yellow
Write-Host "1. Semmit ne javítson (csak ellenőrizzen)"
Write-Host "2. Mindenre kérdezzen rá"
Write-Host "3. Automatikus javítás (némán, amennyire lehet)" -ForegroundColor Green
$choice = Read-Host "Válasz (1-3)"

switch ($choice) {
    "1" { $params = "/scan"; $mode = "Csak ellenőrzés" }
    "2" { $params = "/f /r"; $mode = "Kérdezős javítás" }
    "3" { $params = "/f /r /x"; $mode = "Teljes automata javítás" }
    default { $params = "/f /r /x"; $mode = "Teljes automata javítás" }
}

Write-Log "Kiválasztott mód: $mode" "Yellow"

# ========================
# CHKDSK FUTTATÁSA
# ========================
Write-Log "CHKDSK indítása $Target -on ($params)..." "Yellow"

$chkdskOutput = chkdsk $Target $params.Split() 2>&1

# Teljes kimenet logolása
$chkdskOutput | Out-File $LogFile -Append -Encoding UTF8

if ($chkdskOutput -match "Windows found problems" -or $chkdskOutput -match "javított") {
    Write-Log "CHKDSK hibákat talált és javított!" "Green"
} elseif ($chkdskOutput -match "No further action required") {
    Write-Log "CHKDSK: Nincs javítanivaló." "Green"
} else {
    Write-Log "CHKDSK lefutott (lehet, hogy újraindítás kell a teljes javításhoz)" "Cyan"
}

Write-Log "`n=============================================================" "DarkCyan"
Write-Log "CHKDSK kész! Log mentve: $LogFile" "Green"

Write-Host "`nNyomj ENTER-t a kilépéshez..." -ForegroundColor DarkGray
Read-Host