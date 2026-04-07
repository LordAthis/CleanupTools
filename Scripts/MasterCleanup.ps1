# ================================================
# MasterCleanup.ps1  -  v0.2.2
# ================================================

$ErrorActionPreference = 'SilentlyContinue'
$ScriptPath = $MyInvocation.MyCommand.Path
$Drive = Split-Path $ScriptPath -Parent

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Admin jogkérés..." "Yellow"
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

$LogFolder = Join-Path $Drive "Log"
if (-not (Test-Path $LogFolder)) { New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null }

Write-Host "=============================================================" -ForegroundColor DarkCyan
Write-Host "          MASTERCLEANUP v0.2.2" -ForegroundColor Green
Write-Host "=============================================================`n" -ForegroundColor DarkCyan

Write-Host "Automatikus log elemzés..." -ForegroundColor Yellow
& "$Drive\Scripts\LogAnalyzer.ps1"

Write-Host "`nVálassz műveletet:" -ForegroundColor Yellow
Write-Host "1. Teljes takarítás (ajánlott)"
Write-Host "2. Csak Takarito"
Write-Host "3. Csak SVI takarítás"
Write-Host "4. Csak NTFS Reset"
Write-Host "5. Mély helyvizsgálat"
Write-Host "6. Log elemző"
Write-Host "0. Kilépés"

do {
    $valaszt = Read-Host "`nVálasztás (0-6)"
    switch ($valaszt) {
        "1" { & "$Drive\Scripts\Takarito.ps1"; & "$Drive\Scripts\SVI_Cleanup.ps1"; & "$Drive\Scripts\NTFS_Reset.ps1" }
        "2" { & "$Drive\Scripts\Takarito.ps1" }
        "3" { & "$Drive\Scripts\SVI_Cleanup.ps1" }
        "4" { & "$Drive\Scripts\NTFS_Reset.ps1" }
        "5" { & "$Drive\Scripts\SpaceDeepCheck.ps1" }
        "6" { & "$Drive\Scripts\LogAnalyzer.ps1" }
        "0" { Write-Host "Kilépés..." -ForegroundColor Green; exit }
    }
} while ($valaszt -ne "0")
