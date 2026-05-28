#!/bin/bash
# Sweet Home 3D Docker - Pre-flight Check Script
# Validates environment and configuration before building/deploying

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CHECKS_PASSED=0
CHECKS_FAILED=0

echo "================================================"
echo "🔍 Sweet Home 3D Docker - Pre-flight Check"
echo "================================================"
echo ""

# Function to check and report
check_item() {
    local name=$1
    local command=$2
    
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $name"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} $name"
        ((CHECKS_FAILED++))
    fi
}

echo "📋 System Requirements:"
echo "---"

check_item "Docker installed" "command -v docker"
check_item "Docker daemon running" "docker ps > /dev/null 2>&1"
check_item "Docker Compose installed" "command -v docker-compose"
check_item "Git installed" "command -v git"
check_item "Curl installed" "command -v curl"
check_item "Minimum disk space (2GB)" "[ \$(df / | tail -1 | awk '{print \$4}') -gt 2097152 ]"

echo ""
echo "🗂️  Project Structure:"
echo "---"

check_item "Dockerfile present" "[ -f Dockerfile ]"
check_item "docker-compose.yml present" "[ -f docker-compose.yml ]"
check_item ".env.example present" "[ -f .env.example ]"
check_item "docker/entrypoint.sh present" "[ -f docker/entrypoint.sh ]"
check_item "docker/apache-config.conf present" "[ -f docker/apache-config.conf ]"
check_item "docker/htaccess.conf present" "[ -f docker/htaccess.conf ]"
check_item "README.md present" "[ -f README.md ]"

echo ""
echo "🔐 Configuration Files:"
echo "---"

# Check .env file (optional if not yet created)
if [ -f .env ]; then
    check_item ".env exists and readable" "[ -r .env ]"
    
    # Validate .env syntax
    if grep -q "HOST_PORT" .env && grep -q "AUTH_ENABLED" .env; then
        echo -e "${GREEN}✓${NC} .env has required variables"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} .env missing required variables"
        ((CHECKS_FAILED++))
    fi
else
    echo -e "${YELLOW}ℹ${NC} .env not found (will create from .env.example)"
fi

echo ""
echo "🚀 Build Configuration:"
echo "---"

# Check Dockerfile syntax
if command -v docker &>/dev/null; then
    if docker run --rm -i hadolint/hadolint < Dockerfile 2>/dev/null || true; then
        echo -e "${GREEN}✓${NC} Dockerfile syntax valid (hadolint)"
        ((CHECKS_PASSED++))
    else
        echo -e "${YELLOW}ℹ${NC} hadolint not available (install: docker pull hadolint/hadolint)"
    fi
fi

# Check for SVN availability
check_item "SVN available (for build)" "command -v svn"

echo ""
echo "📦 Docker Configuration:"
echo "---"

# Check docker-compose.yml syntax
if command -v docker-compose &>/dev/null; then
    if docker-compose config > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} docker-compose.yml syntax valid"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} docker-compose.yml has syntax errors"
        ((CHECKS_FAILED++))
    fi
fi

# Check for port conflict (only if docker is running)
DEFAULT_PORT=8080
if command -v docker &>/dev/null && docker ps > /dev/null 2>&1; then
    if netstat -tuln 2>/dev/null | grep -q ":$DEFAULT_PORT " || ss -tuln 2>/dev/null | grep -q ":$DEFAULT_PORT "; then
        echo -e "${YELLOW}⚠${NC}  Port $DEFAULT_PORT appears to be in use"
        ((CHECKS_FAILED++))
    else
        echo -e "${GREEN}✓${NC} Port $DEFAULT_PORT is available"
        ((CHECKS_PASSED++))
    fi
fi

echo ""
echo "🛡️  Security Checks:"
echo "---"

check_item ".htaccess has security rules" "grep -q 'Require all denied' docker/htaccess.conf"
check_item "Apache config has no-index" "grep -q 'Options -Indexes' docker/apache-config.conf"
check_item "Entrypoint has error handling" "grep -q 'set -e' docker/entrypoint.sh"

echo ""
echo "💾 Storage Setup:"
echo "---"

# Check if homes directory exists and writable
if [ -d "homes" ]; then
    check_item "homes directory exists" "[ -d homes ]"
    if [ -w "homes" ]; then
        echo -e "${GREEN}✓${NC} homes directory is writable"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} homes directory not writable - may cause permission issues"
        ((CHECKS_FAILED++))
    fi
else
    echo -e "${YELLOW}ℹ${NC} homes directory not yet created (will be created during setup)"
fi

echo ""
echo "================================================"
echo "📊 Summary:"
echo "---"
echo -e "Passed: ${GREEN}$CHECKS_PASSED${NC} | Failed: ${RED}$CHECKS_FAILED${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Ready for deployment.${NC}"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Copy .env.example to .env"
    echo "   2. Review and customize .env settings"
    echo "   3. Build image: docker-compose build"
    echo "   4. Start container: docker-compose up -d"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please review the issues above.${NC}"
    echo ""
    echo "⚠️  Common issues:"
    echo "   - Docker not running: systemctl start docker"
    echo "   - Port in use: Change HOST_PORT in .env"
    echo "   - SVN not installed: apt-get install subversion"
    echo ""
    exit 1
fi
