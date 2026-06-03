@echo off
setlocal enabledelayedexpansion

:: ── Resolve skill directory ──
set "SKILL_DIR=%~dp0"
if "%SKILL_DIR:~-1%"=="\" set "SKILL_DIR=%SKILL_DIR:~0,-1%"
cd /d "%SKILL_DIR%"

echo Installing youtube skill...

:: Ensure ~/.local/bin exists
set "BIN_DIR=%USERPROFILE%\.local\bin"
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"

:: Create launcher bat
set "LAUNCHER=%BIN_DIR%\youtube.bat"
> "%LAUNCHER%" (
    echo @echo off
    echo cd /d "%SKILL_DIR%" ^&^& python scripts\search.py %%*
)

echo Done. Use: youtube "search query"
