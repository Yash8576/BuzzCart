#!/bin/bash
# Start all Docker services for Like2Share application
# This script starts Cloud SQL Proxy, Redis, Backend, Frontend, and Chatbot services

echo "========================================"
echo "Starting Like2Share Services"
echo "========================================"
echo ""

# Navigate to project root
cd "$(dirname "$0")/.." || exit

echo "Stopping any existing containers..."
docker compose -f docker/docker-compose.yml down
echo ""

echo "Starting all services..."
docker compose -f docker/docker-compose.yml up -d cloudsql-proxy redis backend frontend chatbot
echo ""

echo "Waiting for services to be healthy..."
sleep 5
echo ""

echo "Checking service status..."
docker compose -f docker/docker-compose.yml ps
echo ""

echo "========================================"
echo "Service URLs:"
echo "========================================"
echo "Cloud SQL Proxy:  localhost:5434"
echo "  Target DB:      buzzcart-daeb6-database"
echo ""
echo "Redis:       localhost:6379"
echo "Backend:     localhost:8080"
echo "Frontend:    localhost:80"
echo "Chatbot:     localhost:8001"
echo "========================================"
echo ""
echo "All services started successfully!"
echo "Run 'docker compose -f docker/docker-compose.yml logs -f' to view logs"
echo ""
