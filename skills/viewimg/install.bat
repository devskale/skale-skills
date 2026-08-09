@echo off
REM install.bat — create the %USERPROFILE%\.local\bin\viewimg.bat launcher (Windows)
if not exist "%USERPROFILE%\.local\bin" mkdir "%USERPROFILE%\.local\bin"
set "SCRIPT=%~dp0viewimg"
(
  echo @echo off
  echo bash "%SCRIPT%" %%*
) > "%USERPROFILE%\.local\bin\viewimg.bat"
echo viewimg installed -^> %USERPROFILE%\.local\bin\viewimg.bat
echo Requires chafa in WSL/Git Bash for in-terminal rendering.
