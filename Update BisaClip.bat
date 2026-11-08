@echo off
title Update BisaClip
rem Update BisaClip ke versi terbaru dari GitHub tanpa menyentuh data (preset, musik, project, hasil render).
rem Ikut pasang library tim terbaru dari Downloads:  "Update BisaClip.bat" -WithLibrary
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install\update-windows.ps1" %*
echo.
pause
