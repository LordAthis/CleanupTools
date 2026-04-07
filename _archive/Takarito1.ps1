# ================================================
# AGRESSZÍV TAKARÍTÓ SCRIPT
# Minden törlése a saját mappában (kivéve saját magát)
# Automatikus admin jogkérés + hiba esetén tovább lép
# Készült: idegen meghajtók gyökerében való futtatáshoz
# ================================================

# ========================
# AUTOMATIKUS ADMIN JOGKÉRÉS
# ========================
$ErrorActionPreference = 'SilentlyContinue'

# Saját script útvonala
$ScriptPath = $MyInvocation.MyCommand.Path

# Ha nem vagyunk admin, újraindítjuk admin joggal
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Admin jogkérés folyamatban..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" 
    Exit
}

# ========================
# CÉLMAPPA (ahol a script van)
# ========================
$TargetFolder = Split-Path $ScriptPath -Parent

Write-Host "Törlés indul a mappában: $TargetFolder" -ForegroundColor Green
Write-Host "Mindent törlök (kivéve saját magam). Hibák esetén tovább lépek..." -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor DarkGray

# ========================
# TÖRLÉS - FÁJLOK ELŐSZÖR (mélységtől függetlenül)
# ========================
Write-Host "Fájlok törlése..." -ForegroundColor Yellow

Get-ChildItem -Path $TargetFolder -Recurse -Force -File -ErrorAction SilentlyContinue | 
    Where-Object { $_.FullName -ne $ScriptPath } | 
    ForEach-Object {
        Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
    }

# ========================
# TÖRLÉS - MAPPÁK (mélység szerint, legmélyebbről felfelé)
# ========================
Write-Host "Mappák törlése..." -ForegroundColor Yellow

Get-ChildItem -Path $TargetFolder -Recurse -Force -Directory -ErrorAction SilentlyContinue | 
    Where-Object { $_.FullName -ne $TargetFolder } | 
    Sort-Object -Property @{Expression={$_.FullName.Length}; Ascending=$false} | 
    ForEach-Object {
        Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

# ========================
# VÉGE
# ========================
Write-Host "==================================================" -ForegroundColor DarkGray
Write-Host "KÉSZ! A mappa ki lett takarítva." -ForegroundColor Green
Write-Host "Csak a script maradt meg: $ScriptPath" -ForegroundColor Green
Write-Host "Nyomj egy entert a kilépéshez..." -ForegroundColor DarkGray
Read-Host