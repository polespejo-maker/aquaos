@echo off
rem ===========================================================================
rem  AquaOS · PASO 2: abrirlo en una ventana (VirtualBox)
rem
rem  Tu Windows no se toca. Cierras la ventana y sigues en Windows.
rem  Reinicias el PC y arranca Windows normalmente.
rem ===========================================================================
setlocal
chcp 65001 >nul
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0player\aquaos-player.ps1" %*

if errorlevel 1 (
    echo.
    pause
)
endlocal
