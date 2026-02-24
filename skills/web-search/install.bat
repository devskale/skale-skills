@echo off
setlocal enabledelayedexpansion

REM Ensure we're in the skill directory
cd /d "%~dp0"

echo Installing dependencies for web-search skill...

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

REM Install dependencies from requirements.txt
echo Installing dependencies...
uv pip install --python .venv\Scripts\python.exe -r requirements.txt
if errorlevel 1 (
    echo Error: Failed to install dependencies.
    exit /b 1
)

REM Install credgoo from skale.dev if not already installed
echo Ensuring credgoo is available...
python -c "import credgoo" 2>nul
if errorlevel 1 (
    echo Installing credgoo from skale.dev...
    uv pip install --python .venv\Scripts\python.exe -r https://skale.dev/credgoo
)

echo.
echo Installation complete!
echo.
echo Usage:
echo   search.bat "your query"
echo   search.bat "react hooks" --site github.com
echo.
echo Configuration (optional):
echo   - DuckDuckGo: Set WEB_SEARCH_BEARER environment variable
echo   - SearXNG: Configure 'searx' in credgoo (URL@USERNAME@PASSWORD)
echo.

endlocal
