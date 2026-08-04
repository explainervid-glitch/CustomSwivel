# ============================================================
# Send to Swivel - Installer Script (PowerShell)
# Installs the CEP panel that links Adobe Animate to Swivel.
# Run via install.bat, do not run this file directly.
# ============================================================

param(
    [switch]$Elevated
)

# ---- Names / layout (single place to change) ----
$PluginName   = "Send to Swivel"        # shown to the user
$SourceFolder = "swivel_bridge"         # folder next to this script
$InstallName  = "swivel_animate_bridge" # folder name under CEP\extensions
$SwivelPort   = 47800                   # must match AnimateBridge.DEFAULT_PORT

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

    $currentScriptDir = Split-Path -Parent $selfPath

    # A mapped network drive is NOT visible inside the elevated session, so
    # stage the whole folder locally BEFORE elevating.
    $localPreStage = "$env:TEMP\SwivelBridge_preelevate"

    try {
        if (Test-Path $localPreStage) { Remove-Item $localPreStage -Recurse -Force }
        New-Item -ItemType Directory -Path $localPreStage -Force | Out-Null
        Copy-Item -Path "$currentScriptDir\*" -Destination $localPreStage -Recurse -Force
    } catch {
        Write-Err "Failed to stage project locally before elevation: $_"
        Safe-Exit 1
    }

    $localSelfPath = Join-Path $localPreStage "operator.ps1"
    if (-not (Test-Path $localSelfPath)) {
        Write-Err "operator.ps1 not found after local staging."
        Safe-Exit 1
    }

    # Temp launcher with no spaces in its path, so -File works cleanly.
    $tempLauncher = "$env:TEMP\SwivelBridge_elevate_launcher.ps1"
    Set-Content -Path $tempLauncher -Encoding UTF8 -Value @"
try {
    & '$($localSelfPath -replace "'", "''")' -Elevated
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
    Remove-Item $localPreStage -Recurse -Force -ErrorAction SilentlyContinue
    exit 0
}

# ============================================================
# BANNER
# ============================================================
Clear-Host
Write-Host ""
Write-Host "  ==================================================" -ForegroundColor DarkCyan
Write-Host "   Send to Swivel - Installer for Adobe Animate    " -ForegroundColor Cyan
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

$destSystem = "C:\Program Files (x86)\Common Files\Adobe\CEP\extensions\$InstallName"
$destUser   = "$env:APPDATA\Adobe\CEP\extensions\$InstallName"
$destDir    = if (Test-Path "C:\Program Files (x86)\Common Files\Adobe\CEP\extensions") {
    $destSystem
} else {
    Write-Warn "System CEP path not found, using per-user path."
    $destUser
}

Write-Ok "Source      : $sourceDir"
Write-Ok "Destination : $destDir"

if (-not (Test-Path "$sourceDir\CSXS\manifest.xml")) {
    Write-Host ""
    Write-Err "Folder '$SourceFolder' or manifest.xml not found."
    Write-Err "Expected structure:"
    Write-Host ""
    Write-Host "    install.bat"           -ForegroundColor Gray
    Write-Host "    operator.ps1"          -ForegroundColor Gray
    Write-Host "    $SourceFolder\"        -ForegroundColor Gray
    Write-Host "      CSXS\manifest.xml"   -ForegroundColor Gray
    Write-Host "      index.html"          -ForegroundColor Gray
    Write-Host "      js\panel.js"         -ForegroundColor Gray
    Write-Host "      js\CSInterface.js"   -ForegroundColor Gray
    Write-Host "      jsx\host.jsx"        -ForegroundColor Gray
    Write-Host ""
    Safe-Exit 1
}

# ============================================================
# 2. CHECK FOR CSInterface.js (Adobe's file, not bundled)
# ============================================================
Write-Step "Checking for CSInterface.js..."

if (-not (Test-Path "$sourceDir\js\CSInterface.js")) {
    Write-Err "js\CSInterface.js is missing."
    Write-Host ""
    Write-Host "  This is Adobe's library and is not redistributed here." -ForegroundColor Yellow
    Write-Host "  Get it from:" -ForegroundColor Yellow
    Write-Host "    https://github.com/Adobe-CEP/CEP-Resources" -ForegroundColor Gray
    Write-Host "  and place it at:" -ForegroundColor Yellow
    Write-Host "    $sourceDir\js\CSInterface.js" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  If you already have another CEP panel installed, you can copy" -ForegroundColor DarkGray
    Write-Host "  its CSInterface.js -- any CEP 9+ copy works." -ForegroundColor DarkGray
    Write-Host ""
    Safe-Exit 1
}
Write-Ok "CSInterface.js found."

