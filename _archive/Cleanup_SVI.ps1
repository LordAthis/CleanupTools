# ================================================
# SYSTEM VOLUME INFORMATION TAKARÍTÓ v1.0
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
$LogFile = Join-Path $Drive "SVI_Cleanup_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Write-Log { param([string]$Msg, [string]$Color="White"); Write-Host $Msg -ForegroundColor $Color; $Msg | Out-File $LogFile -Append -Encoding UTF8 }

"=============================================================" | Out-File $LogFile -Encoding UTF8
"SVI Cleanup Log - $(Get-Date)" | Out-File $LogFile -Append -Encoding UTF8
"=============================================================`n" | Out-File $LogFile -Append -Encoding UTF8

Write-Log "System Volume Information takarítás indul az $Drive meghajtón..." "Green"

# 1. Shadow Copies törlése
Write-Log "`n1. Shadow Copies (visszaállítási pontok) törlése..." "Yellow"
vssadmin delete shadows /for=$Drive /all /quiet | Out-File $LogFile -Append -Encoding UTF8
Write-Log "   Shadow copies törölve." "Green"

# 2. Shadow Storage csökkentése 1 GB-ra
Write-Log "`n2. Shadow Storage méret csökkentése..." "Yellow"
vssadmin resize shadowstorage /for=$Drive /on=$Drive /maxsize=1GB | Out-File $LogFile -Append -Encoding UTF8

# 3. System Volume Information jogosultság + törlés (maradék)
Write-Log "`n3. System Volume Information mappa agresszív takarítása..." "Yellow"
$SVIFolder = "$Drive\System Volume Information"

takeown /F "$SVIFolder" /R /A /D Y | Out-Null
icacls "$SVIFolder" /grant "*S-1-5-32-544:F" /T /C /Q | Out-Null

# Üres mappa tükrözés robocopy-val (biztonságos)
$Empty = Join-Path $env:TEMP "Empty_$(Get-Random)"
New-Item -ItemType Directory -Path $Empty -Force | Out-Null
robocopy $Empty "$SVIFolder" /MIR /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
Remove-Item $Empty -Recurse -Force

Write-Log "`nKész! Ellenőrizd a szabad helyet." "Green"
Write-Log "Log mentve: $LogFile" "Cyan"

Write-Host "`nNyomj ENTER-t..." -ForegroundColor DarkGray
Read-Host