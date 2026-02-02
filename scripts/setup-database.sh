#!/bin/bash
# Database Setup Script for Like2Share
# This script sets up the PostgreSQL database using Docker Compose

set -e

echo "========================================="
echo "Like2Share Database Setup"
echo "========================================="
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo "⚠️  .env file not found. Creating from .env.example..."
    cp .env.example .env
    echo "✅ Created .env file. Please update it with your configuration."
    echo ""
fi

# Navigate to docker directory
cd "$(dirname "$0")/../docker"

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose down

# Start PostgreSQL database
echo "🚀 Starting PostgreSQL database..."
docker-compose up -d postgres

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 5

# Check if database is healthy
echo "🔍 Checking database health..."
until docker exec like2share_db pg_isready -U like2share_user -d like2share_db > /dev/null 2>&1; do
    echo "   Database not ready yet, waiting..."
    sleep 2
done

echo "✅ Database is ready!"
echo ""

# Show database connection info
echo "========================================="
echo "Database Connection Information"
echo "========================================="
echo "Host: localhost"
echo "Port: 5432"
echo "Database: like2share_db"
echo "Username: like2share_user"
echo "Password: (check your .env file)"
echo ""
echo "Connection String:"
echo "postgres://like2share_user:<password>@localhost:5432/like2share_db"
echo ""

# Verify tables were created
echo "🔍 Verifying database schema..."
docker exec like2share_db psql -U like2share_user -d like2share_db -c "\dt" | grep -E "users|posts|likes|shares|comments|followers" && echo "✅ All tables created successfully!" || echo "⚠️  Some tables might be missing"

echo ""
echo "========================================="
echo "✅ Database setup completed successfully!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Start the backend: docker-compose up -d backend"
echo "2. Start the frontend: docker-compose up -d frontend"
echo "3. Access the application at http://localhost"
echo ""