# ============================================================
# 3. CHECK ADOBE ANIMATE PROCESS
# ============================================================
Write-Step "Checking for running Adobe Animate process..."

$animateProcess = Get-Process -Name "Animate" -ErrorAction SilentlyContinue

if ($animateProcess) {
    Write-Warn "Adobe Animate is currently running."
    Write-Host ""
    Write-Host "  Choose an action:" -ForegroundColor White
    Write-Host "  [1] Close Animate automatically and continue" -ForegroundColor Gray
    Write-Host "  [2] Continue without closing (not recommended)" -ForegroundColor Gray
    Write-Host "  [3] Cancel" -ForegroundColor Gray
    Write-Host ""

    $choice = Read-Host "  Choice (1/2/3)"

    switch ($choice) {
        "1" {
            Stop-Process -Name "Animate" -Force
            Start-Sleep -Seconds 2
            Write-Ok "Animate closed."
        }
        "2" {
            Write-Warn "Continuing. Restart Animate after installation."
        }
        default {
            Write-Warn "Installation cancelled."
            Safe-Exit 0
        }
    }
} else {
    Write-Ok "Adobe Animate is not currently running."
}

# ============================================================
# 4. COPY EXTENSION FILES
# ============================================================
Write-Step "Copying extension files to CEP extensions folder..."

try {
    if (Test-Path $destDir) {
        Remove-Item $destDir -Recurse -Force
        Write-Ok "Previous installation removed."
    }
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    Copy-Item -Path "$sourceDir\*" -Destination $destDir -Recurse -Force
    Write-Ok "Files copied to: $destDir"
} catch {
    Write-Err "Failed to copy files: $_"
    Safe-Exit 1
}

# ============================================================
# 5. REGISTRY -- PlayerDebugMode (required for unsigned CEP)
# ============================================================
Write-Step "Setting registry PlayerDebugMode..."

$csxsVersions = @(9, 10, 11, 12, 13)
$regErrors    = 0

foreach ($ver in $csxsVersions) {
    $regPath = "HKCU:\Software\Adobe\CSXS.$ver"
    try {
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name "PlayerDebugMode" -Value "1" -Type String -Force
        Write-Ok "CSXS.$ver - PlayerDebugMode=1"
    } catch {
        Write-Warn "CSXS.$ver - Failed: $_"
        $regErrors++
    }
}

if ($regErrors -gt 0) {
    Write-Warn "$regErrors key(s) could not be set (not critical)."
}

# ============================================================
# 6. VERIFICATION
# ============================================================
Write-Step "Verifying installation..."

$checks = @(
    @{ Path = "$destDir\CSXS\manifest.xml"; Label = "manifest.xml"   },
    @{ Path = "$destDir\index.html";        Label = "index.html"     },
    @{ Path = "$destDir\js\panel.js";       Label = "panel.js"       },
    @{ Path = "$destDir\js\CSInterface.js"; Label = "CSInterface.js" },
    @{ Path = "$destDir\jsx\host.jsx";      Label = "host.jsx"       },
    @{ Path = "$destDir\css\style.css";     Label = "style.css"      }
)

$allOk = $true
foreach ($check in $checks) {
    if (Test-Path $check.Path) {
        Write-Ok $check.Label
    } else {
        Write-Err "$($check.Label) -- FILE NOT FOUND!"
        $allOk = $false
    }
}

# ============================================================
# 7. IS SWIVEL LISTENING?  (informational only)
# ============================================================
Write-Step "Checking whether Swivel is listening on port $SwivelPort..."

$listening = Get-NetTCPConnection -State Listen -LocalPort $SwivelPort -ErrorAction SilentlyContinue
if ($listening) {
    Write-Ok "Swivel is running and listening."
} else {
    Write-Warn "Nothing is listening on $SwivelPort -- that is fine if Swivel is closed."
    Write-Host "       Start Swivel before using the panel." -ForegroundColor DarkGray
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
    Write-Host "  Next steps:" -ForegroundColor White
    Write-Host "  1. Start Swivel (the panel connects to it)"          -ForegroundColor Gray
    Write-Host "  2. Open Adobe Animate"                               -ForegroundColor Gray
    Write-Host "  3. Panel : Window > Extensions > $PluginName"        -ForegroundColor Gray
    Write-Host "  4. The dot turns GREEN when Swivel is reachable"     -ForegroundColor Gray
    Write-Host "  5. Press Ctrl+Enter in Animate, then Send to Swivel" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "   INSTALLATION COMPLETED WITH WARNINGS.          " -ForegroundColor Yellow
    Write-Host "  ==================================================" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  Some files were not found at the destination." -ForegroundColor Yellow
}

Safe-Exit 0
