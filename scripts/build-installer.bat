@echo off
setlocal

echo ========================================
echo AI Text Tools - Build Installer
echo ========================================

set "PROJECT_ROOT=%~dp0.."
set "NSIS_PATH=C:\Program Files (x86)\NSIS"

:: Check for NSIS
if not exist "%NSIS_PATH%\makensis.exe" (
    echo ERROR: NSIS not found at %NSIS_PATH%
    echo Please install NSIS from https://nsis.sourceforge.io/
    exit /b 1
)

:: Ensure build directory exists
if not exist "%PROJECT_ROOT%\build\installer" mkdir "%PROJECT_ROOT%\build\installer"

:: Check that EXE was compiled first
if not exist "%PROJECT_ROOT%\build\AITextTools.exe" (
    echo ERROR: AITextTools.exe not found. Run compile.bat first.
    exit /b 1
)

:: Build installer
echo Building installer...
"%NSIS_PATH%\makensis.exe" "%PROJECT_ROOT%\installer\AITextTools.nsi"

if errorlevel 1 (
    echo ERROR: Installer build failed
    exit /b 1
)

echo.
echo ========================================
echo Installer built successfully!
echo Output: %PROJECT_ROOT%\build\installer\AITextTools-Setup.exe
echo ========================================

exit /b 0
