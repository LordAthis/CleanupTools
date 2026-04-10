# ================================================
# LogAnalyzer.ps1  -  v0.8
# ================================================

#Requires -RunAsAdministrator
<#
.SYNOPSIS
    CleanupTools - MasterCleanup.ps1
    Univerzalis szervizes eszkoz kulso NTFS meghajtok takaritasahoz.
    Futtatható a Scripts\ almappaból VAGY a meghajtó gyökeréből egyaránt.
.NOTES
    Karakterkódolás: A script minden kiírást ASCII-kompatibilis módon kezel,
    hogy sérült/vegyes kódolású rendszereken se törjön el.
#>

# ==============================================================================
# 1. KARAKTERKODOLAS ES KONZOL BEALLITAS
#    Sérült rendszereken a chcp és az OutputEncoding beállítása kritikus.
#    Ha a névfeloldás törött, SID-alapú fallback-et használunk.
# ==============================================================================
try {
    # Elsodleges: UTF-8 kenyszeritese
    $null = chcp 65001 2>$null
    [Console]::OutputEncoding        = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding         = [System.Text.Encoding]::UTF8
    $OutputEncoding                  = [System.Text.Encoding]::UTF8
    $env:PYTHONIOENCODING            = 'utf-8'
} catch {
    # Fallback: ha az UTF-8 beallitas sem megy, ASCII-ra esunk vissza
    try {
        $null = chcp 437 2>$null
        [Console]::OutputEncoding    = [System.Text.Encoding]::ASCII
        $OutputEncoding              = [System.Text.Encoding]::ASCII
    } catch { <# csend #> }
}

# Hibakezeles globalisan: ne alljon le a script vartalan kiveteltol
$ErrorActionPreference = 'SilentlyContinue'

# ==============================================================================
# 2. UTVONAL MEGHATAROZA S
#    Mukodik Scripts\ almappabol ES meghajtó gyökeréből is.
# ==============================================================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Ha a script a Scripts\ mappabol fut, eggyel feljebb a gyoker
if ($ScriptDir -match '\\Scripts$' -or $ScriptDir -match '\\Scripts\\?$') {
    $DriveRoot  = Split-Path -Parent $ScriptDir
    $ScriptsDir = $ScriptDir
} else {
    # A script a meghajtó gyökeréből fut
    $DriveRoot  = $ScriptDir
    $ScriptsDir = Join-Path $ScriptDir 'Scripts'
}

# Log mappa mindig a gyökér alatt van
$LogDir = Join-Path $DriveRoot 'Log'

# Log mappa letrehozasa (csendben, ha mar letezik)
if (-not (Test-Path $LogDir)) {
    $null = New-Item -ItemType Directory -Path $LogDir -Force
}

$MasterLogFile = Join-Path $LogDir ('MasterCleanup_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')

# ==============================================================================
# 3. LOGGING FUGGVENY
#    Minden kimenetet konzolra ES logfileba ir.
#    Szin csak a konzolra vonatkozik.
# ==============================================================================
function Write-Log {
    param(
        [string]$Message,
        [string]$Color = 'White',
        [switch]$NoTimestamp
    )
    if ($NoTimestamp) {
        $entry = $Message
    } else {
        $entry = '[' + (Get-Date -Format 'yyyy.MM.dd HH:mm:ss') + '] ' + $Message
    }

    # Logfile: UTF-8, BOM nelkul (szeles kompatibilitas)
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($entry + [Environment]::NewLine)
        $stream = [System.IO.File]::Open($MasterLogFile,
                    [System.IO.FileMode]::Append,
                    [System.IO.FileAccess]::Write,
                    [System.IO.FileShare]::Read)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Close()
    } catch { <# ha a log sem irható, csend #> }

    # Konzol
    Write-Host $entry -ForegroundColor $Color
}

# ==============================================================================
# 4. SEGITSEDFUGGVENYEK
# ==============================================================================

# Meghajtó betűjele és szabad hely
function Get-DriveInfo {
    $letter = (Split-Path -Qualifier $DriveRoot).TrimEnd(':')
    try {
        $wmi  = Get-WmiObject -Class Win32_LogicalDisk -Filter ("DeviceID='" + $letter + ":'") -ErrorAction Stop
        $free = [math]::Round($wmi.FreeSpace  / 1GB, 2)
        $tot  = [math]::Round($wmi.Size       / 1GB, 2)
        $used = [math]::Round(($wmi.Size - $wmi.FreeSpace) / 1GB, 2)
        return [PSCustomObject]@{
            Letter = $letter
            Spec   = $letter + ':'
            Free   = $free
            Used   = $used
            Total  = $tot
        }
    } catch {
        return [PSCustomObject]@{
            Letter = $letter
            Spec   = $letter + ':'
            Free   = 0
            Used   = 0
            Total  = 0
        }
    }
}

function Show-DriveBar {
    $d = Get-DriveInfo
    if ($d.Total -eq 0) {
        Write-Log '  [Meghajtó adatok nem elérhetők]' 'DarkGray'
        return
    }
    $freePct = [math]::Round($d.Free / $d.Total * 100, 1)
    $color   = if ($freePct -lt 10) { 'Red' } elseif ($freePct -lt 20) { 'Yellow' } else { 'Cyan' }
    Write-Log ("  Meghajtó: " + $d.Spec + "  |  " +
               "Foglalt: " + $d.Used  + " GB  |  " +
               "Szabad: "  + $d.Free  + " GB  |  " +
               "Osszes: "  + $d.Total + " GB  (" + $freePct + "% szabad)") $color
}

# Script inditasa parameterezessel
function Invoke-CleanupScript {
    param([string]$FileName)

    # Keresesi sorrend: Scripts\ → gyoker
    $candidates = @(
        (Join-Path $ScriptsDir $FileName),
        (Join-Path $DriveRoot  $FileName)
    )
    $found = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $found) {
        Write-Log ("HIBA: $FileName nem talalhato! Keresve: " + ($candidates -join ', ')) 'Red'
        return
    }

    Write-Log (">>> Indul: $FileName  ($found)") 'Yellow'
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass `
            -File $found `
            -DriveRoot $DriveRoot 2>&1 | ForEach-Object {
                Write-Log ("    " + $_) 'DarkGray'
            }
        Write-Log ("<<< Kesz: $FileName") 'Green'
    } catch {
        Write-Log ("HIBA $FileName futtatasa kozben: " + $_.Exception.Message) 'Red'
    }
}

