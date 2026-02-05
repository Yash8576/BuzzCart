@echo off
echo ===============================================
echo  BuzzCart - Starting All Services
echo ===============================================
echo.

echo [1/3] Checking Docker Desktop...
docker --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker Desktop is not running!
    echo.
    echo Please start Docker Desktop and try again.
    echo.
    pause
    exit /b 1
)
echo ✓ Docker Desktop is running
echo.

echo [2/3] Starting Docker services...
cd docker
docker-compose up -d
if errorlevel 1 (
    echo ❌ Failed to start Docker services
    pause
    exit /b 1
)
echo ✓ Docker services started
echo.

echo [3/3] Checking service status...
timeout /t 5 /nobreak >nul
docker-compose ps
echo.

echo ===============================================
echo  ✅ All Services Started!
echo ===============================================
echo.
echo Services available at:
echo   - Backend API:      http://localhost:8000
echo   - Frontend:         http://localhost:80
echo   - MinIO Console:    http://localhost:9001
echo   - MinIO API:        http://localhost:9000
echo   - PostgreSQL:       localhost:5432
echo   - Redis:            localhost:6379
echo   - Chatbot:          http://localhost:8001
echo.
echo MinIO Console Login:
echo   Username: minioadmin
echo   Password: minioadmin123
echo.
echo To stop all services, run: stop-services.bat
echo.
pause
