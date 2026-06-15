@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "WIDGET_SCRIPT=%SCRIPT_DIR%superpowers-widget.ps1"

if not exist "%WIDGET_SCRIPT%" (
  echo Superpowers widget script was not found.
  echo Expected: %WIDGET_SCRIPT%
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%WIDGET_SCRIPT%"

if errorlevel 1 (
  echo.
  echo Superpowers widget could not start.
  echo If Windows blocked PowerShell, right-click the file and choose Run as administrator once, or ask Codex to check the PowerShell policy.
  pause
)
