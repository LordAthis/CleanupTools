# ================================================
# LogAnalyzer.ps1  -  v0.2
# ================================================

$ErrorActionPreference = 'SilentlyContinue'
$Drive = Split-Path $MyInvocation.MyCommand.Path -Parent
$LogFolder = Join-Path $Drive "Log"

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

Write-Host "=============================================================" -ForegroundColor DarkCyan
Write-Host "          LOG ANALYZER v0.2" -ForegroundColor Green
Write-Host "=============================================================`n" -ForegroundColor DarkCyan

$deep = Get-ChildItem $LogFolder -Filter "*DeepSpaceCheck*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($deep) {
    $content = Get-Content $deep.FullName -Raw
    if ($content -match "Foglalt hely\s*:\s*6\.\d+ GB") {
        Write-Host "⚠️  6+ GB rejtett foglaltság észlelve!" -ForegroundColor Red
        Write-Host "   Javaslat: Futtasd a 4-es opciót (NTFS Reset)" -ForegroundColor Yellow
    } else {
        Write-Host "✅ Nincs kritikus rejtett foglaltság." -ForegroundColor Green
    }
} else {
    Write-Host "Még nincs DeepSpaceCheck log." -ForegroundColor Yellow
}

Write-Host "`nLog elemzés kész." -ForegroundColor Cyan
Write-Host "`nNyomj ENTER-t..." -ForegroundColor DarkGray
Read-Host
