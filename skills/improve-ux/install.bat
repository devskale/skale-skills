@echo off
setlocal
set SKILL_DIR=%~dp0

set BIN_DIR=%USERPROFILE%\.local\bin
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"

echo Installing improve-ux skill...
if exist "%BIN_DIR%\improve-ux.bat" del "%BIN_DIR%\improve-ux.bat"
echo @echo off > "%BIN_DIR%\improve-ux.bat"
echo call bash "%SKILL_DIR%improve-ux" %%* >> "%BIN_DIR%\improve-ux.bat"

echo.
echo ✓ Installation complete!
echo.
echo Usage:
echo   improve-ux discover             discover new UX reference sites
echo   improve-ux add ^<url^> "^<focus^>"  append a site to SITES.md
echo.
echo Requires: web-search (sibling skill), python3, curl. Optional: peep (--x).
endlocal
