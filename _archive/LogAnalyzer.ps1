# ================================================
# LOG ANALYZER v2.0 - Intelligens javaslatok
# ================================================

$ErrorActionPreference = 'SilentlyContinue'
$Drive = "E:"

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

$LogFolder = Join-Path $Drive "Log"
if (-not (Test-Path $LogFolder)) {
    Write-Host "Nincs Log mappa!" -ForegroundColor Red
    Read-Host; exit
}

Write-Host "=============================================================" -ForegroundColor DarkCyan
Write-Host "          LOG ANALYZER v2.0 - Javaslatok" -ForegroundColor Green
Write-Host "=============================================================`n" -ForegroundColor DarkCyan

$deepLogs = Get-ChildItem $LogFolder -Filter "*DeepSpaceCheck*" | Sort-Object LastWriteTime -Descending

if ($deepLogs) {
    $latest = $deepLogs[0]
    $content = Get-Content $latest.FullName -Raw -Encoding UTF8
    
    if ($content -match "Foglalt hely\s*:\s*6\.03 GB") {
        Write-Host "⚠️  DETEKTÁLVA: 6.03 GB rejtett foglaltság!" -ForegroundColor Red
        Write-Host "   Ok: Valószínűleg maradék NTFS metaadatok / SVI struktúrák" -ForegroundColor Yellow
        Write-Host "`n   AJÁNLOTT LÉPÉS:" -ForegroundColor Green
        Write-Host "   1. Futtasd a MasterCleanup.ps1-ből a 4-es opciót (NTFS Reset)" -ForegroundColor White
        Write-Host "   2. Indítsd újra a gépet" -ForegroundColor White
        Write-Host "   3. Utána futtasd újra a 5-ös opciót (Mély helyvizsgálat)" -ForegroundColor White
    } else {
        Write-Host "✅ Jelenleg nincs látható 6 GB-os rejtett foglaltság." -ForegroundColor Green
    }
} else {
    Write-Host "Még nincs DeepSpaceCheck log." -ForegroundColor Yellow
}

Write-Host "`nLog elemzés kész. További segítséget a MasterCleanup.ps1-ben találsz." -ForegroundColor Cyan
Write-Host "`nNyomj ENTER-t..." -ForegroundColor DarkGray
Read-Host