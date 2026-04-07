# ================================================
# MASTERCLEANUP v2.0 - Intelligens központ
# Automatikus log-elemzés + ajánlás az induláskor
# ================================================

$ErrorActionPreference = 'SilentlyContinue'
$ScriptPath = $MyInvocation.MyCommand.Path
$Drive = "E:"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Admin jogkérés..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

$LogFolder = Join-Path $Drive "Log"
if (-not (Test-Path $LogFolder)) { New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null }

# ========================
# AUTOMATIKUS ELEMZÉS INDULÁSKOR
# ========================
Write-Host "=============================================================" -ForegroundColor DarkCyan
Write-Host "          MASTERCLEANUP v2.0 - E: meghajtó" -ForegroundColor Green
Write-Host "=============================================================`n" -ForegroundColor DarkCyan

Write-Host "Automatikus log-elemzés indul..." -ForegroundColor Yellow
& "$Drive\LogAnalyzer.ps1"

Write-Host "`nElemzés kész. Válassz műveletet:" -ForegroundColor Yellow
Write-Host "1. Teljes takarítás (Takarito + SVI + NTFS Reset)"
Write-Host "2. Csak Takarito"
Write-Host "3. Csak SVI tisztítás"
Write-Host "4. Csak NTFS Reset (6 GB probléma)"
Write-Host "5. Mély helyvizsgálat"
Write-Host "6. Log elemző (újra)"
Write-Host "0. Kilépés"

do {
    $valaszt = Read-Host "`nVálasztás (0-6)"
    switch ($valaszt) {
        "1" { & "$Drive\Takarito.ps1"; & "$Drive\SVI_Cleanup_v2.ps1"; & "$Drive\NTFS_Reset.ps1" }
        "2" { & "$Drive\Takarito.ps1" }
        "3" { & "$Drive\SVI_Cleanup_v2.ps1" }
        "4" { & "$Drive\NTFS_Reset.ps1" }
        "5" { & "$Drive\SpaceDeepCheck.ps1" }
        "6" { & "$Drive\LogAnalyzer.ps1" }
        "0" { Write-Host "Kilépés..." -ForegroundColor Green; exit }
    }
} while ($valaszt -ne "0")