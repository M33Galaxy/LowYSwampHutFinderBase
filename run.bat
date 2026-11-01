@echo off
setlocal
cd /d "%~dp0"
if not exist "build\cli\LowYSwampHutFinderBase-cli.exe" (
    echo Build it first:
    echo   powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_cli.ps1"
    pause
    exit /b 1
)
"build\cli\LowYSwampHutFinderBase-cli.exe" %*
endlocal & exit /b %ERRORLEVEL%
