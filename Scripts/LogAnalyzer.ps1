# ================================================
# LogAnalyzer.ps1  -  v0.8
# ================================================

<#
.SYNOPSIS
    CleanupTools – LogAnalyzer.ps1
    Automatikusan elemzi az összes log fájlt és ajánlásokat fogalmaz meg.
.PARAMETER DriveRoot
    A meghajtó gyökere.
#>

#Requires -RunAsAdministrator

param([string]$DriveRoot = "")

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

if ([string]::IsNullOrWhiteSpace($DriveRoot)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $DriveRoot = if ($ScriptDir -match '\\Scripts$') { Split-Path -Parent $ScriptDir } else { $ScriptDir }
}

$LogDir      = Join-Path $DriveRoot "Log"
$DriveLetter = (Split-Path -Qualifier $DriveRoot).TrimEnd(':')
$DriveSpec   = "${DriveLetter}:"
$AnalysisLog = Join-Path $LogDir "LogAnalysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Msg, [string]$Color = "White")
    $stamp = "[$(Get-Date -Format 'yyyy.MM.dd HH:mm:ss')]"
    "$stamp $Msg" | Out-File $AnalysisLog -Append -Encoding UTF8
    Write-Host "$stamp $Msg" -ForegroundColor $Color
}

function Get-VssAdmin {
    if ([Environment]::Is64BitProcess) { return "vssadmin.exe" }
    $sn = Join-Path $env:windir "SysNative\vssadmin.exe"
    if (Test-Path $sn) { return $sn }
    return "vssadmin.exe"  # fallback
}

function Write-Section { param([string]$Title)
    Write-Log "`n╔══════════════════════════════════════╗" "DarkCyan"
    Write-Log "║  $($Title.PadRight(36))║" "DarkCyan"
    Write-Log "╚══════════════════════════════════════╝" "DarkCyan"
}

Write-Log "=== LogAnalyzer.ps1 – Automatikus elemzés ===" "Green"
Write-Log "Meghajtó: $DriveSpec  |  Log mappa: $LogDir" "Cyan"

if (!(Test-Path $LogDir)) {
    Write-Log "Log mappa nem létezik – még nem futottak le scriptek?" "Yellow"
    exit 0
}

# ── 1. Log fájlok összegyűjtése ───────────────────────────────────────────────
Write-Section "LOGFÁJLOK LISTÁJA"
$logFiles = Get-ChildItem -Path $LogDir -Filter "*.log" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending
Write-Log "Talált log fájlok: $($logFiles.Count)" "Cyan"
foreach ($lf in $logFiles) {
    Write-Log "  $($lf.LastWriteTime.ToString('yyyy.MM.dd HH:mm'))  $($lf.Name)  ($([math]::Round($lf.Length/1KB,1)) KB)" "DarkGray"
}

# ── 2. Hibák összesítése ──────────────────────────────────────────────────────
Write-Section "HIBÁK ÖSSZESÍTÉSE"
$allErrors   = @()
$allWarnings = @()
foreach ($lf in $logFiles) {
    $content = Get-Content $lf.FullName -ErrorAction SilentlyContinue
    $errors  = $content | Where-Object { $_ -match "HIBA|ERROR|SIKERTELEN|failed" }
    $warns   = $content | Where-Object { $_ -match "FIGYELEM|WARNING|WARN|Dirty" }
    $allErrors   += $errors
    $allWarnings += $warns
}

Write-Log "Összes hiba:       $($allErrors.Count)" $(if ($allErrors.Count -gt 0) { "Red" } else { "Green" })
Write-Log "Összes figyelmeztetés: $($allWarnings.Count)" $(if ($allWarnings.Count -gt 0) { "Yellow" } else { "Green" })

if ($allErrors.Count -gt 0) {
    Write-Log "`nHibák részletesen:" "Red"
    $allErrors | Select-Object -Unique | ForEach-Object { Write-Log "  $_" "Red" }
}
if ($allWarnings.Count -gt 0) {
    Write-Log "`nFigyelmeztetések:" "Yellow"
    $allWarnings | Select-Object -Unique | ForEach-Object { Write-Log "  $_" "Yellow" }
}

# ── 3. Felszabadított hely összesítése ───────────────────────────────────────
Write-Section "FELSZABADÍTOTT HELY"
$takaritolog = $logFiles | Where-Object { $_.Name -match "Takarito" } | Select-Object -First 1
if ($takaritolog) {
    $content = Get-Content $takaritolog.FullName
    $sizeLines = $content | Where-Object { $_ -match "Felszabadított" }
    foreach ($sl in $sizeLines) { Write-Log "  $sl" "Green" }
    $deletedLine = $content | Where-Object { $_ -match "Törölt elemek" } | Select-Object -Last 1
    if ($deletedLine) { Write-Log "  $deletedLine" "Green" }
}

