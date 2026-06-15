@echo off
setlocal
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo Node.js is required for the web widget.
  echo Install Node.js 20 or newer, then run this file again.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { $r = Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:43821/api/health' -TimeoutSec 2; if ($r.StatusCode -eq 200) { exit 0 } } catch { }; exit 1" >nul 2>nul
if not errorlevel 1 (
  echo Superpowers web widget is already running.
  echo Opening http://127.0.0.1:43821
  start "" "http://127.0.0.1:43821"
  pause
  exit /b 0
)

npm --prefix web start
pause