# ==============================================================================
# 5. GYORS DIAGNOSZTIKA (1-2 perc, ajánlással)
#    Dirty bit, shadow copies, szabad hely, rejtett foglaltsag becslese.
#    NEM indit el mas scriptet — csak olvas es javasol.
# ==============================================================================
function Start-QuickDiag {
    Clear-Host
    Write-Log '================================================' 'Cyan' -NoTimestamp
    Write-Log '  GYORS DIAGNOSZTIKA' 'Cyan' -NoTimestamp
    Write-Log '================================================' 'Cyan' -NoTimestamp

    $d      = Get-DriveInfo
    $spec   = $d.Spec
    $issues = @()   # ide gyujtjuk a problemakat
    $recs   = @()   # ajanlasok

    # --- 5a. Alapadatok ---
    Write-Log '' 'White' -NoTimestamp
    Write-Log '[1] Meghajtó alapadatok' 'Yellow'
    Show-DriveBar

    # --- 5b. Dirty bit ---
    Write-Log '' 'White' -NoTimestamp
    Write-Log '[2] Dirty bit ellenorzese' 'Yellow'
    try {
        $dirtyOut = & fsutil dirty query $spec 2>&1 | Out-String
        if ($dirtyOut -match 'Dirty') {
            Write-Log "    FIGYELEM: A meghajto 'dirty' allapotban van!" 'Red'
            $issues += 'Dirty bit be van allitva'
            $recs   += '[KRITIKUS] Futtasd a Chkdsk_Auto.ps1-et!'
        } else {
            Write-Log '    Dirty bit: tiszta (OK)' 'Green'
        }
    } catch {
        Write-Log ('    Dirty bit lekerdezes sikertelen: ' + $_.Exception.Message) 'DarkGray'
    }

    # --- 5c. USN Journal merete ---
    Write-Log '' 'White' -NoTimestamp
    Write-Log '[3] USN Change Journal merete' 'Yellow'
    try {
        $usnOut = & fsutil usn queryjournal $spec 2>&1 | Out-String
        # Maximum Size kiolvasasa hexbol
        if ($usnOut -match 'Maximum Size\s*=\s*(0x[0-9A-Fa-f]+)') {
            $usnMaxHex = $Matches[1]
            $usnMaxGB  = [math]::Round([Convert]::ToInt64($usnMaxHex, 16) / 1GB, 2)
            $usnColor  = if ($usnMaxGB -gt 0.5) { 'Red' } else { 'Green' }
            Write-Log ("    USN Journal max. merete: $usnMaxGB GB") $usnColor
            if ($usnMaxGB -gt 0.5) {
                $issues += "USN Journal: $usnMaxGB GB"
                $recs   += '[FONTOS] Futtasd az NTFS_Reset.ps1-et (USN Journal torles)!'
            }
        } elseif ($usnOut -match 'No journal') {
            Write-Log '    USN Journal nem aktiv (OK)' 'Green'
        } else {
            Write-Log ('    USN Journal allapot: ' + ($usnOut.Trim() -replace '\s+', ' ')) 'DarkGray'
        }
    } catch {
        Write-Log ('    USN lekerdezes sikertelen: ' + $_.Exception.Message) 'DarkGray'
    }

    # --- 5d. Shadow Copies ---
    Write-Log '' 'White' -NoTimestamp
    Write-Log '[4] Volume Shadow Copies' 'Yellow'
    try {
        $shadowOut = & vssadmin list shadows /for=$spec 2>&1 | Out-String
        if ($shadowOut -match 'No items found|Nincsenek elemek') {
            Write-Log '    Shadow Copies: nincsenek (OK)' 'Green'
        } else {
            # Peldanyok megszamlalasa
            $count = ([regex]::Matches($shadowOut, 'Shadow Copy ID')).Count
            Write-Log ("    Shadow Copies talalhatok: $count db") 'Red'
            $issues += "Shadow Copies: $count db"
            $recs   += '[FONTOS] Futtasd az SVI_Cleanup.ps1-et!'
        }
    } catch {
        Write-Log ('    Shadow Copy lekerdezes sikertelen: ' + $_.Exception.Message) 'DarkGray'
    }

    # --- 5e. Rejtett foglaltsag becsles ---
    Write-Log '' 'White' -NoTimestamp
    Write-Log '[5] Rejtett foglaltsag becsles' 'Yellow'
    try {
        $wmi = Get-WmiObject -Class Win32_LogicalDisk `
                   -Filter ("DeviceID='" + $d.Letter + ":'") -ErrorAction Stop
        $driveUsed = $wmi.Size - $wmi.FreeSpace

        Write-Log '    Latható fajlok osszeszamolasa (ez eltarthat egy percig)...' 'DarkGray'
        $visibleBytes = (
            Get-ChildItem -Path $DriveRoot -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer } |
            Measure-Object -Property Length -Sum
        ).Sum

        if ($visibleBytes -gt 0) {
            $hidden    = $driveUsed - $visibleBytes
            $hiddenGB  = [math]::Round($hidden   / 1GB, 2)
            $visibleGB = [math]::Round($visibleBytes / 1GB, 2)
            $driveGB   = [math]::Round($driveUsed    / 1GB, 2)

            Write-Log ("    Meghajto foglalt:  $driveGB GB") 'Cyan'
            Write-Log ("    Lathato fajlok:    $visibleGB GB") 'Cyan'

            $hidColor = if ($hidden -gt 500MB) { 'Red' } elseif ($hidden -gt 100MB) { 'Yellow' } else { 'Green' }
            Write-Log ("    Rejtett terület:   $hiddenGB GB") $hidColor

            if ($hidden -gt 500MB) {
                $issues += "Rejtett foglaltsag: $hiddenGB GB"
                $recs   += '[FONTOS] Futtasd az NTFS_Reset.ps1-et, majd a SpaceDeepCheck.ps1-et!'
            }
        } else {
            Write-Log '    Nem sikerult a latható fajlok meretét lekerdezni.' 'DarkGray'
        }
    } catch {
        Write-Log ('    Becsles sikertelen: ' + $_.Exception.Message) 'DarkGray'
    }

    # --- 5f. System Volume Information merete ---
    Write-Log '' 'White' -NoTimestamp
    Write-Log '[6] System Volume Information merete' 'Yellow'
    $sviPath = Join-Path $DriveRoot 'System Volume Information'
    if (Test-Path $sviPath) {
        try {
            $sviBytes = (
                Get-ChildItem -LiteralPath $sviPath -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum
            ).Sum
            $sviGB    = [math]::Round($sviBytes / 1GB, 3)
            $sviColor = if ($sviGB -gt 0.5) { 'Red' } elseif ($sviGB -gt 0.1) { 'Yellow' } else { 'Green' }
            Write-Log ("    SVI merete: $sviGB GB") $sviColor
            if ($sviGB -gt 0.5) {
                $issues += "SVI: $sviGB GB"
                $recs   += '[FONTOS] Futtasd az SVI_Cleanup.ps1-et!'
            }
        } catch {
            Write-Log '    SVI mappa hozzaferhetetlen (access denied) - ez gyanús!' 'Yellow'
            $issues += 'SVI mappa zarolva (hozzaferhetetlen)'
            $recs   += '[FONTOS] Futtasd az SVI_Cleanup.ps1-et (jogosultsag-visszaszerzes)!'
        }
    } else {
        Write-Log '    SVI mappa nem letezik (OK)' 'Green'
    }

    # --- 5g. Hibafajlok a gyokerben ---
    Write-Log '' 'White' -NoTimestamp
    Write-Log '[7] Rendszerfajlok a gyokerben (hiberfil, pagefile)' 'Yellow'
    foreach ($fn in @('hiberfil.sys', 'pagefile.sys', 'swapfile.sys')) {
        $fp = Join-Path $DriveRoot $fn
        if (Test-Path $fp) {
            try {
                $fsz = [math]::Round((Get-Item $fp -Force).Length / 1GB, 2)
                Write-Log ("    TALALT: $fn  ($fsz GB)") 'Red'
                $issues += "$fn a gyokerben: $fsz GB"
                $recs   += "[FONTOS] $fn torles szukseges (NTFS_Reset.ps1)!"
            } catch {
                Write-Log ("    TALALT (de nem merheto): $fn") 'Red'
                $issues += "$fn a gyokerben (zárolt)"
                $recs   += "[FONTOS] $fn torles szukseges (NTFS_Reset.ps1)!"
            }
        }
    }
    if ($issues -notmatch 'hiberfil|pagefile|swapfile') {
        Write-Log '    Nincs ilyen fajl a gyokerben (OK)' 'Green'
    }

    # --- 5h. Osszefoglalas ---
    Write-Log '' 'White' -NoTimestamp
    Write-Log '================================================' 'Cyan' -NoTimestamp
    Write-Log '  DIAGNOSZTIKA EREDMENYE' 'Cyan' -NoTimestamp
    Write-Log '================================================' 'Cyan' -NoTimestamp

    if ($issues.Count -eq 0) {
        Write-Log '  Nem talaltam problemat! A meghajto tisztanak tunik.' 'Green'
        Write-Log '  Ha meg mindig van rejtett foglaltsag, futtasd a SpaceDeepCheck.ps1-et.' 'Yellow'
    } else {
        Write-Log ("  Talalt problemak szama: " + $issues.Count) 'Red'
        Write-Log '' 'White' -NoTimestamp
        $i = 1
        foreach ($iss in $issues) {
            Write-Log ("  Problem " + $i + ": " + $iss) 'Red'
            $i++
        }
        Write-Log '' 'White' -NoTimestamp
        Write-Log '  Javasolt lepesek:' 'Yellow'
        $recs | Select-Object -Unique | ForEach-Object {
            Write-Log ("  -> " + $_) 'Yellow'
        }
    }

    Write-Log '' 'White' -NoTimestamp
    Write-Log ('  Log mentve: ' + $MasterLogFile) 'DarkGray'
    Write-Log '================================================' 'Cyan' -NoTimestamp
    Read-Host "`n  [ENTER] a fomenthez"
}

# ==============================================================================
# 6. FOMENU
# ==============================================================================
function Show-Menu {
    Clear-Host
    $d = Get-DriveInfo

    Write-Host ''
    Write-Host '  +--------------------------------------------------+' -ForegroundColor Cyan
    Write-Host '  |      CleanupTools  -  MasterCleanup v0.8     |' -ForegroundColor Cyan
    Write-Host '  +--------------------------------------------------+' -ForegroundColor Cyan
    Write-Host ("  |  Gyoker: " + $DriveRoot.PadRight(41) + "|") -ForegroundColor Cyan
    Write-Host ("  |  Log:    " + $LogDir.PadRight(41)    + "|") -ForegroundColor Cyan
    Write-Host '  +--------------------------------------------------+' -ForegroundColor Cyan
    Write-Host ''

    # Szabad hely szin-kodolva
    $freePct  = if ($d.Total -gt 0) { [math]::Round($d.Free / $d.Total * 100, 1) } else { 0 }
    $barColor = if ($freePct -lt 10) { 'Red' } elseif ($freePct -lt 20) { 'Yellow' } else { 'Green' }
    Write-Host ("  Meghajto: " + $d.Spec + "  Szabad: " + $d.Free + " GB / " + $d.Total + " GB  (" + $freePct + "%)") -ForegroundColor $barColor
    Write-Host ''

    Write-Host '  [1]  Gyors diagnosztika + ajanlasok  (START IDE)' -ForegroundColor Green
    Write-Host '  ---' -ForegroundColor DarkGray
    Write-Host '  [2]  SVI_Cleanup.ps1   - System Volume Information torles'
    Write-Host '  [3]  NTFS_Reset.ps1        - USN Journal, Shadow Copies, hiberfil'
    Write-Host '  [4]  Takarito.ps1          - Fajlok, cache, szemet torles'
    Write-Host '  [5]  SpaceDeepCheck.ps1    - Melyvizsgalat (rejtett foglaltsag)'
    Write-Host '  [6]  Chkdsk_Auto.ps1       - Fajlrendszer ellenorzes + javitas'
    Write-Host '  [7]  LogAnalyzer.ps1       - Log elemzes + javaslatok'
    Write-Host '  ---' -ForegroundColor DarkGray
    Write-Host '  [8]  TELJES TAKARITAS (2+3+4+5+6 sorban)'  -ForegroundColor Yellow
    Write-Host '  ---' -ForegroundColor DarkGray
    Write-Host '  [0]  Kilepes' -ForegroundColor DarkGray
    Write-Host ''
}

# ==============================================================================
# 7. MAIN LOOP
# ==============================================================================
Write-Log '=== MasterCleanup.ps1 indul ===' 'Green'
Write-Log ('Gyoker: ' + $DriveRoot) 'Cyan'
Write-Log ('Scripts: ' + $ScriptsDir) 'Cyan'
Write-Log ('Log: ' + $MasterLogFile) 'Cyan'

do {
    Show-Menu
    $choice = Read-Host '  Valasztas'
    $choice = $choice.Trim()

    switch ($choice) {
        '1' {
            Write-Log '--- Gyors diagnosztika indul ---' 'Yellow'
            Start-QuickDiag
        }
        '2' {
            Write-Log '--- SVI_Cleanup.ps1 ---' 'Yellow'
            Invoke-CleanupScript 'SVI_Cleanup.ps1'
            Read-Host "`n  [ENTER] a fomenthez"
        }
        '3' {
            Write-Log '--- NTFS_Reset.ps1 ---' 'Yellow'
            Invoke-CleanupScript 'NTFS_Reset.ps1'
            Read-Host "`n  [ENTER] a fomenthez"
        }
        '4' {
            Write-Log '--- Takarito.ps1 ---' 'Yellow'
            Invoke-CleanupScript 'Takarito.ps1'
            Read-Host "`n  [ENTER] a fomenthez"
        }
        '5' {
            Write-Log '--- SpaceDeepCheck.ps1 ---' 'Yellow'
            Invoke-CleanupScript 'SpaceDeepCheck.ps1'
            Read-Host "`n  [ENTER] a fomenthez"
        }
        '6' {
            Write-Log '--- Chkdsk_Auto.ps1 ---' 'Yellow'
            Invoke-CleanupScript 'Chkdsk_Auto.ps1'
            Read-Host "`n  [ENTER] a fomenthez"
        }
        '7' {
            Write-Log '--- LogAnalyzer.ps1 ---' 'Yellow'
            Invoke-CleanupScript 'LogAnalyzer.ps1'
            Read-Host "`n  [ENTER] a fomenthez"
        }
        '8' {
            Write-Log '=== TELJES TAKARITAS INDUL ===' 'Yellow'
            Show-DriveBar
            Write-Log '--- 1/5: SVI Cleanup ---' 'Yellow'
            Invoke-CleanupScript 'SVI_Cleanup.ps1'
            Write-Log '--- 2/5: NTFS Reset ---' 'Yellow'
            Invoke-CleanupScript 'NTFS_Reset.ps1'
            Write-Log '--- 3/5: Takarito ---' 'Yellow'
            Invoke-CleanupScript 'Takarito.ps1'
            Write-Log '--- 4/5: SpaceDeepCheck ---' 'Yellow'
            Invoke-CleanupScript 'SpaceDeepCheck.ps1'
            Write-Log '--- 5/5: Chkdsk ---' 'Yellow'
            Invoke-CleanupScript 'Chkdsk_Auto.ps1'
            Write-Log '=== TELJES TAKARITAS KESZ ===' 'Green'
            Show-DriveBar
            Invoke-CleanupScript 'LogAnalyzer.ps1'
            Read-Host "`n  [ENTER] a fomenthez"
        }
        '0' {
            Write-Log 'Kilepes.' 'DarkGray'
        }
        default {
            Write-Host '  Ervenytelen valasztas!' -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($choice -ne '0')

Write-Log '=== MasterCleanup.ps1 befejezve ===' 'Green'
