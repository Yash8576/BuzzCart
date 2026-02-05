@echo off
echo ===============================================
echo  BuzzCart - Stopping All Services
echo ===============================================
echo.

echo Stopping Docker services...
cd docker
docker-compose down
if errorlevel 1 (
    echo ❌ Failed to stop Docker services
    pause
    exit /b 1
)

echo.
echo ✅ All services stopped successfully!
echo.
echo To start services again, run: start-services.bat
echo.
pause
