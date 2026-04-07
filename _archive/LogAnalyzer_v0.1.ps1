# ================================================
# LOG ANALYZER v1.0 - Javaslatokat ad a logok alapján
# ================================================

$ErrorActionPreference = 'SilentlyContinue'
$ScriptPath = $MyInvocation.MyCommand.Path
$Drive = "E:"

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

$LogFolder = Join-Path $Drive "Log"
if (-not (Test-Path $LogFolder)) {
    Write-Host "Nincs Log mappa!" -ForegroundColor Red
    Read-Host; exit
}

Write-Host "=============================================================" -ForegroundColor DarkCyan
Write-Host "          LOG ANALYZER v1.0" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor DarkCyan

$logs = Get-ChildItem $LogFolder -Filter "*Log*.txt" | Sort-Object LastWriteTime -Descending

if ($logs.Count -eq 0) {
    Write-Host "Nincsenek logfájlok." -ForegroundColor Red
    Read-Host; exit
}

Write-Host "Talált logfájlok: $($logs.Count) db`n" -ForegroundColor Cyan

$deepCheck = $logs | Where-Object { $_.Name -like "*DeepSpaceCheck*" } | Select-Object -First 1
if ($deepCheck) {
    $content = Get-Content $deepCheck.FullName -Raw
    if ($content -match "Foglalt hely\s*:\s*6\.03 GB") {
        Write-Host "→ 6 GB foglaltság észlelve (valószínűleg SVI/NTFS metaadat)" -ForegroundColor Red
        Write-Host "   Javaslat: futtasd a 4. opciót (NTFS Reset) a MasterCleanup.ps1-ből!" -ForegroundColor Yellow
    }
}

Write-Host "`nLog elemzés kész. A MasterCleanup.ps1-ben választhatod a megfelelő lépést." -ForegroundColor Green
Write-Host "`nNyomj ENTER-t..." -ForegroundColor DarkGray
Read-Host