@echo off
setlocal enabledelayedexpansion

echo ========================================
echo AI Text Tools - Compilation Script
echo ========================================

:: Configuration
set "AHK_ROOT=C:\Program Files\AutoHotkey"
set "AHK_COMPILER=%AHK_ROOT%\Compiler\Ahk2Exe.exe"
set "AHK_BASE=%AHK_ROOT%\v2\AutoHotkey64.exe"
set "PROJECT_ROOT=%~dp0.."
set "SRC_DIR=%PROJECT_ROOT%\src"
set "BUILD_DIR=%PROJECT_ROOT%\build"
set "MAIN_SCRIPT=%SRC_DIR%\main.ahk"
set "ICON=%PROJECT_ROOT%\assets\icon.ico"

:: Check for AutoHotkey installation
if not exist "%AHK_COMPILER%" (
    echo ERROR: AutoHotkey compiler not found at %AHK_COMPILER%
    echo Please install AutoHotkey v2 or update paths
    exit /b 1
)
if not exist "%AHK_BASE%" (
    echo ERROR: AutoHotkey v2 base not found at %AHK_BASE%
    exit /b 1
)

:: Create build directory
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

:: Clean previous build
if exist "%BUILD_DIR%\AITextTools.exe" del "%BUILD_DIR%\AITextTools.exe"

echo Compiling %MAIN_SCRIPT%...

:: Compile with Ahk2Exe (with custom icon)
"%AHK_COMPILER%" /in "%MAIN_SCRIPT%" /out "%BUILD_DIR%\AITextTools.exe" /icon "%ICON%" /base "%AHK_BASE%"

if errorlevel 1 (
    echo ERROR: Compilation failed
    exit /b 1
)

:: Copy default settings
echo Copying default settings...
copy /Y "%PROJECT_ROOT%\settings.default.ini" "%BUILD_DIR%\settings.default.ini" >nul

echo.
echo ========================================
echo Compilation successful!
echo Output: %BUILD_DIR%\AITextTools.exe
echo ========================================

exit /b 0
