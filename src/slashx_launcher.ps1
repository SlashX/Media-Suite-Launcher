# =========================================================
# SLASHX MEDIA SUITE - MASTER LAUNCHER (PowerShell) v4.1.1
# Cross-platform: Windows PowerShell 5.1 + PowerShell 7+ (Core)
# =========================================================

[CmdletBinding()]
param(
    [Alias('h')] [switch]$Help,
    [Alias('v')] [switch]$Version
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# Forteaza UTF-8 in console (rezolva box-drawing chars / diacritice corupte)
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $OutputEncoding = [System.Text.Encoding]::UTF8
    }
} catch {
    # In unele hostari (ex: ISE) [Console] nu e disponibil — ignoram
}

# =========================================================
# CONFIGURATION MAP
# =========================================================
$SuiteVersion = '4.1.1'

$AV_Root    = 'AV-Encoder-Suite'
$Photo_Root = 'Photo-Encoder-Suite'

$AV_Repo_URL    = 'https://github.com/SlashX/AV-Encoder-Suite.git'
$Photo_Repo_URL = 'https://github.com/SlashX/Photo-Encoder-Suite.git'

# Folosim Join-Path pentru cross-platform (Linux/macOS PowerShell 7+ folosesc /)
$AV_Tools_Dir    = Join-Path $AV_Root    'tools'
$Photo_Tools_Dir = Join-Path $Photo_Root 'tools'
$AV_Tests_Dir    = Join-Path $AV_Root    'tests'
$Photo_Tests_Dir = Join-Path $Photo_Root 'tests'

$AV_Launcher    = 'av_launcher.ps1'
$Photo_Launcher = 'photo_launcher.ps1'

$DebugMode = if ($env:SLASHX_DEBUG -eq '1') { $true } else { $false }
# =========================================================

# ── CLI args (--help / --version) ────────────────────────
if ($Help) {
    @"
SlashX Media Suite Launcher v$SuiteVersion

Usage:
  .\slashx_launcher.ps1 [options]

Options:
  -Help, -h        Show this help message
  -Version, -v     Show version

Environment:
  SLASHX_DEBUG=1   Enable verbose debug logging

Without arguments, the interactive menu is launched.
"@ | Write-Host
    exit 0
}
if ($Version) {
    Write-Host "SlashX Media Suite Launcher v$SuiteVersion (PowerShell)"
    exit 0
}

# Detectare director script (compatibil PS5 si PS7)
# Defensive: PSScriptRoot poate fi null in scenarii exotice (copy-paste in consola,
# Invoke-Expression, etc). Fallback in cascada catre PWD ca ultim resort.
if ($PSScriptRoot) {
    $ScriptDir = $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Definition -and (Test-Path -LiteralPath $MyInvocation.MyCommand.Definition -ErrorAction SilentlyContinue)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
} else {
    Write-Host '[!] Nu pot detecta directorul scriptului. Folosesc directorul curent.' -ForegroundColor Yellow
    $ScriptDir = (Get-Location).Path
}

# Repo-urile AV/Photo se cloneaza un nivel mai sus de src/ (in root-ul Media-Suite-Launcher)
# astfel incat structura finala e:
#   Media-Suite-Launcher\
#   |-- src\slashx_launcher.ps1   <- acest script
#   |-- AV-Encoder-Suite\         <- clonat de [5]
#   +-- Photo-Encoder-Suite\      <- clonat de [5]
try {
    $BaseDir = (Resolve-Path -LiteralPath (Join-Path $ScriptDir '..') -ErrorAction Stop).Path
} catch {
    Write-Host "[!] Nu pot rezolva BaseDir din ScriptDir='$ScriptDir'. Folosesc parent direct." -ForegroundColor Yellow
    $BaseDir = Split-Path -Parent $ScriptDir
    if (-not $BaseDir) { $BaseDir = $ScriptDir }
}

# ── Helpers ──────────────────────────────────────────────
function Write-Dbg {
    param([string]$Message)
    if ($DebugMode) { Write-Host "[DEBUG] $Message" -ForegroundColor DarkGray }
}

function Wait-ForEnter {
    param([string]$Message = 'Press Enter to continue...')
    Read-Host -Prompt $Message | Out-Null
}

