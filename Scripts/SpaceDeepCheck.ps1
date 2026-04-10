# ================================================
# SpaceDeepCheck.ps1  -  v0.8
# ================================================

<#
.SYNOPSIS
    CleanupTools – SpaceDeepCheck.ps1
    Mély helyvizsgálat: megkeresi a rejtett foglaltság forrásait.
    Megvizsgálja az összes NTFS metaadat-struktúrát, rejtett fájlt és foglalt területet.
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

$DriveLetter = (Split-Path -Qualifier $DriveRoot).TrimEnd(':')
$DriveSpec   = "${DriveLetter}:"
$LogDir      = Join-Path $DriveRoot "Log"
$LogFile     = Join-Path $LogDir "SpaceDeepCheck_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$ReportFile  = Join-Path $LogDir "SpaceReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

function Write-Log {
    param([string]$Msg, [string]$Color = "White")
    $stamp = "[$(Get-Date -Format 'yyyy.MM.dd HH:mm:ss')]"
    "$stamp $Msg" | Out-File $LogFile -Append -Encoding UTF8
    $Msg | Out-File $ReportFile -Append -Encoding UTF8
    Write-Host "$stamp $Msg" -ForegroundColor $Color
}

function Get-VssAdmin {
    if ([Environment]::Is64BitProcess) { return "vssadmin.exe" }
    $sn = Join-Path $env:windir "SysNative\vssadmin.exe"
    if (Test-Path $sn) { return $sn }
    return "vssadmin.exe"  # fallback
}

function Format-GB { param([long]$bytes)
    if ($bytes -gt 1GB) { return "$([math]::Round($bytes/1GB,3)) GB" }
    if ($bytes -gt 1MB) { return "$([math]::Round($bytes/1MB,2)) MB" }
    return "$([math]::Round($bytes/1KB,1)) KB"
}

