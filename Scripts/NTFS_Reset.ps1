# ================================================
# NTFS_Reset.ps1  -  v0.8
# ================================================

<#
.SYNOPSIS
    CleanupTools – NTFS_Reset.ps1
    A rejtett foglaltságot okozó NTFS struktúrák teljes törlése:
    - USN Change Journal
    - Volume Shadow Copies
    - Windows Indexing (Windows Search)
    - $Extend metaadatok reset
.PARAMETER DriveRoot
    A meghajtó gyökere (pl. E:\). Ha nem adod meg, az aktuális script helyéből számítja.
#>

#Requires -RunAsAdministrator

param([string]$DriveRoot = "")

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# ── Útvonal és logolás ────────────────────────────────────────────────────────
if ([string]::IsNullOrWhiteSpace($DriveRoot)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $DriveRoot = if ($ScriptDir -match '\\Scripts$') { Split-Path -Parent $ScriptDir } else { $ScriptDir }
}

$DriveLetter = (Split-Path -Qualifier $DriveRoot).TrimEnd(':')
$DriveSpec   = "${DriveLetter}:"
$LogDir      = Join-Path $DriveRoot "Log"
$LogFile     = Join-Path $LogDir "NTFS_Reset_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

function Write-Log {
    param([string]$Msg, [string]$Color = "White")
    $stamp = "[$(Get-Date -Format 'yyyy.MM.dd HH:mm:ss')]"
    "$stamp $Msg" | Out-File $LogFile -Append -Encoding UTF8
    Write-Host "$stamp $Msg" -ForegroundColor $Color
}

# 32-bit PS / WOW64 redirection javítás: SysNative fallback
function Get-VssAdmin {
    if ([Environment]::Is64BitProcess) { return "vssadmin.exe" }
    $sn = Join-Path $env:windir "SysNative\vssadmin.exe"
    if (Test-Path $sn) { return $sn }
    return "vssadmin.exe"  # fallback
}

function Get-FreeSpaceGB {
    $drive = Get-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue
    if ($drive) { return [math]::Round($drive.Free / 1GB, 2) }
    return 0
}

Write-Log "=== NTFS_Reset.ps1 indítása ===" "Green"
Write-Log "Meghajtó: $DriveSpec  ($DriveRoot)" "Cyan"
Write-Log "Szabad hely induláskor: $(Get-FreeSpaceGB) GB" "Cyan"

# ── 1. USN Change Journal törlése ─────────────────────────────────────────────
# Az USN Journal tipikusan 2-4 GB-ot foglal el rejtetten az $Extend\$UsnJrnl fájlban
Write-Log "--- 1. USN Change Journal törlése ---" "Yellow"
try {
    $usnBefore = & fsutil usn queryjournal $DriveSpec 2>&1
    Write-Log "USN Journal állapot (előtte):`n$usnBefore" "DarkCyan"

    $deleteResult = & fsutil usn deletejournal /D $DriveSpec 2>&1
    Write-Log "USN törlés eredménye: $deleteResult" "Cyan"

    # Kis méretű journal visszaállítása (1 MB) – ha kell a Windows számára
    # $createResult = & fsutil usn createjournal m=1048576 a=4096 $DriveSpec 2>&1
    # Write-Log "USN újralétrehozás: $createResult" "DarkGray"

    Write-Log "USN Change Journal törölve." "Green"
} catch {
    Write-Log "HIBA az USN törlés közben: $($_.Exception.Message)" "Red"
}

# ── 2. Volume Shadow Copies törlése ──────────────────────────────────────────
Write-Log "--- 2. Volume Shadow Copies (VSS) törlése ---" "Yellow"
try {
    # Meglévő shadowok listázása
    $shadows = & (Get-VssAdmin) list shadows /for=$DriveSpec 2>&1
    Write-Log "Shadow Copies (előtte):`n$shadows" "DarkCyan"

    # Minden shadow copy törlése a meghajtóról
    $deleteVss = & (Get-VssAdmin) delete shadows /for=$DriveSpec /quiet 2>&1
    Write-Log "VSS törlés: $deleteVss" "Cyan"

    # WMI-n keresztül is (ha a vssadmin nem törölt mindent)
    $wmiShadows = Get-WmiObject Win32_ShadowCopy -ErrorAction SilentlyContinue |
                  Where-Object { $_.VolumeName -like "*$DriveLetter*" }
    foreach ($s in $wmiShadows) {
        Write-Log "WMI Shadow törlése: $($s.ID)" "DarkYellow"
        $s.Delete() | Out-Null
    }
    Write-Log "Volume Shadow Copies törölve." "Green"
} catch {
    Write-Log "HIBA a VSS törlés közben: $($_.Exception.Message)" "Red"
}

