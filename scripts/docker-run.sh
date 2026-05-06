#!/bin/bash
set -e

echo "🚀 Starting MuchToDo with docker-compose..."
docker compose up --build -d

echo ""
echo "✅ Services started. Waiting for health checks..."
sleep 5

docker compose ps

echo ""
echo "📡 API available at: http://localhost:8080"
echo "📡 Ping endpoint:    http://localhost:8080/ping"
echo "📡 Health endpoint:  http://localhost:8080/health"
echo ""
echo "To view logs:  docker compose logs -f backend"
echo "To stop:       docker compose down"
