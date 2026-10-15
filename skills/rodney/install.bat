@echo off
setlocal enabledelayedexpansion

:: rodney skill installer (Windows) — downloads the release binary from
:: GitHub Releases, falls back to build-from-source when Go is available.
set "SKILL_DIR=%~dp0"
if "%SKILL_DIR:~-1%"=="\" set "SKILL_DIR=%SKILL_DIR:~0,-1%"

echo Installing rodney skill...

set "REPO=devskale/rodney"
set "BIN_DIR=%USERPROFILE%\.local\bin"
set "LAUNCHER=%BIN_DIR%\rodney.exe"
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"

:: Minimum required version — single source of truth: MIN_VERSION (shares with
:: install.sh and tests/rodney/test.sh). Bump it when a release carries a fix
:: downstream must not run without.
set "MIN_VERSION="
if exist "%SKILL_DIR%\MIN_VERSION" (
    set /p MIN_VERSION=<"%SKILL_DIR%\MIN_VERSION"
)
if "%MIN_VERSION%"=="" (
    echo ERROR MIN_VERSION missing or empty next to install.bat
    exit /b 1
)

:: ── 1. Detect arch ──
set "ARCH=%PROCESSOR_ARCHITECTURE%"
if /i "%ARCH%"=="AMD64" set "ARCH=amd64"
if /i "%ARCH%"=="ARM64" set "ARCH=arm64"
echo   Platform: windows/%ARCH%
if /i not "%ARCH%"=="amd64" if /i not "%ARCH%"=="arm64" (
    echo ERROR unsupported arch: %ARCH%
    exit /b 1
)

:: ── 2. Current version (info only) ──
where rodney >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%v in ('rodney --version 2^>nul') do echo   Current: %%v at ^(where rodney^)  ^(required: ^>= %MIN_VERSION%^)
)

:: ── 3. Download the latest release binary ──
set "URL=https://github.com/%REPO%/releases/latest/download/rodney-windows-%ARCH%.zip"
set "TMPD=%TEMP%\rodney-install-%RANDOM%"
mkdir "%TMPD%"

echo   Downloading %URL% ...
powershell -NoProfile -ExecutionPolicy ByPass -Command ^
  "try { Invoke-WebRequest -Uri '%URL%' -OutFile '%TMPD%\rodney.zip' -UseBasicParsing } catch { exit 1 }"
if errorlevel 1 (
    echo   NOTE download failed — falling back to source build
    goto :source
)

powershell -NoProfile -Command "Expand-Archive -Path '%TMPD%\rodney.zip' -DestinationPath '%TMPD%' -Force"
if not exist "%TMPD%\rodney.exe" (
    echo   NOTE no rodney.exe in zip — falling back to source build
    goto :source
)
move /y "%TMPD%\rodney.exe" "%LAUNCHER%" >nul
goto :verify

:: ── 4. Fallback: build from source ──
:source
where go >nul 2>&1
if errorlevel 1 (
    echo ERROR no Go toolchain and no release binary — cannot install
    rmdir /s /q "%TMPD%" 2>nul
    exit /b 1
)
set "SRC=%USERPROFILE%\src\rodney"
if exist "%SRC%\.git" (
    git -C "%SRC%" pull --ff-only >nul 2>&1
) else (
    git clone -b skale "https://github.com/%REPO%.git" "%SRC%"
)
pushd "%SRC%"
go build -ldflags "-s -w" -o "%LAUNCHER%" .
popd

:: ── 5. Verify ──
:verify
echo   Verifying...
"%LAUNCHER%" --version
if errorlevel 1 (
    echo ERROR verification failed
    rmdir /s /q "%TMPD%" 2>nul
    exit /b 1
)
:: version gate — same MIN_VERSION source as install.sh / test.sh
powershell -NoProfile -ExecutionPolicy ByPass -Command ^
  "$v=(& '%LAUNCHER%' --version); if ($v -notmatch '^[0-9]+\.[0-9]+') { exit 2 }; if ([version]$v -lt [version]'%MIN_VERSION%') { Write-Host \"ERROR installed rodney $v is older than required %MIN_VERSION%\"; exit 1 }"
if errorlevel 1 (
    echo ERROR rodney is older than the required %MIN_VERSION% — release asset may be stale
    rmdir /s /q "%TMPD%" 2>nul
    exit /b 1
)
echo   OK rodney installed at %LAUNCHER%
rmdir /s /q "%TMPD%" 2>nul

echo   NOTE if %%USERPROFILE%%\.local\bin is not in PATH, add it to use 'rodney'

echo.
echo OK Installation complete!
echo.
echo Usage:
echo   rodney start                  # headless Chrome session
echo   rodney open ^<url^>             # navigate
echo   rodney --session ^<name^> start # parallel session
echo   rodney --help                 # everything else
