# ================================================
# MÉLY LEMEZ HELY VIZSGÁLAT v1.0
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
$LogFile = Join-Path $LogFolder "DeepSpaceCheck_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Write-Log { param([string]$Msg, [string]$Color="White"); Write-Host $Msg -ForegroundColor $Color; "$((Get-Date -Format 'HH:mm:ss')) | $Msg" | Out-File $LogFile -Append -Encoding UTF8 }

"=============================================================" | Out-File $LogFile -Encoding UTF8
"MÉLY HELYVIZSGÁLAT - $(Get-Date)" | Out-File $LogFile -Append -Encoding UTF8
"=============================================================`n" | Out-File $LogFile -Append -Encoding UTF8

Write-Log "Mély lemezvizsgálat indul: $Drive" "Green"
Write-Log "Ez eltarthat 1-3 percig..." "Yellow"

# Teljes méret lekérése
$Total = (Get-PSDrive E).Used + (Get-PSDrive E).Free
Write-Log "Teljes méret     : $([math]::Round($Total/1GB,2)) GB" "Cyan"
Write-Log "Foglalt hely     : $([math]::Round((Get-PSDrive E).Used/1GB,2)) GB" "Red"
Write-Log "Szabad hely      : $([math]::Round((Get-PSDrive E).Free/1GB,2)) GB`n" "Cyan"

# Legnagyobb mappák (mélyebb scan)
Write-Log "Legnagyobb mappák (top 15):" "Yellow"

$bigFolders = Get-ChildItem $Drive -Directory -Force -ErrorAction SilentlyContinue | 
    ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        [PSCustomObject]@{
            Name = $_.Name
            SizeGB = [math]::Round($size/1GB, 3)
            Path = $_.FullName
        }
    } | Sort-Object SizeGB -Descending | Select-Object -First 15

$bigFolders | ForEach-Object {
    Write-Log "   $($_.SizeGB) GB  -->  $($_.Name)  ($($_.Path))" "White"
}

# Külön vizsgálat a System Volume Information-ra
Write-Log "`nSystem Volume Information részletes vizsgálata:" "Yellow"
$SVI = "$Drive\System Volume Information"
if (Test-Path $SVI) {
    $sviSize = (Get-ChildItem $SVI -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    Write-Log "   SVI mappa mérete: $([math]::Round($sviSize/1GB,3)) GB" "Red"
} else {
    Write-Log "   SVI mappa nem található" "Red"
}

Write-Log "`nKész! Log mentve: $LogFile" "Green"
Write-Host "`nNyomj ENTER-t a kilépéshez..." -ForegroundColor DarkGray
Read-Host