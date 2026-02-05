@echo off
echo ===============================================
echo  BuzzCart - Test File Upload to MinIO
echo ===============================================
echo.

REM Create a test image file if it doesn't exist
if not exist "test-image.txt" (
    echo Creating test file...
    echo This is a test file for MinIO upload > test-image.txt
)

echo [1/2] Uploading test file...
echo.

curl -X POST http://localhost:8000/api/upload/image ^
  -F "image=@test-image.txt" ^
  -F "folder=tests"

echo.
echo.

if errorlevel 1 (
    echo ❌ Upload failed!
    echo.
    echo Possible reasons:
    echo   - Backend is not running
    echo   - MinIO is not running
    echo   - Network issue
    echo.
    echo Steps to fix:
    echo   1. Run start-services.bat
    echo   2. Wait 30 seconds for all services to start
    echo   3. Run this script again
    echo.
) else (
    echo.
    echo [2/2] Verifying upload in MinIO Console...
    echo.
    echo ✅ Upload successful!
    echo.
    echo To view the file:
    echo   1. Go to http://localhost:9001
    echo   2. Login with: minioadmin / minioadmin123
    echo   3. Click "Buckets" → "buzzcart-media" → "tests/"
    echo.
    start http://localhost:9001
)

echo.
pause
