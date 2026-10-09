@echo off
setlocal
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\verify.ps1" %*
set "VERIFY_EXIT=%ERRORLEVEL%"
pause
exit /b %VERIFY_EXIT%
