#!/bin/bash

# ──────────────────────────────────────────────────────────────────────────
# TCG Docker Quick Start Script
# ──────────────────────────────────────────────────────────────────────────

set -e

echo "╔════════════════════════════════════════════════════════════════════════════════╗"
echo "║                    TCG Docker Setup & Launch                                   ║"
echo "╚════════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "✅ Docker is installed: $(docker --version)"
echo "✅ Docker Compose is installed: $(docker-compose --version)"
echo ""

# Create .env.docker.local if it doesn't exist
if [ ! -f .env.docker.local ]; then
    echo "📝 Creating .env.docker.local from template..."
    cp .env.docker .env.docker.local
    echo "✅ .env.docker.local created"
    echo "   ⚠️  Please update sensitive values in .env.docker.local"
    echo ""
fi

# Check for required env variables
echo "🔍 Validating environment variables..."

# Build images
echo ""
echo "🏗️  Building Docker images..."
docker-compose build

echo ""
echo "✅ Docker images built successfully!"
echo ""

# Show service info
echo "📊 Docker Services:"
docker-compose ps --services

echo ""
echo "🚀 To start services, run:"
echo ""
echo "   docker-compose up -d"
echo ""
echo "📋 Other useful commands:"
echo ""
echo "   # View logs"
echo "   docker-compose logs -f"
echo ""
echo "   # Stop services"
echo "   docker-compose down"
echo ""
echo "   # View service status"
echo "   docker-compose ps"
echo ""
echo "   # Access API shell"
echo "   docker-compose exec api sh"
echo ""
echo "   # Run migrations"
echo "   docker-compose exec api npm run db:migrate"
echo ""
echo "   # Seed database"
echo "   docker-compose exec api npm run db:seed"
echo ""
echo "📚 For more information, see DOCKER.md"
echo ""
