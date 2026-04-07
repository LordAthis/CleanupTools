# ================================================
# AGRESSZÍV TAKARÍTÓ SCRIPT v2.0
# Minden törlése a saját mappában (kivéve saját magát)
# Jobb visszajelzés + karakterkódolás javítva
# ================================================

# Automatikus admin jogkérés
$ErrorActionPreference = 'SilentlyContinue'

$ScriptPath = $MyInvocation.MyCommand.Path

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Admin jogkérés folyamatban..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Exit
}

# ========================
# KARAKTERKÓDOLÁS JAVÍTÁS
# ========================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$TargetFolder = Split-Path $ScriptPath -Parent

Clear-Host
Write-Host "=============================================================" -ForegroundColor DarkCyan
Write-Host "          AGRESSZÍV MAPPATÖRLŐ SCRIPT v2.0" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor DarkCyan
Write-Host "Célmappa: " -NoNewline
Write-Host $TargetFolder -ForegroundColor Yellow
Write-Host "Mindent törlök (kivéve ezt a scriptet). Hibák esetén tovább lépek." -ForegroundColor Cyan
Write-Host "=============================================================`n" -ForegroundColor DarkCyan

# ========================
# FÁJLOK TÖRLÉSE
# ========================
Write-Host "[1/2] Fájlok törlése..." -ForegroundColor Yellow

Get-ChildItem -Path $TargetFolder -Recurse -Force -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -ne $ScriptPath } |
    ForEach-Object {
        Remove-Item -Path $_.FullName -Force -Confirm:$false -ErrorAction SilentlyContinue
    }

Write-Host "   Fájlok törlése kész." -ForegroundColor Green

# ========================
# MAPPÁK TÖRLÉSE (legmélyebbről felfelé)
# ========================
Write-Host "[2/2] Mappák törlése (mélység szerint)..." -ForegroundColor Yellow

Get-ChildItem -Path $TargetFolder -Recurse -Force -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -ne $TargetFolder } |
    Sort-Object -Property @{Expression = { $_.FullName.Length }; Ascending = $false } |
    ForEach-Object {
        Remove-Item -Path $_.FullName -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    }

Write-Host "`n=============================================================" -ForegroundColor DarkCyan
Write-Host "KÉSZ!" -ForegroundColor Green
Write-Host "A mappa ki lett takarítva." -ForegroundColor Green
Write-Host "Csak a script maradt meg: " -NoNewline
Write-Host $ScriptPath -ForegroundColor White
Write-Host "`nNyomj ENTER-t a kilépéshez..." -ForegroundColor DarkGray
Read-Host