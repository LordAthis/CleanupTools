# ================================================
# SpaceDeepCheck.ps1 - 0.2 verzió
# ================================================

$ErrorActionPreference = 'SilentlyContinue'
$ScriptPath = $MyInvocation.MyCommand.Path
$Drive = Split-Path $ScriptPath -Parent

$LogFolder = Join-Path $Drive "Log"
if (-not (Test-Path $LogFolder)) { New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $LogFolder "DeepSpaceCheck_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Write-Log { param([string]$Msg, [string]$Color="White"); Write-Host $Msg -ForegroundColor $Color; "$((Get-Date -Format 'HH:mm:ss')) | $Msg" | Out-File $LogFile -Append -Encoding UTF8 }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "Admin jogkérés..." "Yellow"
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

Write-Log "Mély helyvizsgálat indul ($Drive)..." "Green"

$Used = [math]::Round((Get-PSDrive (Split-Path $Drive -Qualifier).Trim(':')).Used / 1GB, 2)
Write-Log "Foglalt hely: $Used GB" "Red"

Write-Log "`nLegnagyobb mappák:" "Yellow"
Get-ChildItem $Drive -Directory -Force | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB
    if ($size -gt 0.1) { Write-Log "$([math]::Round($size,2)) GB → $($_.Name)" "White" }
}

Write-Log "`nKész! Log: $LogFile" "Green"
Write-Host "`nNyomj ENTER-t..." -ForegroundColor DarkGray
Read-Host
