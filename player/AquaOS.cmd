@echo off
rem ===========================================================================
rem  AquaOS · doble clic para abrirlo en una ventana (VirtualBox)
rem  Tu Windows no se toca. Reinicia el PC y arranca Windows normalmente.
rem ===========================================================================
setlocal
chcp 65001 >nul
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0aquaos-player.ps1" %*

if errorlevel 1 (
    echo.
    pause
)
endlocal
