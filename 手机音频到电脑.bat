@echo off
chcp 65001 >nul 2>&1
setlocal
set "PS=pwsh"
where pwsh >nul 2>&1
if errorlevel 1 set "PS=powershell"

rem ============================================================
rem  NOTE: KEEP THIS FILE PURE ASCII.
rem  cmd.exe parses .bat files using the system ANSI code page, so
rem  non-ASCII bytes here get mis-decoded and executed as commands.
rem ============================================================

rem First run: automatically deploy scrcpy if it is missing.
if not exist "%~dp0scrcpy\scrcpy.exe" (
    "%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
    if not exist "%~dp0scrcpy\scrcpy.exe" exit /b 1
)

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0phone-audio.ps1"
