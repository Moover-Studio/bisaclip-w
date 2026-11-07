@echo off
title Install BisaClip
rem Pasang atau update BisaClip di laptop Windows ini (WSL2 + Ubuntu). Update: git pull dulu, lalu jalankan file ini lagi.
rem Tanpa GPU NVIDIA / lewati CUDA: jalankan dari Command Prompt dengan  "Install BisaClip.bat" -NoCuda
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install\windows\install-windows.ps1" %*
echo.
pause
