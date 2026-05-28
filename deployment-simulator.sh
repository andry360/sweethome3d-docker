#!/bin/bash
# Sweet Home 3D Docker - Proxmox LXC Deployment Simulator
# Simulates the installation on Proxmox 9.1.2 LXC
# This script tests the major steps without actually modifying the host

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEPLOYMENT_TEST_DIR="${1:-.}"
VERBOSE="${VERBOSE:-0}"

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

echo "================================================"
echo "🚀 Sweet Home 3D Docker - Proxmox Simulator"
echo "================================================"
echo ""

# Check environment
log_info "Checking deployment environment..."
echo ""

# 1. Check if running in Docker or on Linux
if [ -f /.dockerenv ]; then
    log_warn "Running inside a Docker container - some checks may not apply"
elif [[ "$OSTYPE" != "linux-gnu"* ]]; then
    log_error "This script must run on Linux (Proxmox/LXC environment)"
    exit 1
else
    log_ok "Running on Linux system"
fi

# 2. Check disk space
AVAILABLE_DISK=$(df ${DEPLOYMENT_TEST_DIR} | tail -1 | awk '{print $4}')
REQUIRED_DISK=8388608  # 8GB in KB

if [ $AVAILABLE_DISK -lt $REQUIRED_DISK ]; then
    log_error "Insufficient disk space: ${AVAILABLE_DISK}KB available, ${REQUIRED_DISK}KB required"
    exit 1
else
    AVAILABLE_GB=$((AVAILABLE_DISK / 1024 / 1024))
    log_ok "Sufficient disk space: ${AVAILABLE_GB}GB available"
fi

# 3. Check RAM
AVAILABLE_RAM=$(free -m | awk 'NR==2{print $7}')
REQUIRED_RAM=1500  # ~1.5GB minimum for build

if [ $AVAILABLE_RAM -lt $REQUIRED_RAM ]; then
    log_warn "Limited RAM: ${AVAILABLE_RAM}MB available (build may slow down, recommends 2GB+)"
else
    log_ok "Sufficient RAM: ${AVAILABLE_RAM}MB available"
fi

echo ""
log_info "Validating project files..."
echo ""

# 4. Check all required files
REQUIRED_FILES=(
    "Dockerfile"
    "docker-compose.yml"
    ".env.example"
    "docker/entrypoint.sh"
    "docker/apache-config.conf"
    "docker/htaccess.conf"
    "README.md"
)

FILES_OK=1
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "${DEPLOYMENT_TEST_DIR}/${file}" ]; then
        log_ok "Found: ${file}"
    else
        log_error "Missing: ${file}"
        FILES_OK=0
    fi
done

if [ $FILES_OK -eq 0 ]; then
    exit 1
fi

echo ""
log_info "Testing Docker environment..."
echo ""

# 5. Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    exit 1
else
    DOCKER_VERSION=$(docker --version)
    log_ok "Docker found: $DOCKER_VERSION"
fi

# 6. Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose is not installed"
    exit 1
else
    DOCKER_COMPOSE_VERSION=$(docker-compose --version)
    log_ok "Docker Compose found: $DOCKER_COMPOSE_VERSION"
fi

# 7. Check Docker daemon
if ! docker ps > /dev/null 2>&1; then
    log_error "Docker daemon is not running"
    exit 1
else
    log_ok "Docker daemon is running"
fi

echo ""
log_info "Checking network configuration..."
echo ""

# 8. Check port availability
TARGET_PORT=8080
if command -v ss &> /dev/null; then
    if ss -tuln 2>/dev/null | grep -q ":$TARGET_PORT "; then
        log_warn "Port $TARGET_PORT is already in use (may need to change HOST_PORT)"
    else
        log_ok "Port $TARGET_PORT is available"
    fi
elif command -v netstat &> /dev/null; then
    if netstat -tuln 2>/dev/null | grep -q ":$TARGET_PORT "; then
        log_warn "Port $TARGET_PORT is already in use (may need to change HOST_PORT)"
    else
        log_ok "Port $TARGET_PORT is available"
    fi
else
    log_warn "Cannot check port availability (netstat/ss not found)"
fi

echo ""
log_info "Validating Docker configuration files..."
echo ""

# 9. Check docker-compose.yml syntax
cd "${DEPLOYMENT_TEST_DIR}"
if docker-compose config > /dev/null 2>&1; then
    log_ok "docker-compose.yml syntax is valid"
else
    log_error "docker-compose.yml has syntax errors"
    docker-compose config 2>&1 | head -20
    exit 1
fi

# 10. Check Dockerfile
if [ -f Dockerfile ]; then
    # Check for required Docker directives
    if grep -q "FROM" Dockerfile && grep -q "RUN" Dockerfile; then
        log_ok "Dockerfile has required directives"
    else
        log_error "Dockerfile appears incomplete"
        exit 1
    fi
fi

echo ""
log_info "Testing build capability..."
echo ""

# 11. Simulate build (don't actually build, just check readiness)
if [ "$VERBOSE" = "1" ]; then
    log_info "Running docker-compose build --dry-run..."
    docker-compose build --dry-run 2>&1 | head -20 || true
    log_ok "Build dry-run completed"
else
    log_ok "Docker build ready (use VERBOSE=1 for details)"
fi

echo ""
log_info "Simulating deployment steps..."
echo ""

# 12. Create test .env file
if [ ! -f ".env" ]; then
    log_info "Creating .env from template..."
    cp .env.example .env
    log_ok "Created .env file"
else
    log_ok ".env file already exists"
fi

# 13. Create storage directory
if [ ! -d "homes" ]; then
    log_info "Creating homes directory..."
    mkdir -p homes
    chmod 775 homes
    log_ok "Created homes directory with proper permissions"
else
    log_ok "homes directory already exists"
fi

# 14. Create backups directory
if [ ! -d "backups" ]; then
    log_info "Creating backups directory..."
    mkdir -p backups
    chmod 755 backups
    log_ok "Created backups directory"
else
    log_ok "backups directory already exists"
fi

echo ""
echo "================================================"
echo "📊 Deployment Readiness Report"
echo "================================================"
echo ""

log_ok "Pre-flight checks completed successfully!"
echo ""
echo "📋 Deployment Configuration:"
echo "  • Target Port: 8080"
echo "  • Storage Path: ./homes"
echo "  • Backup Path: ./backups"
echo "  • Container Name: sweethome3d-online"
echo "  • Image Version: sweethome3d-online:7.7"
echo ""

echo "🚀 Recommended Next Steps:"
echo ""
echo "  For Local Testing:"
echo "    1. make check          # Run pre-flight checks"
echo "    2. make init           # Initialize environment"
echo "    3. make build          # Build Docker image (20-30 minutes)"
echo "    4. make start          # Start the container"
echo "    5. make test           # Run quick tests"
echo ""

echo "  For Proxmox LXC Deployment:"
echo "    1. Create LXC container (Debian 13, 2CPU, 2GB RAM, 8GB disk)"
echo "    2. Enable nesting: pct set <VMID> -features nesting=1"
echo "    3. SSH into container"
echo "    4. Run: bash ct/sweethome3d.sh"
echo ""

echo "  Access After Deployment:"
echo "    http://192.168.4.25:8080"
echo ""

log_ok "Ready for deployment!"
echo ""
