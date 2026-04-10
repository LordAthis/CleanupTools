# ================================================
# Takarito.ps1  -  v0.8
# ================================================

<#
.SYNOPSIS
    CleanupTools – Takarito.ps1
    Agresszív fájl/mappa törlés külső NTFS meghajtón.
    Saját fájljait és a Log/ mappát megőrzi.
    Rendszerfájlokat is töröl (külső meghajtó – nem rendszermeghajtó!).
.PARAMETER DriveRoot
    A takarítandó meghajtó gyökere. Ha nem adod meg, az aktuális script helyéről számolja ki.
#>

#Requires -RunAsAdministrator

param([string]$DriveRoot = "")

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# ── Útvonal meghatározás ──────────────────────────────────────────────────────
if ([string]::IsNullOrWhiteSpace($DriveRoot)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $DriveRoot = if ($ScriptDir -match '\\Scripts$') {
        Split-Path -Parent $ScriptDir
    } else { $ScriptDir }
}

$LogDir  = Join-Path $DriveRoot "Log"
$LogFile = Join-Path $LogDir "Takarito_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

# ── Saját fájlok – ezeket NEM törli ──────────────────────────────────────────
$ProtectedNames = @(
    "MasterCleanup.ps1","Takarito.ps1","NTFS_Reset.ps1",
    "SpaceDeepCheck.ps1","LogAnalyzer.ps1","Chkdsk_Auto.ps1",
    "SVI_Cleanup.ps1","Log","Scripts","_archive",
    ".gitignore","README.md","LICENSE"
)

function Write-Log {
    param([string]$Msg, [string]$Color = "White")
    $stamp = "[$(Get-Date -Format 'yyyy.MM.dd HH:mm:ss')]"
    "$stamp $Msg" | Out-File $LogFile -Append -Encoding UTF8
    Write-Host "$stamp $Msg" -ForegroundColor $Color
}

function Remove-ItemSafe {
    param([string]$Path, [switch]$Recurse)
    try {
        # Attribútumok törlése (rejtett, rendszer, csak olvasható)
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        $item.Attributes = 'Normal'
        if ($Recurse) {
            # Almappák attribútumait is töröljük
            Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
                ForEach-Object { try { $_.Attributes = 'Normal' } catch {} }
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        } else {
            Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
        }
        return $true
    } catch {
        Write-Log "SIKERTELEN törlés: $Path — $($_.Exception.Message)" "Red"
        return $false
    }
}

function Get-SizeGB { param([string]$Path)
    try {
        $bytes = (Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
                  Measure-Object -Property Length -Sum).Sum
        return [math]::Round($bytes / 1GB, 3)
    } catch { return 0 }
}

# ── Törlendő mappák/fájlok listája ───────────────────────────────────────────
$TargetFolders = @(
    # Windows rendszermappák (külső meghajtón maradtak)
    '$RECYCLE.BIN',
    'System Volume Information',
    'Windows\Temp',
    'Windows\SoftwareDistribution\Download',
    'Windows\Prefetch',
    'Windows\Logs',
    'Windows\CbsTemp',
    'Windows\Panther',
    'Windows\inf\setupapi*',
    'ProgramData\Microsoft\Windows\WER',
    'ProgramData\Microsoft\Windows\ActionCenter\Archive',
    # Felhasználói temp mappák (minden profil)
    'Users\*\AppData\Local\Temp',
    'Users\*\AppData\Local\Microsoft\Windows\INetCache',
    'Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files',
    'Users\*\AppData\Local\Microsoft\Windows\WebCache',
    'Users\*\AppData\Local\CrashDumps',
    'Users\*\AppData\Local\Microsoft\CryptnetUrlCache',
    'Users\*\AppData\Local\Microsoft\Windows\Explorer\ThumbCaches',
    # Böngésző cache-ek
    'Users\*\AppData\Local\Google\Chrome\User Data\*\Cache',
    'Users\*\AppData\Local\Google\Chrome\User Data\*\Code Cache',
    'Users\*\AppData\Local\Google\Chrome\User Data\*\GPUCache',
    'Users\*\AppData\Local\Microsoft\Edge\User Data\*\Cache',
    'Users\*\AppData\Local\Microsoft\Edge\User Data\*\Code Cache',
    'Users\*\AppData\Roaming\Mozilla\Firefox\Profiles\*\cache2',
    # Windows hibakereső és jelentések
    'Windows\Minidump',
    'Windows\memory.dmp',
    'Users\*\AppData\Local\Microsoft\Windows\WER',
    # Hibernálás, lapozófájl (ha van)
    'hiberfil.sys',
    'pagefile.sys',
    'swapfile.sys',
    # Windows Update maradványok
    'Windows\Installer\$PatchCache$',
    'Windows\SoftwareDistribution\DataStore',
    # Indexelő adatbázis
    'ProgramData\Microsoft\Search\Data',
    # Thumbs.db mindenhol
    'thumbs.db',
    'desktop.ini'  # csak ha tömegesen generált
)

