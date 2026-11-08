@echo off
title Install BisaClip
rem Pasang atau update BisaClip di Windows (XAMPP for Windows). Update: git pull dulu, lalu jalankan file ini lagi.
rem Tanpa GPU NVIDIA / lewati CUDA: jalankan dari Command Prompt dengan  "Install BisaClip.bat" -NoCuda
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install\setup-windows.ps1" %*
echo.
pause
