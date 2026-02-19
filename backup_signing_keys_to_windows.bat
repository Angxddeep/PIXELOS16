@echo off
setlocal enabledelayedexpansion

REM ============================================
REM   Backup PixelOS Signing Keys to Windows
REM ============================================

set PROJECT=agile-outlook-481719-c1
set VM_NAME=pixelos
set VM_USER=angxddeep
set ZONE=us-central1-c
set REMOTE_KEYS_DIR=/home/%VM_USER%/android-keys
set REMOTE_ARCHIVE=/tmp/pixelos_signing_keys_backup.tar.gz
set BACKUP_DIR=%USERPROFILE%\Documents\PixelOS\SigningKeys

echo ============================================
echo   PixelOS Signing Key Backup
echo ============================================
echo VM: %VM_NAME%  Zone: %ZONE%
echo Remote keys: %REMOTE_KEYS_DIR%
echo Local backup: %BACKUP_DIR%
echo.

where gcloud >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: gcloud CLI not found. Install Google Cloud SDK first.
    pause
    exit /b 1
)

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set TS=%%i
if not defined TS set TS=backup

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
set FINAL_FILE=%BACKUP_DIR%\pixelos_signing_keys_%TS%.tar.gz

echo Creating archive on VM...
gcloud compute ssh %VM_USER%@%VM_NAME% --project=%PROJECT% --zone=%ZONE% --command="set -e; test -d %REMOTE_KEYS_DIR%; umask 077; tar -C /home/%VM_USER% -czf %REMOTE_ARCHIVE% android-keys; ls -lh %REMOTE_ARCHIVE%"
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to create key archive on VM.
    pause
    exit /b 1
)

echo Downloading archive to Windows Documents...
gcloud compute scp %VM_USER%@%VM_NAME%:%REMOTE_ARCHIVE% "%FINAL_FILE%" --project=%PROJECT% --zone=%ZONE%
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to download key archive.
    pause
    exit /b 1
)

echo Cleaning up remote temp archive...
gcloud compute ssh %VM_USER%@%VM_NAME% --project=%PROJECT% --zone=%ZONE% --command="rm -f %REMOTE_ARCHIVE%" >nul 2>nul

echo.
echo Backup complete:
echo   %FINAL_FILE%
echo.
echo IMPORTANT: Keep this file private and stored securely.
echo.
pause
