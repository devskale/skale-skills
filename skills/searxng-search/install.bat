@echo off
setlocal enabledelayedexpansion

REM Ensure we're in the skill directory
cd /d "%~dp0"

echo Installing dependencies for searxng-search skill...

REM Check for python
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: python is not installed.
    exit /b 1
)

REM Check for uv
uv --version >nul 2>&1
if errorlevel 1 (
    echo uv is not installed. Installing uv...
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    if errorlevel 1 (
        echo Error: Failed to install uv.
        exit /b 1
    )
    REM Refresh PATH for current session
    set "PATH=%USERPROFILE%\.local\bin;%PATH%"
)

REM Create virtual environment if it doesn't exist
if not exist ".venv" (
    echo Creating virtual environment...
    uv venv
    if errorlevel 1 (
        echo Error: Failed to create virtual environment.
        exit /b 1
    )
)

REM Install dependencies
echo Installing credgoo...
uv pip install --python .venv\Scripts\python.exe -r https://skale.dev/credgoo
if errorlevel 1 (
    echo Error: Failed to install credgoo.
    exit /b 1
)

echo.
echo Installation complete!
echo Please ensure your credentials for 'searx' are stored in credgoo.
echo Format: URL@USERNAME@PASSWORD
echo Example: https://neusiedl.duckdns.org:8002@searxng@searxng23
echo.
echo To add credentials, run:
echo   credgoo.bat set searx "your_url@your_username@your_password"

endlocal
