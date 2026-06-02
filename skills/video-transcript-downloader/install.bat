@echo off
setlocal enabledelayedexpansion

:: ── Resolve skill directory ──
set "SKILL_DIR=%~dp0"
if "%SKILL_DIR:~-1%"=="\" set "SKILL_DIR=%SKILL_DIR:~0,-1%"
cd /d "%SKILL_DIR%"

echo Installing video-transcript-downloader...

:: Ensure bin dir exists
set "BIN_DIR=%USERPROFILE%\.local\bin"
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"

:: Check/Install uv
where uv >nul 2>&1
if errorlevel 1 (
    echo uv not found. Installing...
    powershell -ExecutionPolicy ByPass -NoProfile -Command "irm https://astral.sh/uv/install.ps1 | iex"
    set "PATH=%USERPROFILE%\.local\bin;%USERPROFILE%\.cargo\bin;%PATH%"
)

:: Create venv + install yt-dlp
if not exist "%SKILL_DIR%\.venv" (
    echo Creating virtual environment...
    uv venv
)
echo Installing yt-dlp...
uv pip install yt-dlp

:: Node dependencies — avoid running npm/pnpm inside parenthesized blocks
set "HAS_PM="
where pnpm >nul 2>&1 && set "HAS_PM=pnpm"
if not defined HAS_PM where npm >nul 2>&1 && set "HAS_PM=npm"
if defined HAS_PM goto :do_npm_install
echo Warning: No pnpm/npm found. Node deps may be missing.
goto :after_npm

:do_npm_install
echo Installing Node dependencies (%HAS_PM%)...
call %HAS_PM% install

:after_npm

:: Create launcher bat
set "LAUNCHER=%BIN_DIR%\vtd.bat"
> "%LAUNCHER%" (
    echo @echo off
    echo cd /d "%SKILL_DIR%" ^&^& node scripts\vtd.js %%*
)

powershell -NoProfile -Command "[int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" > "%SKILL_DIR%\.last-update"

echo Done. Use: vtd transcript --url URL
