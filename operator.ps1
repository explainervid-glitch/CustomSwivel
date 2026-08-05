# ============================================================
# Swivel 2 - Installer Script (PowerShell)
# Copies the packaged bundle to Program Files and adds a Start
# Menu entry. Run via install.bat, do not run this file directly.
#
# This lives in bin\ and installs from bin\Swivel\, because
# PackageApp.bat deletes and recreates bin\Swivel on every run.
# ============================================================

param(
    [switch]$Elevated
)

# ---- Names / layout (single place to change) ----
$AppName      = "Swivel 2"
$SourceFolder = "Swivel"                          # bundle folder next to this script
$InstallDir   = "C:\Program Files (x86)\Swivel2"
$ExeName      = "Swivel2.exe"
$ShortcutName = "Swivel 2.lnk"

# ---- Color helpers ----
function Write-Ok   ($msg) { Write-Host "  [OK] $msg"  -ForegroundColor Green  }
function Write-Warn ($msg) { Write-Host "  [!]  $msg"  -ForegroundColor Yellow }
function Write-Err  ($msg) { Write-Host "  [X]  $msg"  -ForegroundColor Red    }
function Write-Step ($msg) { Write-Host "`n  >>  $msg" -ForegroundColor Cyan   }

function Safe-Exit ($code) {
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit $code
}

trap {
    Write-Host ""
    Write-Err "Unexpected error: $_"
    Safe-Exit 1
}

