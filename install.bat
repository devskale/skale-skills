@echo off
setlocal enabledelayedexpansion
:: skale-skills - one-command Windows installer (idempotent)
:: Runs every skills\*\install.bat -> global commands in %USERPROFILE%\.local\bin

set "REPO_DIR=%~dp0"
if "%REPO_DIR:~-1%"=="\" set "REPO_DIR=%REPO_DIR:~0,-1%"
cd /d "%REPO_DIR%"

echo skale-skills installer
echo   repo: %REPO_DIR%
echo.

echo -- Skills (global commands in %USERPROFILE%\.local\bin) --
for /d %%d in (skills\*) do (
    if exist "%%d\install.bat" (
        echo * %%~nxd
        call "%%d\install.bat" >nul 2>&1
        if errorlevel 1 (
            echo   X FAILED - run "%%d\install.bat" for details
        )
    )
)
echo   (d2, peep, improve-ux are knowledge skills; figure needs node - nothing to install)
echo   (rodney: uv tool install per guides/rodney-setup.md)

echo.
echo -- pi --
where pi >nul 2>&1
if errorlevel 1 (
    echo * pi not found - to serve these skills from pi:
    echo     pi install git:github.com/devskale/skale-skills ^&^& pi config
) else (
    pi install git:github.com/devskale/skale-skills
    echo * package installed/updated   (activate skills: pi config^)
)

echo.
echo -- Credentials (API keys via credgoo^) --
where credgoo >nul 2>&1
if errorlevel 1 (
    echo * credgoo missing:
    echo     uv tool install "credgoo @ git+https://github.com/devskale/python-openutils.git#subdirectory=packages/credgoo"
) else (
    echo * credgoo present
)

echo.
echo + done
