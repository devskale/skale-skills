@echo off
setlocal enabledelayedexpansion

:: ── Resolve skill directory ──
set "SKILL_DIR=%~dp0"
if "%SKILL_DIR:~-1%"=="\" set "SKILL_DIR=%SKILL_DIR:~0,-1%"
cd /d "%SKILL_DIR%"

echo Installing fetch-url skill...

:: ── 1. Ensure uv is available ──
where uv >nul 2>&1
if errorlevel 1 (
    echo uv not found. Installing...
    powershell -ExecutionPolicy ByPass -NoProfile -Command "irm https://astral.sh/uv/install.ps1 | iex"
    set "PATH=%USERPROFILE%\.local\bin;%USERPROFILE%\.cargo\bin;%PATH%"
    where uv >nul 2>&1
    if errorlevel 1 (
        echo X uv not found in PATH after install. Restart your terminal and retry.
        exit /b 1
    )
)

:: ── 2. Install dependencies ──
echo Syncing dependencies...
uv sync

:: ── 3. Create global launcher ──
set "BIN_DIR=%USERPROFILE%\.local\bin"
set "LAUNCHER=%BIN_DIR%\fetch-url.bat"
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"

> "%LAUNCHER%" (
    echo @echo off
    echo cd /d "%SKILL_DIR%" ^&^& uv run scripts\fetch.py %%*
)
echo   Created launcher: %LAUNCHER% -^> %SKILL_DIR%\scripts\fetch.py

:: ── 4. Write update timestamp ──
powershell -NoProfile -Command "[int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" > "%SKILL_DIR%\.last-update"

echo.
echo + Installation complete!
echo.
echo Usage:
echo   fetch-url "https://example.com"
echo   fetch-url "https://reddit.com/r/python"
echo.
echo Update:
echo   fetch-url --update
echo   fetch-url --selfcheck
