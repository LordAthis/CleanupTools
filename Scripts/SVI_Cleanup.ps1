<#
.SYNOPSIS
    CleanupTools – SVI_Cleanup_v2.ps1
    System Volume Information teljes kiürítése és jogosultság-visszaszerzése.
    Ez az egyik leggyakoribb forrása a rejtett 5 GB+ foglaltságnak.
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
$SviPath     = Join-Path $DriveRoot "System Volume Information"
$LogDir      = Join-Path $DriveRoot "Log"
$LogFile     = Join-Path $LogDir "SVI_Cleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

function Write-Log {
    param([string]$Msg, [string]$Color = "White")
    $stamp = "[$(Get-Date -Format 'yyyy.MM.dd HH:mm:ss')]"
    "$stamp $Msg" | Out-File $LogFile -Append -Encoding UTF8
    Write-Host "$stamp $Msg" -ForegroundColor $Color
}

Write-Log "=== SVI_Cleanup_v2.ps1 indítása ===" "Green"
Write-Log "Meghajtó: $DriveSpec" "Cyan"

function Get-VssAdmin {
    if ([Environment]::Is64BitProcess) { return "vssadmin.exe" }
    $sn = Join-Path $env:windir "SysNative\vssadmin.exe"
    if (Test-Path $sn) { return $sn }
    return "vssadmin.exe"  # fallback
}

if (!(Test-Path $SviPath)) {
    Write-Log "System Volume Information mappa nem létezik – kész." "Green"
    exit 0
}

# ── 1. Méret mérés ────────────────────────────────────────────────────────────
Write-Log "--- 1. SVI méret mérése ---" "Yellow"
try {
    $sviSize = (Get-ChildItem -LiteralPath $SviPath -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
    $sviGB = [math]::Round($sviSize / 1GB, 3)
    Write-Log "SVI jelenlegi mérete: $sviGB GB" "Cyan"
} catch {
    Write-Log "Méret mérés sikertelen (hozzáférési hiba) – folytatás..." "Yellow"
}

# ── 2. Shadow Copies törlése a VSS-en keresztül ───────────────────────────────
Write-Log "--- 2. Shadow Copies törlése ---" "Yellow"
try {
    $vssOut = & vssadmin delete shadows /for=$DriveSpec /quiet 2>&1
    Write-Log "VSS törlés: $vssOut" "Cyan"
} catch {
    Write-Log "VSS törlés hiba: $($_.Exception.Message)" "Red"
}

# ── 3. Jogosultság visszaszerzése (takeown + icacls) ─────────────────────────
Write-Log "--- 3. Tulajdonjog visszaszerzése (takeown) ---" "Yellow"
try {
    $takeown = & takeown /f $SviPath /r /d Y 2>&1
    Write-Log "Takeown: $takeown" "DarkCyan"

    $icacls = & icacls $SviPath /grant "$env:USERNAME:(F)" /t /c /q 2>&1
    Write-Log "ICacls: $icacls" "DarkCyan"

    # Administrators full control
    $icacls2 = & icacls $SviPath /grant "Administrators:(F)" /t /c /q 2>&1
    Write-Log "ICacls Admins: $icacls2" "DarkCyan"
} catch {
    Write-Log "HIBA a jogosultságok beállítása közben: $($_.Exception.Message)" "Red"
}

# ── 4. Tartalom törlése ───────────────────────────────────────────────────────
Write-Log "--- 4. SVI tartalom törlése ---" "Yellow"
try {
    # Attribútumok törlése minden fájlon
    Get-ChildItem -LiteralPath $SviPath -Recurse -Force -ErrorAction SilentlyContinue |
        ForEach-Object {
            try { $_.Attributes = 'Normal' } catch {}
        }

    # Tartalom törlése (maga a mappa marad – Windows néha újraírja)
    Get-ChildItem -LiteralPath $SviPath -Force -ErrorAction SilentlyContinue |
        ForEach-Object {
            try {
                Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
                Write-Log "Törölve: $($_.FullName)" "DarkYellow"
            } catch {
                Write-Log "HIBA: $($_.FullName) – $($_.Exception.Message)" "Red"
            }
        }
    Write-Log "SVI tartalom törölve." "Green"
} catch {
    Write-Log "HIBA az SVI törlése közben: $($_.Exception.Message)" "Red"
}

# ── 5. System Restore letiltása erre a meghajtóra ────────────────────────────
Write-Log "--- 5. System Restore letiltása a meghajtóra ---" "Yellow"
try {
    # WMI-n keresztül
    $restoreResult = & vssadmin delete shadows /for=$DriveSpec /oldest /quiet 2>&1
    Write-Log "Oldest shadow delete: $restoreResult" "DarkCyan"

    # Rendszer visszaállítás letiltása (külső meghajtón amúgy sem kellene futni)
    Disable-ComputerRestore -Drive $DriveSpec -ErrorAction SilentlyContinue
    Write-Log "System Restore letiltva erre a meghajtóra." "Green"
} catch {
    Write-Log "System Restore letiltás: $($_.Exception.Message)" "Yellow"
}

# ── 6. SVI mappa rejtett + rendszer attribútum visszaállítása ────────────────
Write-Log "--- 6. SVI mappa védelem visszaállítása ---" "Yellow"
try {
    $sviItem = Get-Item -LiteralPath $SviPath -Force -ErrorAction SilentlyContinue
    if ($sviItem) {
        $sviItem.Attributes = 'Hidden,System'
        Write-Log "SVI mappa attribútumok visszaállítva (Hidden+System)." "Green"
    }
} catch {
    Write-Log "Attribútum visszaállítás: $($_.Exception.Message)" "Yellow"
}

Write-Log "=== SVI_Cleanup_v2 kész ===" "Green"
Write-Log "Log: $LogFile" "Cyan"
