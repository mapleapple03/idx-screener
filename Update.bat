@echo off
REM Klik dua kali file ini untuk memperbarui screener.
title Screener Saham IDX
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-Screener.ps1"
if errorlevel 1 (
  echo.
  echo Terjadi kesalahan. Tekan tombol apa saja untuk menutup.
  pause >nul
)
