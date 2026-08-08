@echo off
:: ============================================================
:: Swivel 2 - Installer Launcher
:: Lives in bin\ rather than bin\Swivel\, because PackageApp.bat
:: deletes and recreates bin\Swivel every time it runs.
:: ============================================================

:: Run PowerShell and wait for it to finish.
:: -NoExit keeps the window open if it fails early.
powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -Command ^
    "try { & '%~dp0operator.ps1' } catch { Write-Host $_.Exception.Message -ForegroundColor Red; Read-Host 'Press Enter to exit' }"

:: Fallback pause -- in case PowerShell exits without Read-Host
pause
