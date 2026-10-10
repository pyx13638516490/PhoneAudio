@echo off
chcp 65001 >nul 2>&1
setlocal
set "PS=pwsh"
where pwsh >nul 2>&1
if errorlevel 1 set "PS=powershell"

rem 首次运行：如果还没部署 scrcpy，先做环境准备
if not exist "%~dp0scrcpy\scrcpy.exe" (
    "%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
    if not exist "%~dp0scrcpy\scrcpy.exe" exit /b 1
)

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0phone-audio.ps1"
