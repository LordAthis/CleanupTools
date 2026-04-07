# ================================================
# AGRESSZÍV TAKARÍTÓ SCRIPT v4.0
# takeown + icacls + robocopy módszer (makacs meghajtókra)
# ================================================

$ErrorActionPreference = 'SilentlyContinue'
$ScriptPath = $MyInvocation.MyCommand.Path

# Admin jog
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Admin jogkérés..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

$Target = Split-Path $ScriptPath -Parent
$EmptyDir = Join-Path $env:TEMP "EmptyDeleteDir_$(Get-Random)"

Write-Host "=============================================================" -ForegroundColor DarkCyan
Write-Host "          AGRESSZÍV MAPPATÖRLŐ SCRIPT v4.0" -ForegroundColor Green
Write-Host "Célmappa: $Target" -ForegroundColor Yellow
Write-Host "=============================================================`n" -ForegroundColor DarkCyan

# Üres mappa létrehozása a robocopy trükkhöz
New-Item -ItemType Directory -Path $EmptyDir -Force | Out-Null

Write-Host "Tulajdonjog átvétele és jogosultságok bővítése..." -ForegroundColor Yellow

# Minden top-level mappára takeown + icacls
Get-ChildItem -Path $Target -Force -Directory | Where-Object { $_.Name -ne (Split-Path $ScriptPath -Leaf) } | ForEach-Object {
    Write-Host "   Feldolgozás: $($_.Name)" -ForegroundColor White
    takeown /F $_.FullName /R /A /D Y | Out-Null
    icacls $_.FullName /grant Administrators:F /T /C /Q | Out-Null
}

# Fájlokra is
Get-ChildItem -Path $Target -Force -File | Where-Object { $_.FullName -ne $ScriptPath } | ForEach-Object {
    takeown /F $_.FullName /A | Out-Null
    icacls $_.FullName /grant Administrators:F /C /Q | Out-Null
}

Write-Host "`nTörlés robocopy tükrözéssel (ez a legerősebb módszer)..." -ForegroundColor Yellow

robocopy $EmptyDir $Target /MIR /R:3 /W:5 /MT:8 /NP /NFL /NDL /NJH /NJS

# Takarítás
Remove-Item -Path $EmptyDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n=============================================================" -ForegroundColor DarkCyan
Write-Host "KÉSZ!" -ForegroundColor Green
Write-Host "A mappa ki lett takarítva amennyire lehetséges volt." -ForegroundColor Green
Write-Host "Csak a script maradt meg: $ScriptPath" -ForegroundColor White
Write-Host "`nNyomj ENTER-t..." -ForegroundColor DarkGray
Read-Host