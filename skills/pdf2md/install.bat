@echo off
setlocal enabledelayedexpansion

:: ── Resolve skill directory ──
set "SKILL_DIR=%~dp0"
:: Remove trailing backslash
if "%SKILL_DIR:~-1%"=="\" set "SKILL_DIR=%SKILL_DIR:~0,-1%"
cd /d "%SKILL_DIR%"

echo Installing pdf2md skill...
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
set "LAUNCHER=%BIN_DIR%\pdf2md.bat"
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"

> "%LAUNCHER%" (
    echo @echo off
    echo cd /d "%SKILL_DIR%" ^&^& uv run scripts\pdf2md.py %%*
)
echo   Created launcher: %LAUNCHER% -^> %SKILL_DIR%\scripts\pdf2md.py

:: ── 3b. Create bash launcher (for git-bash users) ──
set "BASH_LAUNCHER=%BIN_DIR%\pdf2md"
copy /y "%SKILL_DIR%\pdf2md" "%BASH_LAUNCHER%" >nul
chmod +x "%BASH_LAUNCHER%" 2>nul
if errorlevel 1 (
    echo   ! Could not set execute bit. For bash: chmod +x "%BASH_LAUNCHER%"
)
if exist "%BASH_LAUNCHER%" (
    echo   Created bash launcher: %BASH_LAUNCHER%
) else (
    echo   ! Could not create bash launcher; pdf2md will only be available in CMD.
)

:: ── 4. Verify installation ──
echo   Verifying...
call "%LAUNCHER%" --selfcheck >nul 2>&1
if not errorlevel 1 (
    echo   + pdf2md works
) else (
    echo   ! pdf2md installed but verification failed. Try running manually:
    echo     %LAUNCHER% --selfcheck
)

:: ── 5. Write update timestamp ──
powershell -NoProfile -Command "[int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" > "%SKILL_DIR%\.last-update"

echo.
echo + Installation complete!
echo.
echo Usage:
echo   pdf2md document.pdf                    # auto: pdfplumber, llamaparse fallback
echo   pdf2md scan.pdf --method llamaparse    # force cloud OCR
echo   pdf2md doc.pdf --out doc.md            # write file instead of stdout
echo.
echo Update:
echo   pdf2md --update
echo   pdf2md --selfcheck
echo.
echo Credentials (bearer token for the pdf API - same as fetch-url's api tool):
echo   credgoo FETCH_URL_BEARER