function Get-HostOS {
    if ($IsWindows -or ($PSVersionTable.PSVersion.Major -le 5)) {
        return "Windows ($([Environment]::OSVersion.Version))"
    }
    if ($IsMacOS)   { return 'macOS (PowerShell 7+)' }
    if ($IsLinux)   { return 'Linux (PowerShell 7+)' }
    return 'Unknown OS'
}

# Returneaza executabilul PowerShell potrivit pentru subprocess
# (pwsh pe PS7+, powershell pe Windows PS5.1)
function Get-PowerShellExe {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $exe = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($exe) { return $exe.Source }
    }
    $exe = Get-Command powershell -ErrorAction SilentlyContinue
    if ($exe) { return $exe.Source }
    return $null
}

# Ruleaza un script .ps1 in proces NOU (izolat de launcher)
# Astfel un 'exit' in script nu omoara launcher-ul.
function Invoke-IsolatedScript {
    param(
        [Parameter(Mandatory)] [string]$ScriptPath,
        [Parameter(Mandatory)] [string]$WorkingDir
    )

    if (-not (Test-Path $ScriptPath)) {
        Write-Host "[!] Script inexistent: $ScriptPath" -ForegroundColor Red
        return 1
    }

    $psExe = Get-PowerShellExe
    if (-not $psExe) {
        Write-Host '[!] Nu pot gasi powershell/pwsh in PATH.' -ForegroundColor Red
        return 1
    }

    Write-Dbg "Running $ScriptPath in $WorkingDir using $psExe"

    $oldLocation = Get-Location
    try {
        Set-Location $WorkingDir -ErrorAction Stop
        # Argumentele ca array — PS le quoteaza corect chiar si cu spatii in cale
        & $psExe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath
        return $LASTEXITCODE
    } catch {
        Write-Host "[!] Eroare la rulare: $_" -ForegroundColor Red
        return 1
    } finally {
        Set-Location $oldLocation
    }
}

