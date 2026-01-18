@echo off
setlocal

echo ========================================
echo AI Text Tools - Full Build
echo ========================================
echo.

:: Run compilation
call "%~dp0compile.bat"
if errorlevel 1 (
    echo Build failed at compilation step
    exit /b 1
)

echo.

:: Build installer
call "%~dp0build-installer.bat"
if errorlevel 1 (
    echo Build failed at installer step
    exit /b 1
)

echo.
echo ========================================
echo Full build completed successfully!
echo ========================================
echo.
echo Outputs:
echo   - build\AITextTools.exe
echo   - build\installer\AITextTools-Setup.exe
echo.
echo Next steps:
echo   1. Test the installer on a clean system
echo   2. Submit to VirusTotal for AV check
echo   3. Create GitHub release
echo.

exit /b 0
