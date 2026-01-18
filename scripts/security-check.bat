@echo off
setlocal enabledelayedexpansion

echo ========================================
echo AI Text Tools - Security Check
echo ========================================
echo.

set "PROJECT_ROOT=%~dp0.."
set "ISSUES=0"

echo Checking for potential API keys in source files...

:: Check for common API key patterns
for %%P in (
    "sk-[a-zA-Z0-9]"
    "sk-ant-"
    "AIza"
    "api.key"
    "apikey"
    "api_key"
    "secret"
) do (
    findstr /s /i /r "%%~P" "%PROJECT_ROOT%\src\*.ahk" "%PROJECT_ROOT%\*.ini" "%PROJECT_ROOT%\*.md" 2>nul
    if not errorlevel 1 (
        echo WARNING: Potential sensitive data found matching pattern %%~P
        set /a ISSUES+=1
    )
)

echo.

:: Check for hardcoded URLs that might contain keys
findstr /s /i "api.openai.com.*sk-" "%PROJECT_ROOT%\src\*.ahk" 2>nul
if not errorlevel 1 (
    echo WARNING: Possible API key in URL
    set /a ISSUES+=1
)

echo.

:: Verify settings.ini is not tracked
git -C "%PROJECT_ROOT%" ls-files settings.ini 2>nul | findstr . >nul
if not errorlevel 1 (
    echo WARNING: settings.ini is tracked by git!
    set /a ISSUES+=1
)

echo.

if %ISSUES% equ 0 (
    echo ========================================
    echo Security check passed - no issues found
    echo ========================================
) else (
    echo ========================================
    echo WARNING: %ISSUES% potential issue(s) found
    echo Review above warnings before committing
    echo ========================================
)

exit /b %ISSUES%
