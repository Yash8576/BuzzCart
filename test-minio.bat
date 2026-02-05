@echo off
echo ===============================================
echo  BuzzCart - MinIO Integration Test
echo ===============================================
echo.

echo [1/4] Testing MinIO Health...
curl -s http://localhost:9000/minio/health/live >nul 2>&1
if errorlevel 1 (
    echo ❌ MinIO is not responding
    echo    Make sure services are running: start-services.bat
    echo.
    pause
    exit /b 1
)
echo ✓ MinIO is healthy
echo.

echo [2/4] Testing MinIO Console...
curl -s http://localhost:9001 >nul 2>&1
if errorlevel 1 (
    echo ❌ MinIO Console is not responding
    pause
    exit /b 1
)
echo ✓ MinIO Console is accessible
echo.

echo [3/4] Testing Backend Health...
curl -s http://localhost:8000/health >nul 2>&1
if errorlevel 1 (
    echo ⚠️  Backend is not responding (this is OK if not started yet)
) else (
    echo ✓ Backend is healthy
)
echo.

echo [4/4] Opening MinIO Console in browser...
start http://localhost:9001
echo.

echo ===============================================
echo  ✅ MinIO Tests Complete!
echo ===============================================
echo.
echo MinIO Console opened in your browser.
echo.
echo Login credentials:
echo   Username: minioadmin
echo   Password: minioadmin123
echo.
echo After logging in:
echo   1. Click "Buckets" to view buckets
echo   2. Look for "buzzcart-media" bucket
echo      (it will be auto-created on first upload)
echo.
echo To test file upload:
echo   1. Make sure backend is running
echo   2. Use test-upload.bat script
echo   OR
echo   3. Use curl command from MINIO_SETUP_GUIDE.md
echo.
pause
