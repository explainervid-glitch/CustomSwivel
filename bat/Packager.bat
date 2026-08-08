@echo off
if not exist %CERT_FILE% goto certificate

:: AIR output
if not exist %AIR_PATH% md %AIR_PATH%
set OUTPUT=%AIR_PATH%\%AIR_NAME%%AIR_TARGET%.air

:: Package
echo.
echo Packaging %AIR_NAME%%AIR_TARGET%.air using certificate %CERT_FILE%...
:: -tsa none: the timestamp authority AIR 32 defaults to is long dead and the
:: signing fails with "Could not generate timestamp: Connection reset".
:: Timestamping only keeps a signature valid past certificate expiry, which is
:: meaningless for the self-signed cert from CreateCertificate.bat.
call adt -package -storetype pkcs12 -keystore bat/Swivel.p12 -storepass %CERT_PASS% -tsa none -target bundle bin/Swivel application.xml bin/Swivel.swf ffmpeg/win32 ffmpeg/licenses assets/icons README.md LICENSE.md
if errorlevel 1 goto failed
goto end

:certificate
echo.
echo Certificate not found: %CERT_FILE%
echo.
echo Troubleshooting:
echo - generate a default certificate using 'bat\CreateCertificate.bat'
echo.
if %PAUSE_ERRORS%==1 pause
exit

:failed
echo AIR setup creation FAILED.
echo.
echo Troubleshooting:
echo - did you build your project in FlashDevelop?
echo - verify AIR SDK target version in %APP_XML%
echo.
if %PAUSE_ERRORS%==1 pause
exit

:end
echo.