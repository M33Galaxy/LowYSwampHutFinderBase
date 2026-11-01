@echo off
REM Build the standalone LowYSwampHutFinderBase CLI (no Java / DLL required).
REM Output: build\cli\LowYSwampHutFinderBase-cli.exe
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_cli.ps1"
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" (
    echo BUILD FAILED with exit code %EXIT_CODE%.
    pause
    exit /b %EXIT_CODE%
)
echo BUILD OK: %~dp0build\cli\LowYSwampHutFinderBase-cli.exe
pause
endlocal & exit /b 0
