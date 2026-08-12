@echo off
setlocal
set SKILL_DIR=%~dp0

set BIN_DIR=%USERPROFILE%\.local\bin
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"

echo Installing visualize skill...
if exist "%BIN_DIR%\visualize.bat" del "%BIN_DIR%\visualize.bat"
echo @echo off > "%BIN_DIR%\visualize.bat"
echo call "%SKILL_DIR%visualize" %%* >> "%BIN_DIR%\visualize.bat"

echo.
echo ✓ Installation complete!
echo.
echo Usage:
echo   visualize open ^<file.html^>      open in browser
echo   visualize share ^<file.html^>     upload to throway, print URL
echo   visualize validate ^<file.html^>  check self-contained
echo.
echo Requires: curl (for share).
endlocal
