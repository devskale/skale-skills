@echo off
setlocal

REM Ensure we're in the skill directory
cd /d "%~dp0"

REM Activate virtual environment
if exist ".venv\Scripts\activate.bat" (
    call .venv\Scripts\activate.bat
) else (
    echo Error: Virtual environment not found. Please run install.bat first.
    exit /b 1
)

REM Set UTF-8 encoding for proper output on Windows
set PYTHONIOENCODING=utf-8

REM Run the search script
python scripts\search.py %*

endlocal
