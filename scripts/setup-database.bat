@echo off
REM Database Setup Script for Like2Share (Windows)
REM This script sets up the PostgreSQL database using Docker Compose

echo =========================================
echo Like2Share Database Setup
echo =========================================
echo.

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo Error: Docker is not running. Please start Docker Desktop and try again.
    pause
    exit /b 1
)

REM Check if .env file exists
if not exist .env (
    echo .env file not found. Creating from .env.example...
    copy .env.example .env
    echo Created .env file. Please update it with your configuration.
    echo.
)

REM Navigate to docker directory
cd /d "%~dp0\..\docker"

REM Stop any existing containers
echo Stopping existing containers...
docker-compose down

REM Start PostgreSQL database
echo Starting PostgreSQL database...
docker-compose up -d postgres

REM Wait for PostgreSQL to be ready
echo Waiting for PostgreSQL to be ready...
timeout /t 5 /nobreak >nul

REM Check if database is healthy
:check_db
docker exec like2share_db pg_isready -U like2share_user -d like2share_db >nul 2>&1
if errorlevel 1 (
    echo    Database not ready yet, waiting...
    timeout /t 2 /nobreak >nul
    goto check_db
)

echo Database is ready!
echo.

REM Show database connection info
echo =========================================
echo Database Connection Information
echo =========================================
echo Host: localhost
echo Port: 5432
echo Database: like2share_db
echo Username: like2share_user
echo Password: (check your .env file)
echo.
echo Connection String:
echo postgres://like2share_user:^<password^>@localhost:5432/like2share_db
echo.

REM Verify tables were created
echo Verifying database schema...
docker exec like2share_db psql -U like2share_user -d like2share_db -c "\dt"

echo.
echo =========================================
echo Database setup completed successfully!
echo =========================================
echo.
echo Next steps:
echo 1. Start the backend: docker-compose up -d backend
echo 2. Start the frontend: docker-compose up -d frontend
echo 3. Access the application at http://localhost
echo.

pause
