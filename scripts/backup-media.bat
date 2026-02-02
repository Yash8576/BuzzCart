@echo off
REM Media Backup Script for Windows
REM Creates compressed backup of media files

setlocal enabledelayedexpansion

set STORAGE_DIR=%~dp0..\storage\media
set BACKUP_DIR=%~dp0..\backups\media
set TIMESTAMP=%date:~-4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set BACKUP_NAME=media_backup_%TIMESTAMP%.zip

echo =========================================
echo Like2Share Media Backup
echo =========================================
echo.

REM Check if storage directory exists
if not exist "%STORAGE_DIR%" (
    echo Error: Storage directory not found: %STORAGE_DIR%
    exit /b 1
)

REM Create backup directory if it doesn't exist
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

REM Calculate storage size
for /f "tokens=3" %%a in ('dir /s "%STORAGE_DIR%" ^| find "File(s)"') do set STORAGE_SIZE=%%a
echo Storage files to backup
echo.

REM Create backup using PowerShell
echo Creating backup...
echo    Backup file: %BACKUP_NAME%
echo.

powershell -Command "Compress-Archive -Path '%STORAGE_DIR%\*' -DestinationPath '%BACKUP_DIR%\%BACKUP_NAME%' -CompressionLevel Optimal -Force -Exclude 'temp','*.tmp'"

REM Verify backup
if exist "%BACKUP_DIR%\%BACKUP_NAME%" (
    echo Backup created successfully!
    for %%A in ("%BACKUP_DIR%\%BACKUP_NAME%") do echo    Size: %%~zA bytes
    echo    Location: %BACKUP_DIR%\%BACKUP_NAME%
) else (
    echo Error: Backup failed!
    exit /b 1
)

echo.

REM Clean old backups (keep last 7)
echo Cleaning old backups ^(keeping last 7^)...
for /f "skip=7 delims=" %%F in ('dir /b /o-d "%BACKUP_DIR%\media_backup_*.zip" 2^>nul') do (
    del "%BACKUP_DIR%\%%F"
)

REM List recent backups
echo.
echo Recent backups:
dir /o-d /b "%BACKUP_DIR%\media_backup_*.zip" 2>nul | findstr /n "^" | findstr /b "[1-7]:" | for /f "tokens=2 delims=:" %%a in ('more') do echo    %%a

echo.
echo =========================================
echo Backup completed!
echo =========================================
echo.
echo To restore, extract: %BACKUP_DIR%\%BACKUP_NAME%
echo.

pause
