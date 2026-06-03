@echo off
setlocal enabledelayedexpansion

:: ── Resolve skill directory ──
set "SKILL_DIR=%~dp0"
:: Remove trailing backslash
if "%SKILL_DIR:~-1%"=="\" set "SKILL_DIR=%SKILL_DIR:~0,-1%"
cd /d "%SKILL_DIR%"

echo Installing web-search skill...
echo   Skill dir: %SKILL_DIR%

:: ── 1. Ensure uv is available ──
where uv >nul 2>&1
if errorlevel 1 (
    echo   uv not found. Installing...
    powershell -ExecutionPolicy ByPass -NoProfile -Command "irm https://astral.sh/uv/install.ps1 | iex"
    :: Add to PATH for this session
    set "PATH=%USERPROFILE%\.local\bin;%USERPROFILE%\.cargo\bin;%PATH%"
    where uv >nul 2>&1
    if errorlevel 1 (
        echo X uv not found in PATH after install. Restart your terminal and retry.
        exit /b 1
    )
)

:: ── 2. Install dependencies ──
echo   Syncing dependencies...
uv sync

:: ── 3. Create global launcher ──
:: Write a .bat launcher that embeds SKILL_DIR
set "BIN_DIR=%USERPROFILE%\.local\bin"
set "LAUNCHER=%BIN_DIR%\web-search.bat"
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"

> "%LAUNCHER%" (
    echo @echo off
    echo cd /d "%SKILL_DIR%" ^&^& uv run scripts\search.py %%*
)
echo   Created launcher: %LAUNCHER% -^> %SKILL_DIR%\scripts\search.py

:: ── 4. Verify installation ──
echo   Verifying...
"%LAUNCHER%" "test" -v >nul 2>&1
if not errorlevel 1 (
    echo   + web-search works
) else (
    echo   ! web-search installed but verification failed. Try running manually:
    echo     %LAUNCHER% "test query" -v
)

:: ── 5. Write update timestamp ──
powershell -NoProfile -Command "[int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" > "%SKILL_DIR%\.last-update"

echo.
echo + Installation complete!
echo.
echo Usage:
echo   web-search "your query"              # Search the web
echo   web-search "cats" --categories images # Image search
echo   web-search "news" --categories news    # News search
echo   web-search "query" -v                 # Verbose (show backend)
echo.
echo Works out-of-the-box with public SearXNG instances.
