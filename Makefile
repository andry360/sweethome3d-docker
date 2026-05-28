# Makefile for Sweet Home 3D Docker

.PHONY: help build build-sf start stop restart logs clean backup restore test init check preflight

# Default target
help:
	@echo "Sweet Home 3D Docker - Available commands:"
	@echo ""
	@echo "  make check      - Run pre-flight checks before deployment"
	@echo "  make preflight  - Alias for 'make check'"
	@echo "  make init       - Initialize environment (.env, directories)"
	@echo "  make build      - Build Docker image from local sources"
	@echo "  make build-sf   - Build Docker image from SourceForge"
	@echo "  make start      - Start containers"
	@echo "  make stop       - Stop containers"
	@echo "  make restart    - Restart containers"
	@echo "  make logs       - Show container logs"
	@echo "  make clean      - Stop and remove containers"
	@echo "  make backup     - Backup user projects"
	@echo "  make restore    - Restore user projects from backup"
	@echo "  make test       - Run quick test"
	@echo ""

# Pre-flight checks
check preflight:
	@bash preflight-check.sh

# Build image from local sources
build:
	@echo "Building Sweet Home 3D Docker image from local sources..."
	docker-compose build

# Build image from SourceForge
build-sf:
	@echo "Building Sweet Home 3D Docker image from SourceForge..."
	docker build -f Dockerfile.sourceforge -t sweethome3d-online:7.7 .

# Start containers
start:
	@echo "Starting Sweet Home 3D..."
	docker-compose up -d
	@echo ""
	@echo "Sweet Home 3D is starting..."
	@echo "Access at: http://localhost:8080"

# Stop containers
stop:
	@echo "Stopping Sweet Home 3D..."
	docker-compose down

# Restart containers
restart:
	@echo "Restarting Sweet Home 3D..."
	docker-compose restart

# Show logs
logs:
	docker-compose logs -f

# Clean up
clean:
	@echo "Cleaning up Sweet Home 3D containers and images..."
	docker-compose down -v
	@echo "Cleanup complete"

# Backup user projects
backup:
	@echo "Running backup script..."
	bash backup-homes.sh

# Restore user projects
restore:
	@echo "Running restore script..."
	bash restore-homes.sh

# Quick test
test:
	@echo "Running quick test..."
	@docker ps | grep sweethome3d-online && echo "✓ Container is running" || echo "✗ Container is not running"
	@curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:8080 || echo "✗ Cannot connect to service"
	@test -d homes && echo "✓ Storage directory exists" || echo "✗ Storage directory not found"

# Initialize environment
init:
	@echo "Initializing Sweet Home 3D setup..."
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "✓ Created .env file - please edit it"; \
	else \
		echo "✓ .env file already exists"; \
	fi
	@mkdir -p homes backups
	@chmod +x backup-homes.sh restore-homes.sh
	@echo "✓ Created directories"
	@echo "✓ Set executable permissions on scripts"
	@echo ""
	@echo "Setup complete! Next steps:"
	@echo "  1. Edit .env file with your configuration"
	@echo "  2. Run 'make build' to build the image"
	@echo "  3. Run 'make start' to start Sweet Home 3D"
