# ================================================
# AGRESSZÍV TAKARÍTÓ SCRIPT v5.0
# Teljes logolás + SID alapú jogosultság (névfeloldás nélkül)
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

$Target = Split-Path $ScriptPath -Parent
$LogFile = Join-Path $Target "Takaritas_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# Log header
"=============================================================" | Out-File $LogFile -Encoding UTF8
"          AGRESSZÍV TAKARÍTÓ v5.0 - LOG" | Out-File $LogFile -Append -Encoding UTF8
"Tényleges dátum: $(Get-Date)" | Out-File $LogFile -Append -Encoding UTF8
"Célmappa: $Target" | Out-File $LogFile -Append -Encoding UTF8
"=============================================================`n" | Out-File $LogFile -Append -Encoding UTF8

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
    $Message | Out-File $LogFile -Append -Encoding UTF8
}

Write-Log "Script elindult. Logfájl: $LogFile" "Green"

# Üres mappa a robocopy-hoz
$EmptyDir = Join-Path $env:TEMP "EmptyDelete_$(Get-Random)"
New-Item -ItemType Directory -Path $EmptyDir -Force | Out-Null

Write-Log "`n1. Tulajdonjog + jogosultságok (SID alapú)..." "Yellow"

# Minden gyökér elem feldolgozása
$items = Get-ChildItem -Path $Target -Force | Where-Object { $_.FullName -ne $ScriptPath }

foreach ($item in $items) {
    $path = $item.FullName
    $name = $item.Name
    
    Write-Log "`nFeldolgozás: $name" "White"
    
    # Takeown SID-del (Administrators SID = S-1-5-32-544)
    $take = takeown /F "$path" /R /A /D Y 2>&1
    if ($take -match "SUCCESS") { Write-Log "   takeown: SIKER" "Green" } 
    else { Write-Log "   takeown: HIBA" "Red" }
    
    # icacls SID-del (nem névvel!)
    icacls "$path" /grant "*S-1-5-32-544:F" /T /C /Q | Out-Null
    Write-Log "   icacls: megpróbálva" "Cyan"
    
    # Robocopy próbálkozás
    $robolog = robocopy $EmptyDir "$path" /MIR /R:1 /W:1 /MT:4 /NP /NFL /NDL /NJH /NJS 2>&1
    if ($LastExitCode -in 0,1,2,3) {
        Write-Log "   robocopy: SIKER" "Green"
    } else {
        Write-Log "   robocopy: Részleges vagy sikertelen" "Yellow"
    }
    
    # Utolsó próbálkozás Remove-Item-mel
    Remove-Item -Path "$path" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    if (-not (Test-Path $path)) {
        Write-Log "   Végleges törlés: SIKER" "Green"
    } else {
        Write-Log "   Végleges törlés: MEG MARADT" "Red"
    }
}

# Takarítás
Remove-Item $EmptyDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Log "`n=============================================================" "DarkCyan"
Write-Log "KÉSZ! Teljes log mentve: $LogFile" "Green"
Write-Log "Csak a script maradt meg: $ScriptPath" "White"

Write-Host "`nNyomj ENTER-t a kilépéshez..." -ForegroundColor DarkGray
Read-Host