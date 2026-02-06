@echo off
REM Start all Docker services for Like2Share application
REM This script starts PostgreSQL, Redis, MinIO, Backend, and Chatbot services

echo ========================================
echo Starting Like2Share Services
echo ========================================
echo.

cd /d "%~dp0\.."

echo Stopping any existing containers...
docker compose -f docker/docker-compose.yml down
echo.

echo Starting all services...
docker compose -f docker/docker-compose.yml up -d postgres redis minio backend
echo.

echo Waiting for services to be healthy...
timeout /t 5 /nobreak >nul
echo.

echo Checking service status...
docker compose -f docker/docker-compose.yml ps
echo.

echo ========================================
echo Service URLs:
echo ========================================
echo PostgreSQL:  localhost:5433
echo   Database:  like2share_db  
echo   Username:  like2share_user
echo   Password:  like2share_dev_password
echo.
echo Redis:       localhost:6379
echo MinIO:       localhost:9000 (console: localhost:9001)
echo Backend:     localhost:8080
echo ========================================
echo.
echo All services started successfully!
echo Run 'docker compose -f docker/docker-compose.yml logs -f' to view logs
echo.
pause