# ── Fő törlési logika ─────────────────────────────────────────────────────────
Write-Log "=== Takarito.ps1 indítása ===" "Green"
Write-Log "Meghajtó gyökér: $DriveRoot" "Cyan"

$totalDeleted = 0
$totalErrors  = 0
$totalSizeGB  = 0

# 1. Célzott törlések wildcard alapon
Write-Log "--- 1. Célzott rendszermappák törlése ---" "Yellow"
foreach ($rel in $TargetFolders) {
    $pattern = Join-Path $DriveRoot $rel
    $items   = @()
    try {
        # Wildcard feloldás
        $items = Get-Item -Path $pattern -Force -ErrorAction SilentlyContinue
        if (!$items) {
            $items = Get-ChildItem -Path (Split-Path $pattern) -Filter (Split-Path -Leaf $pattern) `
                        -Force -ErrorAction SilentlyContinue
        }
    } catch {}

    foreach ($item in $items) {
        # Védett fájlok kihagyása
        if ($ProtectedNames -contains $item.Name) { continue }
        if ($item.FullName -like "*\Log\*") { continue }
        if ($item.FullName -like "*\Scripts\*" -and $item.Name -ne "Scripts") { continue }

        $sizeGB = if ($item.PSIsContainer) { Get-SizeGB $item.FullName } else {
            [math]::Round($item.Length / 1GB, 3)
        }
        Write-Log "Törlés: $($item.FullName) ($sizeGB GB)" "DarkYellow"
        $ok = Remove-ItemSafe -Path $item.FullName -Recurse:($item.PSIsContainer)
        if ($ok) {
            $totalDeleted++
            $totalSizeGB += $sizeGB
        } else { $totalErrors++ }
    }
}

# 2. Thumbs.db és desktop.ini rekurzív keresés
Write-Log "--- 2. Thumbs.db / desktop.ini törlése ---" "Yellow"
foreach ($fname in @("Thumbs.db", "ehthumbs.db", "Desktop.ini")) {
    Get-ChildItem -Path $DriveRoot -Filter $fname -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\Log\\|\\Scripts\\' } |
    ForEach-Object {
        Write-Log "Törlés: $($_.FullName)" "DarkYellow"
        $ok = Remove-ItemSafe -Path $_.FullName
        if ($ok) { $totalDeleted++; $totalSizeGB += [math]::Round($_.Length / 1GB, 6) }
        else { $totalErrors++ }
    }
}

# 3. 0 bájtos fájlok keresése és törlése (kivéve védett mappák)
Write-Log "--- 3. Nulla méretű fájlok törlése ---" "Yellow"
$zeroFiles = Get-ChildItem -Path $DriveRoot -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object {
        !$_.PSIsContainer -and
        $_.Length -eq 0 -and
        $_.FullName -notmatch '\\Log\\|\\Scripts\\|\\_archive\\' -and
        $ProtectedNames -notcontains $_.Name -and
        $_.Extension -notin @('.torrent','.txt','.crc','.md5','.url','.lnk','.ini')
    }

Write-Log "Nulla méretű fájlok száma: $($zeroFiles.Count)" "Cyan"
foreach ($f in $zeroFiles) {
    Write-Log "0 bájtos törlés: $($f.FullName)" "DarkGray"
    $ok = Remove-ItemSafe -Path $f.FullName
    if ($ok) { $totalDeleted++ } else { $totalErrors++ }
}

# 4. Üres mappák törlése (nem védett)
Write-Log "--- 4. Üres mappák törlése ---" "Yellow"
$emptyDirs = @()
do {
    $emptyDirs = Get-ChildItem -Path $DriveRoot -Recurse -Force -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '\\Log$|\\Scripts$|\\_archive$' -and
            $ProtectedNames -notcontains $_.Name -and
            (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0
        }
    foreach ($dir in $emptyDirs) {
        Write-Log "Üres mappa törlése: $($dir.FullName)" "DarkGray"
        $ok = Remove-ItemSafe -Path $dir.FullName
        if ($ok) { $totalDeleted++ } else { $totalErrors++ }
    }
} while ($emptyDirs.Count -gt 0)

# ── Összegzés ─────────────────────────────────────────────────────────────────
Write-Log "=== TAKARÍTÁS KÉSZ ===" "Green"
Write-Log "Törölt elemek száma: $totalDeleted" "Green"
Write-Log "Felszabadított hely (becsült): $([math]::Round($totalSizeGB, 2)) GB" "Green"
Write-Log "Hibák száma: $totalErrors" $(if ($totalErrors -gt 0) { "Red" } else { "Green" })
Write-Log "Log: $LogFile" "Cyan"

if ($totalErrors -gt 0) {
    Write-Host "`nFigyelem: $totalErrors törlés sikertelen volt. Nézd meg a logot!" -ForegroundColor Red
}