# ============================================================
# 0. SELF-ELEVATE to Administrator if not already
# ============================================================
$isAdmin = ([Security.Principal.WindowsPrincipal]`
    [Security.Principal.WindowsIdentity]::GetCurrent()`
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "  Requesting administrator privileges..." -ForegroundColor Yellow

    $selfPath = $MyInvocation.MyCommand.Path
    if (-not $selfPath) { $selfPath = $PSCommandPath }
    if (-not $selfPath) {
        Write-Err "Cannot resolve script path. Please run via install.bat."
        Safe-Exit 1
    }

    $scriptDir = Split-Path -Parent $selfPath

    # A mapped network drive is not visible inside the elevated session, so
    # hand the elevated process a UNC path when there is one.
    try {
        $qualifier = (Split-Path -Qualifier $scriptDir).TrimEnd(':')
        $drive = Get-PSDrive -Name $qualifier -ErrorAction SilentlyContinue
        if ($drive -and $drive.DisplayRoot -like "\\*") {
            $scriptDir = $scriptDir -replace [regex]::Escape("$qualifier`:"), $drive.DisplayRoot
        }
    } catch {}

    # Build the target path first: -replace inside $( ) would be read as a
    # parameter of Join-Path rather than as an operator.
    $targetScript = (Join-Path $scriptDir "operator.ps1").Replace("'", "''")

    # A temp launcher avoids quoting a spaced path inside -Command.
    $tempLauncher = "$env:TEMP\Swivel2_elevate_launcher.ps1"
    Set-Content -Path $tempLauncher -Encoding UTF8 -Value @"
try {
    & '$targetScript' -Elevated
} catch {
    Write-Host `$_.Exception.Message -ForegroundColor Red
}
Read-Host 'Press Enter to exit'
"@

    try {
        Start-Process -FilePath "powershell.exe" `
                      -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", $tempLauncher `
                      -Verb RunAs `
                      -Wait
    } catch {
        Write-Err "Elevation cancelled or failed: $_"
        Safe-Exit 1
    }

    Remove-Item $tempLauncher -ErrorAction SilentlyContinue
    exit 0
}

# ============================================================
# BANNER
# ============================================================
Clear-Host
Write-Host ""
Write-Host "  ==================================================" -ForegroundColor DarkCyan
Write-Host "   Swivel 2 - Installer                            " -ForegroundColor Cyan
Write-Host "  ==================================================" -ForegroundColor DarkCyan
Write-Host ""

# ============================================================
# 1. RESOLVE PATHS
# ============================================================
Write-Step "Checking paths..."

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else {
    Split-Path -Parent $MyInvocation.MyCommand.Definition
}
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

$sourceDir = Join-Path $scriptDir $SourceFolder

Write-Ok "Source      : $sourceDir"
Write-Ok "Destination : $InstallDir"

if (-not (Test-Path (Join-Path $sourceDir $ExeName))) {
    Write-Host ""
    Write-Err "$SourceFolder\$ExeName not found."
    Write-Err "Run PackageApp.bat first. Expected layout:"
    Write-Host ""
    Write-Host "    bin\install.bat"                -ForegroundColor Gray
    Write-Host "    bin\operator.ps1"               -ForegroundColor Gray
    Write-Host "    bin\$SourceFolder\"             -ForegroundColor Gray
    Write-Host "      $ExeName"                     -ForegroundColor Gray
    Write-Host "      Adobe AIR\"                   -ForegroundColor Gray
    Write-Host "      META-INF\AIR\debug"           -ForegroundColor Gray
    Write-Host "      ffmpeg\win32\"                -ForegroundColor Gray
    Write-Host ""
    Safe-Exit 1
}

# The debug marker is what allows System.pause during frame capture.
# Without it the encoder throttling breaks, so warn rather than ship it quietly.
if (-not (Test-Path (Join-Path $sourceDir "META-INF\AIR\debug"))) {
    Write-Warn "META-INF\AIR\debug is missing from this bundle."
    Write-Warn "Conversion will drop frames. Re-run PackageApp.bat to regenerate it."
    Write-Host ""
    $go = Read-Host "  Install anyway? (y/N)"
    if ($go -ne "y") { Write-Warn "Installation cancelled."; Safe-Exit 0 }
}

# ============================================================
# 2. CHECK SWIVEL IS NOT RUNNING
# ============================================================
Write-Step "Checking for a running Swivel..."

$running = Get-Process -Name "Swivel2" -ErrorAction SilentlyContinue

if ($running) {
    Write-Warn "Swivel 2 is currently running."
    Write-Host ""
    Write-Host "  Choose an action:" -ForegroundColor White
    Write-Host "  [1] Close it automatically and continue" -ForegroundColor Gray
    Write-Host "  [2] Cancel" -ForegroundColor Gray
    Write-Host ""

    $choice = Read-Host "  Choice (1/2)"

    if ($choice -eq "1") {
        Stop-Process -Name "Swivel2" -Force
        Start-Sleep -Seconds 2
        Write-Ok "Swivel closed."
    } else {
        Write-Warn "Installation cancelled."
        Safe-Exit 0
    }
} else {
    Write-Ok "Swivel is not running."
}

# ============================================================
# 3. COPY THE BUNDLE
# ============================================================
Write-Step "Copying files to $InstallDir..."

try {
    if (Test-Path $InstallDir) {
        Remove-Item $InstallDir -Recurse -Force
        Write-Ok "Previous installation removed."
    }
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

    Copy-Item -Path (Join-Path $sourceDir "*") -Destination $InstallDir -Recurse -Force

    # The uninstaller lives beside this script, not inside the bundle, so it
    # has to be copied across explicitly.
    foreach ($file in @("uninstall.bat", "uninstall.ps1")) {
        $from = Join-Path $scriptDir $file
        if (Test-Path $from) { Copy-Item $from -Destination $InstallDir -Force }
        else { Write-Warn "$file not found -- the installed copy will have no uninstaller." }
    }

    Write-Ok "Files copied."
} catch {
    Write-Err "Failed to copy files: $_"
    Safe-Exit 1
}

# ============================================================
# 4. START MENU SHORTCUT
# ============================================================
Write-Step "Creating Start Menu entry..."

$startMenu = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs"
$shortcut  = Join-Path $startMenu $ShortcutName
$exePath   = Join-Path $InstallDir $ExeName

try {
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($shortcut)
    $link.TargetPath       = $exePath
    $link.WorkingDirectory = $InstallDir
    $link.IconLocation     = $exePath
    $link.Description      = "SWF to video converter"
    $link.Save()

    Write-Ok "Start Menu : $shortcut"
} catch {
    Write-Err "Could not create the Start Menu shortcut: $_"
    Safe-Exit 1
}

# ============================================================
# 5. ADD/REMOVE PROGRAMS ENTRY
# ============================================================
Write-Step "Registering with Add/Remove Programs..."

$registryKey  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Swivel2"
$uninstaller  = Join-Path $InstallDir "uninstall.bat"

try {
    if (-not (Test-Path $registryKey)) { New-Item -Path $registryKey -Force | Out-Null }

    $sizeKb = [int]((Get-ChildItem $InstallDir -Recurse -File |
        Measure-Object -Property Length -Sum).Sum / 1KB)

    Set-ItemProperty -Path $registryKey -Name "DisplayName"     -Value $AppName
    Set-ItemProperty -Path $registryKey -Name "DisplayIcon"     -Value $exePath
    Set-ItemProperty -Path $registryKey -Name "InstallLocation" -Value $InstallDir
    Set-ItemProperty -Path $registryKey -Name "Publisher"       -Value "Newgrounds.com, Inc."
    Set-ItemProperty -Path $registryKey -Name "UninstallString" -Value "`"$uninstaller`""
    Set-ItemProperty -Path $registryKey -Name "EstimatedSize"   -Value $sizeKb -Type DWord
    Set-ItemProperty -Path $registryKey -Name "NoModify"        -Value 1 -Type DWord
    Set-ItemProperty -Path $registryKey -Name "NoRepair"        -Value 1 -Type DWord

    Write-Ok "Listed in Settings > Apps."
} catch {
    Write-Warn "Could not register for Add/Remove Programs: $_"
    Write-Warn "Uninstalling will still work via uninstall.bat."
}

# ============================================================
# 6. VERIFICATION
# ============================================================
Write-Step "Verifying installation..."

$checks = @(
    @{ Path = $exePath;                                          Label = $ExeName            },
    @{ Path = (Join-Path $InstallDir "Adobe AIR");               Label = "Adobe AIR runtime" },
    @{ Path = (Join-Path $InstallDir "ffmpeg\win32\ffmpeg.exe"); Label = "ffmpeg.exe"        },
    @{ Path = (Join-Path $InstallDir "META-INF\AIR\debug");      Label = "debug marker"      },
    @{ Path = $shortcut;                                         Label = "Start Menu shortcut" },
    @{ Path = $uninstaller;                                      Label = "uninstall.bat"     }
)

$allOk = $true
foreach ($check in $checks) {
    if (Test-Path $check.Path) {
        Write-Ok $check.Label
    } else {
        Write-Err "$($check.Label) -- NOT FOUND!"
        $allOk = $false
    }
}

# ============================================================
# DONE
# ============================================================
Write-Host ""
Write-Host "  ==================================================" -ForegroundColor DarkCyan

if ($allOk) {
    Write-Host "   INSTALLATION SUCCESSFUL!                        " -ForegroundColor Green
    Write-Host "  ==================================================" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  $AppName is installed to:" -ForegroundColor White
    Write-Host "    $InstallDir" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Search 'Swivel' from the taskbar to launch it." -ForegroundColor Gray
    Write-Host "  The Animate panel will find it here automatically." -ForegroundColor DarkGray
    Write-Host ""
} else {
    Write-Host "   INSTALLATION COMPLETED WITH WARNINGS.          " -ForegroundColor Yellow
    Write-Host "  ==================================================" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  Some files were not found at the destination." -ForegroundColor Yellow
    Write-Host ""
}

Safe-Exit 0
