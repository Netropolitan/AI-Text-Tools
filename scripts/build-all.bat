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

:: Copy bin/ directory (whisper-cli, models) if present
if exist "%~dp0..\bin" (
    echo.
    echo Copying bin/ directory to build output...
    if not exist "%~dp0..\build\bin" mkdir "%~dp0..\build\bin"
    xcopy /Y /Q "%~dp0..\bin\*.*" "%~dp0..\build\bin\" >nul 2>&1
    echo bin/ files copied to build output
)

echo.
echo ========================================
echo Full build completed successfully!
echo ========================================
echo.
echo Outputs:
echo   - build\AITextTools.exe
echo   - build\bin\  (whisper-cli + models, if downloaded)
echo   - build\installer\AITextTools-Setup.exe
echo.
echo Next steps:
echo   1. Test the installer on a clean system
echo   2. Submit to VirusTotal for AV check
echo   3. Create GitHub release
echo.

exit /b 0
