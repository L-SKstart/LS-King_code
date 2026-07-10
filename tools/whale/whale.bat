@echo off
chcp 65001 >nul 2>&1
set "WHALE_BIN=%~dp0node_modules\@usewhale\whale-win32-x64\vendor\whale.exe"
if not exist "%WHALE_BIN%" (
    echo [ERROR] Whale binary not found: %WHALE_BIN%
    echo Please re-run: cd /d %~dp0 ^&^& npm install
    pause
    exit /b 1
)
"%WHALE_BIN%" %*