# ── 4. Jelenlegi meghajtó állapot ─────────────────────────────────────────────
Write-Section "JELENLEGI MEGHAJTÓ ÁLLAPOT"
try {
    $drive = Get-PSDrive -Name $DriveLetter -ErrorAction Stop
    $totalBytes = $drive.Used + $drive.Free
    $freePct    = [math]::Round($drive.Free / $totalBytes * 100, 1)
    Write-Log "  Szabad: $([math]::Round($drive.Free/1GB,2)) GB  ($freePct%)" `
              $(if ($freePct -lt 10) { "Red" } elseif ($freePct -lt 20) { "Yellow" } else { "Green" })
    Write-Log "  Foglalt: $([math]::Round($drive.Used/1GB,2)) GB" "Cyan"
    Write-Log "  Összesen: $([math]::Round($totalBytes/1GB,2)) GB" "Cyan"
} catch { Write-Log "  Meghajtó adatok nem elérhetők." "Yellow" }

$dirtyCheck = & fsutil dirty query $DriveSpec 2>&1
$isDirty = $dirtyCheck -match "is Dirty"
Write-Log "  Dirty bit: $(if ($isDirty) { 'IGEN – javítás szükséges!' } else { 'Nem (rendben)' })" `
          $(if ($isDirty) { "Red" } else { "Green" })

# ── 5. Rejtett foglaltság vizsgálat ──────────────────────────────────────────
Write-Section "REJTETT FOGLALTSÁG BECSLÉS"
try {
    $vol = Get-WmiObject -Class Win32_Volume -Filter "DriveLetter='$DriveSpec'" -ErrorAction Stop
    $usedByFiles = (Get-ChildItem -Path $DriveRoot -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { !$_.PSIsContainer } |
                    Measure-Object -Property Length -Sum).Sum

    $usedByDrive = $vol.Capacity - $vol.FreeSpace
    $hidden = $usedByDrive - $usedByFiles

    Write-Log "  Meghajtó foglaltsága:    $([math]::Round($usedByDrive/1GB,3)) GB" "Cyan"
    Write-Log "  Látható fájlok mérete:   $([math]::Round($usedByFiles/1GB,3)) GB" "Cyan"
    Write-Log "  Becsült rejtett terület: $([math]::Round($hidden/1GB,3)) GB" `
              $(if ($hidden -gt 500MB) { "Red" } elseif ($hidden -gt 100MB) { "Yellow" } else { "Green" })

    if ($hidden -gt 500MB) {
        Write-Log "  AJÁNLÁS: Futtasd az NTFS_Reset.ps1-et a rejtett NTFS struktúrák törlésére!" "Red"
    }
} catch {
    Write-Log "  WMI adatok nem elérhetők: $($_.Exception.Message)" "Yellow"
}

# ── 6. Ajánlások ──────────────────────────────────────────────────────────────
Write-Section "AJÁNLÁSOK"

$recommendations = @()

if ($isDirty) {
    $recommendations += "[KRITIKUS] A meghajtó 'dirty' – futtasd a Chkdsk_Auto.ps1-et AZONNAL!"
}

# USN Journal vizsgálat
$usnQuery = & fsutil usn queryjournal $DriveSpec 2>&1 | Out-String
if ($usnQuery -match "Maximum Size\s*=\s*0x[1-9]") {
    $recommendations += "[FONTOS] USN Journal aktív és nagy. Futtasd az NTFS_Reset.ps1-et!"
}

# Shadow copies
$shadows = & (Get-VssAdmin) list shadows /for=$DriveSpec 2>&1 | Out-String
if ($shadows -notmatch "No items found") {
    $recommendations += "[FONTOS] Volume Shadow Copies találhatók. Futtasd az SVI_Cleanup.ps1-et!"
}

# Hibák alapján
if ($allErrors.Count -gt 5) {
    $recommendations += "[FIGYELEM] $($allErrors.Count) hiba a logokban. Ellenőrizd kézzel a Log/ mappát!"
}

if ($recommendations.Count -eq 0) {
    Write-Log "  Nincs sürgős teendő. A meghajtó állapota megfelelőnek tűnik." "Green"
} else {
    $i = 1
    foreach ($rec in $recommendations) {
        Write-Log "  [$i] $rec" "Yellow"
        $i++
    }
}

Write-Log "`n=== Elemzés kész ===" "Green"
Write-Log "Elemzési log: $AnalysisLog" "Cyan"

