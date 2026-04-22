@echo off
REM Rebuild and start all Docker services for Like2Share application

echo ========================================
echo Rebuilding Like2Share Services
echo ========================================
echo.

cd /d "%~dp0\.."

echo Stopping and removing existing containers...
docker compose -f docker/docker-compose.yml down
echo.

echo Building and starting all services...
docker compose -f docker/docker-compose.yml up -d --build cloudsql-proxy redis backend frontend chatbot
echo.

echo Waiting for services to be healthy...
timeout /t 10 /nobreak >nul
echo.

echo Checking service status...
docker compose -f docker/docker-compose.yml ps
echo.

echo Checking backend logs for errors...
docker compose -f docker/docker-compose.yml logs --tail=20 backend
echo.

echo ========================================
echo Service URLs:
echo ========================================
echo Cloud SQL Proxy:  localhost:5434
echo   Target DB:      buzzcart-daeb6-database
echo.
echo Redis:       localhost:6379
echo Backend:     localhost:8080
echo Frontend:    localhost:80
echo Chatbot:     localhost:8001
echo ========================================
echo.
echo Rebuild complete!
echo.
pause
