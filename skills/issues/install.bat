@echo off
setlocal
set SKILL_DIR=%~dp0
set BIN_DIR=%USERPROFILE%\.local\bin
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"

rem issues is a bash CLI — on Windows it runs via git-bash / WSL if present
where bash >nul 2>nul
if errorlevel 1 (
    echo issues is a bash skill — install bash ^(git-bash or WSL^) and re-run,
    echo or use the WSL path: bash skills/issues/install.sh
    exit /b 1
)

if exist "%BIN_DIR%\issues" del "%BIN_DIR%\issues"

(
    echo @echo off
    echo bash "%SKILL_DIR%issues" %%*
) > "%BIN_DIR%\issues.bat"

echo Created %BIN_DIR%\issues.bat -^> bash %SKILL_DIR%issues
echo Usage: issues board
endlocal
