@echo off
REM ============================================================
REM Deep Code CLI 启动器
REM 专为 DeepSeek V4 优化的终端 AI 编码助手
REM 安装路径：D:\Reasonix_Workspace\tools\deepcode-cli
REM 使用方式：双击运行或在终端中执行本文件
REM ============================================================
cd /d "%~dp0"
"%~dp0node_modules\.bin\deepcode.cmd" %*
