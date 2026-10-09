@echo off
setlocal
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\login.ps1" %*
set "LOGIN_EXIT=%ERRORLEVEL%"
pause
exit /b %LOGIN_EXIT%