# ── 3. Windows Search / Indexelési adatbázis törlése ─────────────────────────
Write-Log "--- 3. Windows Search Index törlése ---" "Yellow"
try {
    # Indexelési szolgáltatás leállítása
    $svc = Get-Service -Name "WSearch" -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Log "WSearch szolgáltatás leállítva." "Cyan"
    }

    $indexPaths = @(
        "$DriveRoot\ProgramData\Microsoft\Search\Data",
        "$DriveRoot\Windows\system32\config\systemprofile\AppData\Local\Microsoft\Windows\Caches",
        "$DriveRoot\ProgramData\Microsoft\Windows\Caches"
    )
    foreach ($p in $indexPaths) {
        if (Test-Path $p) {
            Write-Log "Index mappa törlése: $p" "DarkYellow"
            try {
                Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue |
                    ForEach-Object { try { $_.Attributes = 'Normal' } catch {} }
                Remove-Item -Path $p -Recurse -Force -ErrorAction Stop
                Write-Log "Törölve: $p" "Green"
            } catch {
                Write-Log "HIBA: $p – $($_.Exception.Message)" "Red"
            }
        }
    }
} catch {
    Write-Log "HIBA az indexelési adatok törlése közben: $($_.Exception.Message)" "Red"
}

# ── 4. $Extend metaadat területek reset ──────────────────────────────────────
Write-Log "--- 4. NTFS $Extend objektumok vizsgálata ---" "Yellow"
try {
    # $Quota reset (kvóta adatok)
    $quotaResult = & fsutil quota disable $DriveSpec 2>&1
    Write-Log "Quota letiltás: $quotaResult" "DarkCyan"

    # Dirty bit vizsgálat
    $dirtyResult = & fsutil dirty query $DriveSpec 2>&1
    Write-Log "Dirty bit állapot: $dirtyResult" "Cyan"
    if ($dirtyResult -match "is Dirty") {
        Write-Log "FIGYELEM: A meghajtó 'dirty' – chkdsk javítás szükséges!" "Red"
    }

    # Reparse point vizsgálat
    $reparseResult = & fsutil reparsepoint query $DriveRoot 2>&1
    Write-Log "Reparse point ($DriveRoot): $reparseResult" "DarkCyan"
} catch {
    Write-Log "HIBA az NTFS metaadatok kezelése közben: $($_.Exception.Message)" "Red"
}

# ── 5. Hibernáció kikapcsolása (ha be van kapcsolva) ─────────────────────────
Write-Log "--- 5. Hibernáció fájl kezelése ---" "Yellow"
$hiberfil = Join-Path $DriveRoot "hiberfil.sys"
if (Test-Path $hiberfil) {
    Write-Log "Hiberfil.sys megtalálva! ($([math]::Round((Get-Item $hiberfil -Force).Length / 1GB, 2)) GB)" "Red"
    try {
        # Ha ez a rendszermeghajtó lenne, powercfg-gel kellene – de külső meghajtón csak törölhetjük
        (Get-Item $hiberfil -Force).Attributes = 'Normal'
        Remove-Item $hiberfil -Force -ErrorAction Stop
        Write-Log "Hiberfil.sys törölve." "Green"
    } catch {
        Write-Log "HIBA hiberfil.sys törlése közben: $($_.Exception.Message)" "Red"
    }
} else {
    Write-Log "Hiberfil.sys nem található (rendben)." "Green"
}

# ── 6. Lapozófájl ─────────────────────────────────────────────────────────────
Write-Log "--- 6. Lapozófájl (pagefile.sys) kezelése ---" "Yellow"
foreach ($pf in @("pagefile.sys","swapfile.sys")) {
    $pfPath = Join-Path $DriveRoot $pf
    if (Test-Path $pfPath) {
        $pfSize = [math]::Round((Get-Item $pfPath -Force).Length / 1GB, 2)
        Write-Log "$pf megtalálva ($pfSize GB) – törlési kísérlet..." "Red"
        try {
            (Get-Item $pfPath -Force).Attributes = 'Normal'
            Remove-Item $pfPath -Force -ErrorAction Stop
            Write-Log "$pf törölve." "Green"
        } catch {
            Write-Log "HIBA $pf törlése közben: $($_.Exception.Message)" "Red"
            Write-Log "Tipp: Lehetséges, hogy zárolt. Próbáld meg WinPE-ből!" "Yellow"
        }
    }
}

# ── Összegzés ─────────────────────────────────────────────────────────────────
Write-Log "=== NTFS_Reset kész ===" "Green"
Write-Log "Szabad hely utána: $(Get-FreeSpaceGB) GB" "Green"
Write-Log "Log: $LogFile" "Cyan"
Write-Host "`nJavasolt: Következő lépésként futtasd a Chkdsk_Auto.ps1-et!" -ForegroundColor Yellow

