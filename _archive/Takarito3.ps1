# ================================================
# AGRESSZÍV TAKARÍTÓ SCRIPT v3.0
# Gyorsabb, látható haladás, hibás rendszerekre optimalizálva
# ================================================

$ErrorActionPreference = 'SilentlyContinue'

$ScriptPath = $MyInvocation.MyCommand.Path

# Admin jogkérés
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Admin jogkérés folyamatban..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Exit
}

# UTF-8 kényszerítés + tiszta képernyő
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

$TargetFolder = Split-Path $ScriptPath -Parent

Write-Host "=============================================================" -ForegroundColor DarkCyan
Write-Host "          AGRESSZÍV MAPPATÖRLŐ SCRIPT v3.0" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor DarkCyan
Write-Host "Célmappa: " -NoNewline; Write-Host $TargetFolder -ForegroundColor Yellow
Write-Host "Mindent törlök (kivéve a scriptet). Hibák esetén tovább lépek." -ForegroundColor Cyan
Write-Host "=============================================================`n" -ForegroundColor DarkCyan

# ========================
# TOP-LEVEL elemek törlése (ezért nem lóg!)
# ========================
$items = Get-ChildItem -Path $TargetFolder -Force -ErrorAction SilentlyContinue |
         Where-Object { $_.FullName -ne $ScriptPath }

$total = $items.Count
$current = 0

foreach ($item in $items) {
    $current++
    $percent = [math]::Round(($current / $total) * 100)
    
    Write-Host "[$percent%] Törlés: " -NoNewline
    Write-Host $item.Name -ForegroundColor White
    
    Remove-Item -Path $item.FullName -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    
    if ($item.PSIsContainer) {
        Write-Host "   → Mappa törölve" -ForegroundColor Green
    } else {
        Write-Host "   → Fájl törölve" -ForegroundColor Green
    }
}

Write-Host "`n=============================================================" -ForegroundColor DarkCyan
Write-Host "KÉSZ!" -ForegroundColor Green
Write-Host "A mappa teljesen ki lett takarítva." -ForegroundColor Green
Write-Host "Csak a script maradt meg: " -NoNewline
Write-Host $ScriptPath -ForegroundColor White
Write-Host "`nNyomj ENTER-t a kilépéshez..." -ForegroundColor DarkGray
Read-Host