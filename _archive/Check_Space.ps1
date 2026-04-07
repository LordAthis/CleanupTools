# ================================================
# LEMEZ HELY VIZSGÁLÓ v1.0
# Logok mindig a .\Log mappában
# ================================================

$ErrorActionPreference = 'SilentlyContinue'
$ScriptPath = $MyInvocation.MyCommand.Path

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Admin jogkérés..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

$Drive = "E:"

# Log mappa
$LogFolder = Join-Path $Drive "Log"
if (-not (Test-Path $LogFolder)) { New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $LogFolder "SpaceCheck_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Write-Log { param([string]$Msg, [string]$Color="White"); Write-Host $Msg -ForegroundColor $Color; "$((Get-Date -Format 'HH:mm:ss')) | $Msg" | Out-File $LogFile -Append -Encoding UTF8 }

"=============================================================" | Out-File $LogFile -Encoding UTF8
"LEMEZ HELY VIZSGÁLAT - $(Get-Date)" | Out-File $LogFile -Append -Encoding UTF8
"=============================================================`n" | Out-File $LogFile -Append -Encoding UTF8

Write-Log "Lemezelemzés indul: $Drive" "Green"

# Szabad hely lekérdezése
$Free = (Get-PSDrive E).Free / 1GB
$Used = (Get-PSDrive E).Used / 1GB
Write-Log "Szabad hely : $([math]::Round($Free,2)) GB" "Cyan"
Write-Log "Foglalt hely: $([math]::Round($Used,2)) GB" "Cyan"

# Legnagyobb mappák (top 10)
Write-Log "`n10 legnagyobb mappa/fájl (rejtettek is):" "Yellow"
Get-ChildItem $Drive -Recurse -Force -ErrorAction SilentlyContinue | 
  Sort-Object Length -Descending | 
  Select-Object -First 10 FullName, @{Name="SizeGB";Expression={[math]::Round($_.Length/1GB,3)}} | 
  ForEach-Object { Write-Log "   $($_.SizeGB) GB  -->  $($_.FullName)" "White" }

Write-Log "`nKész! Log mentve: $LogFile" "Green"
Write-Host "`nNyomj ENTER-t..." -ForegroundColor DarkGray
Read-Host