# ── Helper: sync unul singur repo (la nivel global, nu nested) ─
function Sync-SlashxRepo {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Url,
        [Parameter(Mandatory)] [string]$BasePath
    )
    $path = Join-Path $BasePath $Name
    $gitDir = Join-Path $path '.git'

    if (Test-Path $gitDir) {
        Write-Host "--> Updating $Name..." -ForegroundColor Yellow
        git -C $path pull --ff-only
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[!] Update esuat pentru $Name (conflict local sau retea)" -ForegroundColor Red
            Write-Host "    Verifica: git -C `"$path`" status" -ForegroundColor Yellow
            return $false
        }
    } else {
        Write-Host "--> Installing $Name from GitHub..." -ForegroundColor Green
        git clone $Url $path
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[!] Clone esuat pentru $Name" -ForegroundColor Red
            return $false
        }
    }
    Write-Host ''
    return $true
}

# ── Git install/update ───────────────────────────────────
function Invoke-GitRepos {
    Clear-Host
    Write-Host '=================================================' -ForegroundColor Cyan
    Write-Host '           SUITE INSTALLER & UPDATER             ' -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host '=================================================' -ForegroundColor Cyan
    Write-Host ''

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "[!] Eroare: 'git' nu este instalat sau nu e in PATH." -ForegroundColor Red
        Write-Host '    Windows: winget install Git.Git'   -ForegroundColor Yellow
        Write-Host '    macOS  : brew install git'         -ForegroundColor Yellow
        Write-Host '    Linux  : sudo apt install git'     -ForegroundColor Yellow
        Write-Host ''
        Wait-ForEnter
        return $false
    }

    $allOk = $true
    if (-not (Sync-SlashxRepo -Name $AV_Root    -Url $AV_Repo_URL    -BasePath $BaseDir)) { $allOk = $false }
    if (-not (Sync-SlashxRepo -Name $Photo_Root -Url $Photo_Repo_URL -BasePath $BaseDir)) { $allOk = $false }

    if ($allOk) {
        Write-Host 'Process complete.' -ForegroundColor Green
    } else {
        Write-Host 'Process complete cu erori.' -ForegroundColor Yellow
    }
    Wait-ForEnter
    return $allOk
}

# ── Repo status ──────────────────────────────────────────
function Show-RepoStatus {
    Clear-Host
    Write-Host '=================================================' -ForegroundColor Cyan
    Write-Host '              REPO STATUS                        ' -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host '=================================================' -ForegroundColor Cyan
    Write-Host ''

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host '[!] git nu este instalat.' -ForegroundColor Red
        Wait-ForEnter; return
    }

    foreach ($r in @($AV_Root, $Photo_Root)) {
        $p = Join-Path $BaseDir $r
        Write-Host "── $r ──" -ForegroundColor Yellow
        if (-not (Test-Path (Join-Path $p '.git'))) {
            Write-Host '  Nu este instalat (foloseste optiunea [5])' -ForegroundColor Red
            Write-Host ''
            continue
        }

        $branch = git -C $p rev-parse --abbrev-ref HEAD 2>$null
        Write-Host "  Branch : $branch"
        $lastCommit = git -C $p log -1 --pretty=format:'%h %s (%ar)' 2>$null
        Write-Host "  Commit : $lastCommit"

        $localChanges = (git -C $p status --porcelain 2>$null | Measure-Object).Count
        if ($localChanges -gt 0) {
            Write-Host "  Modificari locale: $localChanges fisier(e) — pull poate esua" -ForegroundColor Yellow
        } else {
            Write-Host '  Tree curat' -ForegroundColor Green
        }

        # Fetch silent + ahead/behind (best-effort)
        git -C $p fetch --quiet 2>$null
        $ab = git -C $p rev-list --left-right --count '@{u}...HEAD' 2>$null
        if ($ab) {
            $parts = $ab -split '\s+' | Where-Object { $_ -match '^\d+$' }
            if ($parts.Count -ge 2) {
                $behind = [int]$parts[0]
                $ahead  = [int]$parts[1]
                if ($behind -gt 0) { Write-Host "  $behind commit(s) noi pe remote (fa pull)" -ForegroundColor Yellow }
                if ($ahead  -gt 0) { Write-Host "  $ahead commit(s) locale necommit-uite remote" -ForegroundColor Yellow }
            }
        }
        Write-Host ''
    }
    Wait-ForEnter
}

# ── Submeniu Tools/Tests ─────────────────────────────────
function Show-MappedMenu {
    param(
        [Parameter(Mandatory)] [string]$Title,
        [Parameter(Mandatory)] [string]$AVPath,
        [Parameter(Mandatory)] [string]$PhotoPath,
        [Parameter(Mandatory)] [string]$BgColor
    )

    while ($true) {
        Clear-Host
        Write-Host '=================================================' -ForegroundColor Cyan
        Write-Host "                 $Title                      " -ForegroundColor White -BackgroundColor $BgColor
        Write-Host '=================================================' -ForegroundColor Cyan

        $fileList = @()
        foreach ($p in @($AVPath, $PhotoPath)) {
            $fullPath = Join-Path $BaseDir $p
            if (Test-Path $fullPath) {
                $items = Get-ChildItem -Path $fullPath -Filter '*.ps1' -File -ErrorAction SilentlyContinue
                if ($items) { $fileList += $items }
            }
        }

        if ($fileList.Count -eq 0) {
            Write-Host '  [!] Nu am gasit fisiere .ps1 in director.' -ForegroundColor Red
            Write-Host '      Foloseste [5] din meniul principal sau ruleaza .sh daca' -ForegroundColor Yellow
            Write-Host '      ai doar fisiere bash.' -ForegroundColor Yellow
            Wait-ForEnter
            return
        }

        for ($i = 0; $i -lt $fileList.Count; $i++) {
            $prefix = if ($fileList[$i].FullName -like "*$AV_Root*") { '[AV]' } else { '[Photo]' }
            Write-Host "  [$($i+1)] $prefix $($fileList[$i].Name)" -ForegroundColor Yellow
        }

        Write-Host ''
        Write-Host '  [0] Back' -ForegroundColor Red
        $choice = Read-Host ' Select item'

        if ($choice -eq '0') { return }

        if ($choice -match '^\d+$' -and [int]$choice -gt 0 -and [int]$choice -le $fileList.Count) {
            $file = $fileList[[int]$choice - 1]
            $root = if ($file.FullName -like "*$AV_Root*") { $AV_Root } else { $Photo_Root }
            $workDir = Join-Path $BaseDir $root

            Write-Host ''
            Write-Host "--> Running $($file.Name)..." -ForegroundColor Green
            $rc = Invoke-IsolatedScript -ScriptPath $file.FullName -WorkingDir $workDir
            if ($rc -ne 0) {
                Write-Host "[!] Script-ul s-a incheiat cu exit code $rc" -ForegroundColor Yellow
            }
            Wait-ForEnter
        } else {
            Write-Host '[!] Selectie invalida.' -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}

# ── Run main launcher (AV sau Photo) ─────────────────────
function Invoke-MainLauncher {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$LauncherName
    )
    $launcherPath = Join-Path (Join-Path $BaseDir $Root) $LauncherName
    if (-not (Test-Path $launcherPath)) {
        Write-Host "Error: $Root nu este instalat. Foloseste [5] din meniu." -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }
    $rc = Invoke-IsolatedScript -ScriptPath $launcherPath -WorkingDir (Join-Path $BaseDir $Root)
    if ($rc -ne 0) {
        Write-Host "[!] Launcher terminat cu cod $rc" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
}

# ── Main Menu ────────────────────────────────────────────
$hostOS = Get-HostOS

# Trap pentru Ctrl+C — la PS, [Console]::TreatControlCAsInput n-ar fi user-friendly
# In schimb folosim try/finally pe bucla principala
try {
    while ($true) {
        Clear-Host
        Write-Host '=================================================' -ForegroundColor Cyan
        Write-Host "            SLASHX MEDIA SUITE v$SuiteVersion            " -ForegroundColor White -BackgroundColor DarkBlue
        Write-Host '=================================================' -ForegroundColor Cyan
        Write-Host " Host OS : $hostOS" -ForegroundColor Green
        if ($DebugMode) { Write-Host ' Debug   : ON' -ForegroundColor Yellow }
        Write-Host '=================================================' -ForegroundColor Cyan
        Write-Host "  [1] Video Processing ($AV_Root)"           -ForegroundColor Yellow
        Write-Host "  [2] Photo Processing ($Photo_Root)"         -ForegroundColor Yellow
        Write-Host '  [3] Tools & Updaters (Mapped)'              -ForegroundColor Yellow
        Write-Host '  [4] Tests & Diagnostics (Mapped)'           -ForegroundColor Yellow
        Write-Host '  [5] Install / Update Suite (Git)'           -ForegroundColor Green
        Write-Host '  [6] Repo Status'                            -ForegroundColor Yellow
        Write-Host ''
        Write-Host '  [0] Exit' -ForegroundColor Red
        Write-Host '=================================================' -ForegroundColor Cyan

        $opt = Read-Host ' Select option'
        switch ($opt) {
            '1' { Invoke-MainLauncher -Root $AV_Root    -LauncherName $AV_Launcher }
            '2' { Invoke-MainLauncher -Root $Photo_Root -LauncherName $Photo_Launcher }
            '3' { Show-MappedMenu -Title 'TOOLS MENU' -AVPath $AV_Tools_Dir -PhotoPath $Photo_Tools_Dir -BgColor 'DarkCyan' }
            '4' { Show-MappedMenu -Title 'TESTS MENU' -AVPath $AV_Tests_Dir -PhotoPath $Photo_Tests_Dir -BgColor 'DarkMagenta' }
            '5' { Invoke-GitRepos | Out-Null }
            '6' { Show-RepoStatus }
            '0' {
                Write-Host ''
                Write-Host 'Exiting SlashX Media Suite. Have a great day!' -ForegroundColor Green
                Write-Host ''
                exit 0
            }
            ''  { } # Enter gol — re-deseneaza
            default {
                Write-Host '[!] Selectie invalida.' -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
} finally {
    # Cleanup pe iesire (incl. Ctrl+C in Read-Host)
    if ($DebugMode) { Write-Host '[DEBUG] Launcher terminat.' -ForegroundColor DarkGray }
}
