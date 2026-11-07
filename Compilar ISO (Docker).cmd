@echo off
rem ===========================================================================
rem  AquaOS · PASO 1 de 2: compilar la ISO (solo hace falta una vez)
rem
rem  Necesita Docker Desktop. Si no lo tienes, el script te dice exactamente
rem  que instalar. Tarda 20-60 minutos y deja la ISO en out\.
rem ===========================================================================
setlocal
chcp 65001 >nul
cd /d "%~dp0"

echo.
echo   AquaOS - compilando la ISO
echo   ------------------------------------------------
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-in-docker.ps1" %*

echo.
pause
endlocal
