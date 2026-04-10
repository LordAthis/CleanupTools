# ================================================
# Chkdsk_Auto.ps1  -  v0.8
# ================================================

<#
.SYNOPSIS
    CleanupTools – Chkdsk_Auto.ps1
    Automatikus fájlrendszer-ellenőrzés és javítás (Főleg külső meghajtón!)
    Hibás clusterek jelölése, elveszett cluster-láncok javítása, NTFS integritás helyreállítása.
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
$LogFile     = Join-Path $LogDir "Chkdsk_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

function Write-Log {
    param([string]$Msg, [string]$Color = "White")
    $stamp = "[$(Get-Date -Format 'yyyy.MM.dd HH:mm:ss')]"
    "$stamp $Msg" | Out-File $LogFile -Append -Encoding UTF8
    Write-Host "$stamp $Msg" -ForegroundColor $Color
}

Write-Log "=== Chkdsk_Auto.ps1 indítása ===" "Green"
Write-Log "Meghajtó: $DriveSpec" "Cyan"

# ── 1. Dirty bit ellenőrzés ───────────────────────────────────────────────────
Write-Log "--- 1. Dirty bit állapot ---" "Yellow"
$dirty = & fsutil dirty query $DriveSpec 2>&1
Write-Log "Dirty bit: $dirty" $(if ($dirty -match "is Dirty") { "Red" } else { "Green" })

# ── 2. Csak olvasható szkennelés először ──────────────────────────────────────
Write-Log "--- 2. Chkdsk olvasási teszt (javítás nélkül) ---" "Yellow"
Write-Log "Ez eltarthat néhány percig..." "DarkGray"
try {
    $scanResult = & chkdsk $DriveSpec /scan /perf 2>&1
    $scanText = $scanResult | Out-String
    Write-Log "Szkennelés eredménye:`n$scanText" "DarkCyan"

    $hasErrors = $scanText -match "errors found|Found \d+ errors|Errors detected"
    if ($hasErrors) {
        Write-Log "!! FÁJLRENDSZER HIBÁK TALÁLVA – javítás szükséges!" "Red"
    } else {
        Write-Log "Nem találhatók fájlrendszer hibák az olvasási tesztben." "Green"
    }
} catch {
    Write-Log "Szkennelés hiba: $($_.Exception.Message)" "Red"
    $hasErrors = $true  # Ismeretlen állapot – biztonságból javítást kérünk
}

# ── 3. Javítás futtatása ha hiba van vagy dirty ────────────────────────────────
$needsRepair = ($dirty -match "is Dirty") -or $hasErrors

if ($needsRepair) {
    Write-Log "--- 3. Chkdsk javítás futtatása ---" "Yellow"
    Write-Log "Paraméterek: /f (fix) /r (bad sectors) /x (unmount) /b (bad cluster re-eval)" "DarkGray"

    Write-Host "`n!! FIGYELEM: A chkdsk most JAVÍTANI fogja a fájlrendszert." -ForegroundColor Red
    Write-Host "   Ez akár 30-60 percig is eltarthat nagy meghajtón!" -ForegroundColor Red
    Write-Host "   A meghajtó automatikusan leválasztódik a javítás idejére." -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "Folytatás? (I/N)"
    if ($confirm -match "^[Ii]$") {
        try {
            # /f = hibák javítása, /r = bad sector keresés + adat-visszanyerés, /x = erőltetett unmount, /b = bad cluster újraértékelés
            $repairResult = & chkdsk $DriveSpec /f /r /x /b 2>&1
            $repairText = $repairResult | Out-String
            Write-Log "Javítás eredménye:`n$repairText" "Cyan"

            if ($repairText -match "Windows has made corrections|No further action") {
                Write-Log "Chkdsk javítás sikeres!" "Green"
            } elseif ($repairText -match "The volume is in use") {
                Write-Log "FIGYELEM: A meghajtó használatban van, nem lehet most javítani." "Red"
                Write-Log "Megoldás: Válaszd le a meghajtót, csatlakoztasd újra, és futtasd újra ezt a scriptet." "Yellow"
            } else {
                Write-Log "Javítás lefutott. Ellenőrizd a fenti kimenetet!" "Yellow"
            }
        } catch {
            Write-Log "HIBA chkdsk futtatása közben: $($_.Exception.Message)" "Red"
        }
    } else {
        Write-Log "Javítás kihagyva felhasználói döntés alapján." "Yellow"
    }
} else {
    Write-Log "--- 3. Javítás nem szükséges (nincs dirty bit, nincs hiba) ---" "Green"
}

# ── 4. NTFS integritás ellenőrzés (sfc, ha értelmes) ─────────────────────────
Write-Log "--- 4. NTFS log flush ---" "Yellow"
try {
    # Flush NTFS log a meghajtóra
    $flushResult = & fsutil volume flushLog $DriveSpec 2>&1
    Write-Log "NTFS log flush: $flushResult" "DarkCyan"
} catch {
    Write-Log "Log flush hiba: $($_.Exception.Message)" "Yellow"
}

# ── 5. Javítás utáni állapot ──────────────────────────────────────────────────
Write-Log "--- 5. Javítás utáni dirty bit állapot ---" "Yellow"
$dirtyAfter = & fsutil dirty query $DriveSpec 2>&1
Write-Log "Dirty bit (utána): $dirtyAfter" $(if ($dirtyAfter -match "is Dirty") { "Red" } else { "Green" })

if ($dirtyAfter -match "is Dirty") {
    Write-Log "!! A dirty bit még mindig be van állítva. Valószín leg fizikai hiba van a meghajtón." "Red"
    Write-Log "   Javasolt: Vizsgáld meg CrystalDiskInfo vagy hasonló eszközzel a S.M.A.R.T. adatokat!" "Yellow"
} else {
    Write-Log "Meghajtó állapota: CLEAN (rendben)" "Green"
}

Write-Log "=== Chkdsk_Auto kész ===" "Green"
Write-Log "Log: $LogFile" "Cyan"