function Get-FolderSize { param([string]$Path)
    try {
        return (Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    } catch { return 0 }
}

Write-Log "=== SpaceDeepCheck.ps1 - Mély helyvizsgálat ===" "Green"
Write-Log "Meghajtó: $DriveSpec  |  Gyökér: $DriveRoot" "Cyan"
Write-Log "Időpont: $(Get-Date -Format 'yyyy.MM.dd HH:mm:ss')" "Cyan"
Write-Log "══════════════════════════════════════════════════════" "DarkGray"

# ── 1. Alapadatok ─────────────────────────────────────────────────────────────
Write-Log "`n[1] MEGHAJTÓ ALAPADATOK" "Yellow"
try {
    $drive = Get-PSDrive -Name $DriveLetter -ErrorAction Stop
    $totalBytes = $drive.Used + $drive.Free
    $usedPct    = [math]::Round($drive.Used / $totalBytes * 100, 1)
    Write-Log "  Teljes:  $(Format-GB $totalBytes)" "Cyan"
    Write-Log "  Foglalt: $(Format-GB $drive.Used)  ($usedPct%)" "Cyan"
    Write-Log "  Szabad:  $(Format-GB $drive.Free)" "Green"
} catch {
    Write-Log "  Meghajtó adatok lekérése sikertelen: $($_.Exception.Message)" "Red"
}

# WMI-ből pontosabb adat (allokált vs ténylegesen látható fájlok különbsége)
try {
    $vol = Get-WmiObject -Class Win32_Volume -Filter "DriveLetter='$DriveSpec'" -ErrorAction Stop
    Write-Log "  WMI Kapacitás: $(Format-GB $vol.Capacity)" "DarkCyan"
    Write-Log "  WMI Szabad:    $(Format-GB $vol.FreeSpace)" "DarkCyan"
    Write-Log "  WMI Foglalt:   $(Format-GB ($vol.Capacity - $vol.FreeSpace))" "DarkCyan"
    Write-Log "  Fájlrendszer:  $($vol.FileSystem)" "DarkCyan"
    Write-Log "  Cluster méret: $($vol.BlockSize) bájt" "DarkCyan"
} catch {
    Write-Log "  WMI Volume lekérés hiba: $($_.Exception.Message)" "Yellow"
}

# ── 2. Látható fájlok összmérete ──────────────────────────────────────────────
Write-Log "`n[2] LÁTHATÓ FÁJLOK ÖSSZMÉRETE (normál + rejtett)" "Yellow"
Write-Log "  Számolás folyamatban (ez eltarthat egy ideig)..." "DarkGray"
$visibleSize = 0
$visibleCount = 0
Get-ChildItem -Path $DriveRoot -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { !$_.PSIsContainer } |
    ForEach-Object {
        $visibleSize += $_.Length
        $visibleCount++
    }
Write-Log "  Látható fájlok száma: $visibleCount" "Cyan"
Write-Log "  Látható fájlok mérete: $(Format-GB $visibleSize)" "Cyan"

try {
    $drive2 = Get-PSDrive -Name $DriveLetter
    $hidden = ($drive2.Used) - $visibleSize
    if ($hidden -gt 100MB) {
        Write-Log "  !! REJTETT FOGLALTSÁG: $(Format-GB $hidden) !!" "Red"
        Write-Log "     Ez az NTFS metaadatokban, USN Journalban vagy egyébben van." "Red"
    } else {
        Write-Log "  Rejtett foglaltság: $(Format-GB $hidden) (normális tartomány)" "Green"
    }
} catch {}

# ── 3. NTFS metaadatok vizsgálata ─────────────────────────────────────────────
Write-Log "`n[3] NTFS METAADATOK (fsutil)" "Yellow"

# USN Journal
try {
    $usn = & fsutil usn queryjournal $DriveSpec 2>&1
    Write-Log "  USN Journal:`n$($usn | ForEach-Object { "    $_" } | Out-String)" "Cyan"
    # Maximum size kinyerése
    $maxLine = $usn | Where-Object { $_ -match "Maximum Size" }
    if ($maxLine) { Write-Log "  >> $maxLine" "Red" }
} catch {
    Write-Log "  USN lekérés hiba: $($_.Exception.Message)" "Yellow"
}

# Dirty bit
try {
    $dirty = & fsutil dirty query $DriveSpec 2>&1
    Write-Log "  Dirty bit: $dirty" $(if ($dirty -match "Dirty") { "Red" } else { "Green" })
} catch {}

# Volume info
try {
    $volinfo = & fsutil volume diskfree $DriveSpec 2>&1
    Write-Log "  Volume Diskfree:`n$($volinfo | ForEach-Object { "    $_" } | Out-String)" "DarkCyan"
} catch {}

# ── 4. Shadow Copies ──────────────────────────────────────────────────────────
Write-Log "`n[4] VOLUME SHADOW COPIES" "Yellow"
try {
    $shadows = & (Get-VssAdmin) list shadows /for=$DriveSpec 2>&1
    if ($shadows -match "No items found") {
        Write-Log "  Shadow Copies: nincsenek (rendben)" "Green"
    } else {
        Write-Log "  Shadow Copies megtalálva!`n$($shadows | ForEach-Object { "    $_" } | Out-String)" "Red"
    }
    $shadowStorage = & (Get-VssAdmin) list shadowstorage /for=$DriveSpec 2>&1
    Write-Log "  Shadow Storage: $($shadowStorage | Out-String)" "DarkCyan"
} catch {
    Write-Log "  VSS lekérés hiba: $($_.Exception.Message)" "Yellow"
}

# ── 5. Rejtett rendszerfájlok a gyökérben ─────────────────────────────────────
Write-Log "`n[5] REJTETT RENDSZERFÁJLOK A GYÖKÉRBEN" "Yellow"
$rootHidden = Get-ChildItem -Path $DriveRoot -Force -ErrorAction SilentlyContinue |
              Where-Object { $_.Attributes -match "Hidden|System" }
foreach ($item in $rootHidden) {
    $size = if ($item.PSIsContainer) { Get-FolderSize $item.FullName } else { $item.Length }
    Write-Log "  [$($item.Attributes)] $($item.Name)  — $(Format-GB $size)" `
              $(if ($size -gt 500MB) { "Red" } elseif ($size -gt 100MB) { "Yellow" } else { "DarkGray" })
}

# ── 6. TOP 20 legnagyobb mappa ────────────────────────────────────────────────
Write-Log "`n[6] TOP 20 LEGNAGYOBB MAPPA" "Yellow"
$folders = Get-ChildItem -Path $DriveRoot -Directory -Force -ErrorAction SilentlyContinue
$folderSizes = foreach ($f in $folders) {
    $sz = Get-FolderSize $f.FullName
    [PSCustomObject]@{ Name = $f.Name; FullName = $f.FullName; SizeBytes = $sz; SizeText = Format-GB $sz }
}
$folderSizes | Sort-Object SizeBytes -Descending | Select-Object -First 20 |
    ForEach-Object {
        Write-Log "  $(($_.SizeText).PadLeft(12))  $($_.Name)" `
                  $(if ($_.SizeBytes -gt 1GB) { "Red" } elseif ($_.SizeBytes -gt 500MB) { "Yellow" } else { "White" })
    }

# ── 7. Speciális NTFS fájlok ($MFT, stb.) ────────────────────────────────────
Write-Log "`n[7] NTFS MFT ÉS SPECIÁLIS FÁJLOK" "Yellow"
try {
    $ntfsInfo = & fsutil fsinfo ntfsinfo $DriveSpec 2>&1
    Write-Log "  NTFS Info:`n$($ntfsInfo | ForEach-Object { "    $_" } | Out-String)" "DarkCyan"
} catch {
    Write-Log "  NTFS info hiba: $($_.Exception.Message)" "Yellow"
}

# ── 8. Chkdsk állapot ─────────────────────────────────────────────────────────
Write-Log "`n[8] CHKDSK ELŐZETES ÁLLAPOT" "Yellow"
try {
    $chkdskRead = & chkdsk $DriveSpec /scan /perf 2>&1
    Write-Log "$($chkdskRead | ForEach-Object { "  $_" } | Out-String)" "DarkCyan"
} catch {
    Write-Log "  Chkdsk futtatás hiba: $($_.Exception.Message)" "Yellow"
}

# ── Összegzés és ajánlások ────────────────────────────────────────────────────
Write-Log "`n══════════════════════════════════════════════════════" "DarkGray"
Write-Log "=== VIZSGÁLAT KÉSZ ===" "Green"
Write-Log "Log fájl:    $LogFile" "Cyan"
Write-Log "Riport fájl: $ReportFile" "Cyan"
Write-Host "`nA részletes riport itt található: $ReportFile" -ForegroundColor Yellow


