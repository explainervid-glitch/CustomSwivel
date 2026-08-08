# ============================================================
# Swivel 2 - Uninstaller (PowerShell)
# Removes the installed app, its Start Menu entry and its
# Add/Remove Programs registration.
# Run via uninstall.bat, do not run this file directly.
#
# A copy is placed in the install folder, so this works whether
# run from the build tree or from Program Files.
# ============================================================

param(
    [switch]$Elevated
)

# ---- Names / layout (must match operator.ps1) ----
$AppName      = "Swivel 2"
$InstallDir   = "C:\Program Files (x86)\Swivel2"
$ShortcutName = "Swivel 2.lnk"
$RegistryKey  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Swivel2"
$AppDataDir   = Join-Path $env:APPDATA "com.newgrounds.swivel.Swivel2"

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
        Write-Err "Cannot resolve script path. Please run via uninstall.bat."
        Safe-Exit 1
    }

    # Copy to temp before elevating: the elevated session may be removing the
    # very folder this script is running from.
    $tempCopy = "$env:TEMP\Swivel2_uninstall.ps1"
    Copy-Item -Path $selfPath -Destination $tempCopy -Force

    $tempLauncher = "$env:TEMP\Swivel2_uninstall_launcher.ps1"
    Set-Content -Path $tempLauncher -Encoding UTF8 -Value @"
try {
    & '$tempCopy' -Elevated
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
    Remove-Item $tempCopy -ErrorAction SilentlyContinue
    exit 0
}

# ============================================================
# BANNER
# ============================================================
Clear-Host
Write-Host ""
Write-Host "  ==================================================" -ForegroundColor DarkCyan
Write-Host "   Swivel 2 - Uninstaller                          " -ForegroundColor Cyan
Write-Host "  ==================================================" -ForegroundColor DarkCyan
Write-Host ""

# ============================================================
# 1. CONFIRM
# ============================================================
Write-Step "About to remove..."

Write-Host "    $InstallDir" -ForegroundColor Gray
Write-Host "    Start Menu entry '$ShortcutName'" -ForegroundColor Gray
Write-Host "    Add/Remove Programs registration" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $InstallDir)) {
    Write-Warn "$InstallDir does not exist -- Swivel may already be uninstalled."
    Write-Host ""
}

$confirm = Read-Host "  Continue? (y/N)"
if ($confirm -ne "y") {
    Write-Warn "Uninstall cancelled."
    Safe-Exit 0
}

# ============================================================
# 2. CLOSE SWIVEL IF RUNNING
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
        Write-Warn "Uninstall cancelled."
        Safe-Exit 0
    }
} else {
    Write-Ok "Swivel is not running."
}

# ============================================================
# 3. REMOVE THE INSTALL FOLDER
# ============================================================
Write-Step "Removing program files..."

if (Test-Path $InstallDir) {
    try {
        Remove-Item $InstallDir -Recurse -Force
        Write-Ok "Removed $InstallDir"
    } catch {
        Write-Err "Could not remove $InstallDir : $_"
        Write-Warn "Something may still have a file open. Close Animate and retry."
        Safe-Exit 1
    }
} else {
    Write-Warn "Nothing to remove at $InstallDir"
}

# ============================================================
# 4. REMOVE THE START MENU ENTRY
# ============================================================
Write-Step "Removing Start Menu entry..."

$shortcut = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\$ShortcutName"

if (Test-Path $shortcut) {
    try {
        Remove-Item $shortcut -Force
        Write-Ok "Removed $ShortcutName"
    } catch {
        Write-Warn "Could not remove the shortcut: $_"
    }
} else {
    Write-Warn "No Start Menu entry found."
}

# ============================================================
# 5. REMOVE THE ADD/REMOVE PROGRAMS ENTRY
# ============================================================
Write-Step "Removing Add/Remove Programs entry..."

if (Test-Path $RegistryKey) {
    try {
        Remove-Item $RegistryKey -Recurse -Force
        Write-Ok "Registration removed."
    } catch {
        Write-Warn "Could not remove the registry entry: $_"
    }
} else {
    Write-Warn "No registration found."
}

# ============================================================
# 6. USER DATA (optional)
# ============================================================
Write-Step "Checking for user data..."

if (Test-Path $AppDataDir) {
    Write-Host ""
    Write-Host "  Swivel also stores logs and temporary files here:" -ForegroundColor White
    Write-Host "    $AppDataDir" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  This includes SwivelLog.txt and FfmpegLog.txt, which are worth" -ForegroundColor DarkGray
    Write-Host "  keeping if you are reinstalling to troubleshoot something." -ForegroundColor DarkGray
    Write-Host ""

    $removeData = Read-Host "  Remove it too? (y/N)"

    if ($removeData -eq "y") {
        try {
            Remove-Item $AppDataDir -Recurse -Force
            Write-Ok "User data removed."
        } catch {
            Write-Warn "Could not remove user data: $_"
        }
    } else {
        Write-Ok "User data kept."
    }
} else {
    Write-Ok "No user data found."
}

# ============================================================
# DONE
# ============================================================
Write-Step "Verifying..."

$leftovers = @()
if (Test-Path $InstallDir)  { $leftovers += $InstallDir }
if (Test-Path $shortcut)    { $leftovers += $shortcut }
if (Test-Path $RegistryKey) { $leftovers += $RegistryKey }

Write-Host ""
Write-Host "  ==================================================" -ForegroundColor DarkCyan

if ($leftovers.Count -eq 0) {
    Write-Host "   UNINSTALL SUCCESSFUL!                           " -ForegroundColor Green
    Write-Host "  ==================================================" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  $AppName has been removed." -ForegroundColor White
    Write-Host ""
    Write-Host "  The Animate panel will report Swivel as not running" -ForegroundColor DarkGray
    Write-Host "  until it is installed again." -ForegroundColor DarkGray
    Write-Host ""
} else {
    Write-Host "   UNINSTALL COMPLETED WITH LEFTOVERS.             " -ForegroundColor Yellow
    Write-Host "  ==================================================" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  These could not be removed:" -ForegroundColor Yellow
    foreach ($item in $leftovers) { Write-Host "    $item" -ForegroundColor Gray }
    Write-Host ""
}

Safe-Exit 0
