@echo off
REM Cleanup script for temporary files (Windows)
REM Removes files older than specified retention period

setlocal enabledelayedexpansion

set STORAGE_DIR=%~dp0..\storage\media
set RETENTION_HOURS=%1
if "%RETENTION_HOURS%"=="" set RETENTION_HOURS=24

echo =========================================
echo Like2Share Temporary Files Cleanup
echo =========================================
echo.
echo Retention period: %RETENTION_HOURS% hours
echo.

REM Check if storage directory exists
if not exist "%STORAGE_DIR%" (
    echo Error: Storage directory not found: %STORAGE_DIR%
    exit /b 1
)

cd /d "%STORAGE_DIR%"

REM Clean temp uploads
if exist "temp\uploads" (
    echo Cleaning temp uploads...
    forfiles /P "temp\uploads" /S /M * /D -%RETENTION_HOURS% /C "cmd /c del @path" 2>nul
)

REM Clean temp processing
if exist "temp\processing" (
    echo Cleaning temp processing...
    forfiles /P "temp\processing" /S /M * /D -%RETENTION_HOURS% /C "cmd /c del @path" 2>nul
)

REM Clean old thumbnails (older than 90 days)
if exist "thumbnails" (
    echo Cleaning old thumbnails...
    forfiles /P "thumbnails" /S /M * /D -90 /C "cmd /c del @path" 2>nul
)

REM Remove empty directories
echo Removing empty directories...
for /f "delims=" %%d in ('dir /ad /b /s "temp" ^| sort /r') do (
    rd "%%d" 2>nul
)

echo.
echo Cleanup completed!
echo.

REM Show current storage usage
echo Current temp storage usage:
dir /s "%STORAGE_DIR%\temp" | find "File(s)"

echo.
pause
