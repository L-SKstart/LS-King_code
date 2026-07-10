@echo off
chcp 65001 >nul 2>&1
set "WHALE_BIN=%~dp0node_modules\@usewhale\whale-win32-x64\vendor\whale.exe"
"%WHALE_BIN%" -m deepseek-v4-pro --effort max %*
