#!/bin/bash
# Sweet Home 3D Docker - Proxmox LXC Deployment Guide & Checklist
# This script provides a comprehensive deployment checklist for Proxmox 9.1.2

set -e

RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'

clear

cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║          🏠 Sweet Home 3D 7.7-Online - Proxmox 9.1.2 Deployment              ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

EOF

echo -e "${CYAN}This guide will help you deploy Sweet Home 3D on Proxmox VE 9.1.2${RESET}\n"

# Function to ask yes/no question
confirm() {
    local prompt="$1"
    local response
    
    while true; do
        read -p "$(echo -e ${CYAN}${prompt}${RESET}) [Y/n]: " -r response
        case "$response" in
            [yY][eE][sS]|[yY]|"")
                return 0
                ;;
            [nN][oO]|[nN])
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

# Function to print section header
section() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}$1${RESET}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
}

# Deployment Checklist
section "PRE-DEPLOYMENT CHECKLIST"

echo -e "${YELLOW}📋 Please verify the following:${RESET}\n"

checklist=(
    "Proxmox VE 9.1.2 is installed and accessible"
    "You have root/sudo access to Proxmox"
    "Network is configured correctly (192.168.4.x range available)"
    "You have SSH access to Proxmox node"
    "At least 15GB free disk space available"
    "You have cloned or downloaded this repository"
)

for i in "${!checklist[@]}"; do
    echo -n "  $((i+1)). ${checklist[$i]}... "
    if confirm ""; then
        echo -e "${GREEN}✓${RESET}"
    else
        echo -e "${RED}✗ FAILED${RESET}"
        exit 1
    fi
done

# Step 1: Proxmox Container Creation
section "STEP 1: CREATE PROXMOX LXC CONTAINER"

echo -e "${YELLOW}🔧 Container Specifications:${RESET}"
cat << EOF
  • OS: Debian 13
  • CPU: 2 cores (minimum 1)
  • RAM: 2 GB (minimum 1 GB, recommended 2+ GB)
  • Disk: 8 GB (minimum, recommended 10-15 GB)
  • Network: Bridge (default vmbr0)
  • IP Address: 192.168.4.25
  • Unprivileged: Yes (with nesting support)

EOF

echo -e "${CYAN}You can create the container using:${RESET}\n"

echo -e "${BOLD}Option A: Proxmox Web Interface${RESET}"
cat << 'EOF'
  1. Login to Proxmox Web UI (https://proxmox-ip:8006)
  2. Click "Create CT" button
  3. Fill in:
     - Node: Select your Proxmox node
     - CT ID: Auto (or choose >100 for unprivileged)
     - Hostname: sweethome3d
     - Password: [set secure password]
     - Resource Pool: (optional)
  4. Select Template: debian-13-standard_13.x_amd64
  5. Disks: rootfs = 8 GB (or more)
  6. CPU: 2 cores
  7. Memory: 2048 MB (RAM)
  8. Network: Hostname = sweethome3d, IP = 192.168.4.25/24
  9. Finish

EOF

echo -e "${BOLD}Option B: Command Line (on Proxmox node)${RESET}"
cat << 'EOF'
  # Note: Adjust CT ID (e.g., 101), storage (local-lvm), and settings as needed
  pct create 101 local:vztmpl/debian-13-standard_13.x_amd64.tar.zst \
    --hostname sweethome3d \
    --memory 2048 \
    --cores 2 \
    --storage local-lvm \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.4.25/24,gw=192.168.4.1 \
    --features nesting=1 \
    --unprivileged 1

  # Start the container
  pct start 101

EOF

if confirm "Has the container been created and started?"; then
    echo -e "${GREEN}✓ Container created${RESET}\n"
else
    echo -e "${YELLOW}Please create the container and start it, then continue.${RESET}\n"
    read -p "Press Enter to continue..."
fi

# Step 2: SSH Connection
section "STEP 2: CONNECT TO CONTAINER VIA SSH"

echo -e "${YELLOW}📡 SSH Connection:${RESET}\n"

echo "Connection details:"
echo "  • Host: 192.168.4.25"
echo "  • Port: 22"
echo "  • User: root"
echo ""

cat << 'EOF'
From your development machine:
  ssh root@192.168.4.25
  # Enter the password you set during container creation

EOF

if confirm "Are you connected to the container via SSH?"; then
    echo -e "${GREEN}✓ Connected${RESET}\n"
else
    echo -e "${YELLOW}Please connect to the container and continue.${RESET}\n"
    read -p "Press Enter to continue..."
fi

# Step 3: Repository Setup
section "STEP 3: DOWNLOAD & SETUP REPOSITORY"

cat << 'EOF'
Inside the container, run:

  # Update system packages
  apt-get update
  apt-get upgrade -y

  # Install git
  apt-get install -y git curl wget

  # Clone the repository
  cd /opt
  git clone https://github.com/andry360/sweethome3d-docker.git
  cd sweethome3d-docker

EOF

echo -e "${CYAN}Alternative: Direct download${RESET}"
cat << 'EOF'

  # If git is not available
  cd /opt
  wget -O sweethome3d-docker.zip https://github.com/andry360/sweethome3d-docker/archive/refs/heads/main.zip
  unzip sweethome3d-docker.zip
  cd sweethome3d-docker-main

EOF

if confirm "Has the repository been downloaded?"; then
    echo -e "${GREEN}✓ Repository downloaded${RESET}\n"
else
    echo -e "${YELLOW}Please download the repository and continue.${RESET}\n"
    read -p "Press Enter to continue..."
fi

# Step 4: Pre-flight Checks
section "STEP 4: RUN PRE-FLIGHT CHECKS"

cat << 'EOF'
In the container, run the pre-flight check:

  cd /opt/sweethome3d-docker
  bash preflight-check.sh

This will verify:
  ✓ Disk space available
  ✓ System dependencies
  ✓ Docker compatibility
  ✓ Network configuration
  ✓ File permissions

EOF

if confirm "Have the pre-flight checks passed?"; then
    echo -e "${GREEN}✓ Pre-flight checks passed${RESET}\n"
else
    echo -e "${RED}✗ Pre-flight checks failed${RESET}"
    echo -e "Review the errors above and resolve them before continuing."
    echo ""
    read -p "Press Enter to continue anyway..."
fi

# Step 5: Configuration
section "STEP 5: CONFIGURE ENVIRONMENT"

cat << 'EOF'
Initialize the environment:

  make init

This will:
  1. Create .env file from .env.example
  2. Create necessary directories (homes, backups)
  3. Set proper permissions

Then edit the configuration:

  nano .env

Key settings to review:
  • HOST_PORT=8080 (port for web access)
  • STORAGE_PATH=./homes (where projects are saved)
  • UPLOAD_MAX_FILESIZE=50M
  • AUTH_ENABLED=false (set to 'true' to require password)
  • AUTH_USERNAME=admin
  • AUTH_PASSWORD= (leave empty for auto-generation)

EOF

if confirm "Has the configuration been completed?"; then
    echo -e "${GREEN}✓ Configuration completed${RESET}\n"
else
    echo -e "${YELLOW}Please configure .env and continue.${RESET}\n"
    read -p "Press Enter to continue..."
fi

# Step 6: Build Docker Image
section "STEP 6: BUILD DOCKER IMAGE"

echo -e "${YELLOW}⏱️  Estimated build time: 20-30 minutes${RESET}\n"

cat << 'EOF'
Build the Docker image:

  make build

Or with BuildKit for better caching:

  DOCKER_BUILDKIT=1 docker-compose build

Progress indicators:
  • Stage 1: Download and compile (10-20 minutes)
  • Stage 2: Build runtime image (5-10 minutes)

If the build fails:
  • Check internet connection (needs SourceForge access)
  • Increase VM memory if available
  • Try again with: docker-compose build --no-cache

EOF

if confirm "Is the Docker image build complete and successful?"; then
    echo -e "${GREEN}✓ Docker image built${RESET}\n"
else
    echo -e "${RED}✗ Build failed${RESET}"
    echo -e "Run: ${CYAN}make logs${RESET} to see detailed error messages"
    read -p "Press Enter to continue..."
fi

# Step 7: Start Container
section "STEP 7: START SWEET HOME 3D CONTAINER"

cat << 'EOF'
Start the Docker container:

  make start

Or manually:

  docker-compose up -d

Check if it's running:

  docker-compose ps

Output should show:
  STATUS: Up (healthy)
  PORTS: 0.0.0.0:8080->80/tcp

EOF

if confirm "Is the container running and healthy?"; then
    echo -e "${GREEN}✓ Container running${RESET}\n"
else
    echo -e "${YELLOW}Check container status:${RESET}"
    echo "  docker-compose logs -f"
    read -p "Press Enter to continue..."
fi

# Step 8: Verify Access
section "STEP 8: VERIFY WEB ACCESS"

echo -e "${YELLOW}🌐 Access Sweet Home 3D:${RESET}\n"

echo "From your browser:"
echo "  http://192.168.4.25:8080"
echo ""

echo -e "${CYAN}If not accessible, check:${RESET}"
cat << 'EOF'
  1. Container is running: docker-compose ps
  2. Port is exposed: netstat -tuln | grep 8080
  3. Firewall allows access
  4. Network is reachable: ping 192.168.4.25
  5. Check logs: docker-compose logs -f

EOF

if confirm "Can you access the web interface at http://192.168.4.25:8080?"; then
    echo -e "${GREEN}✓ Web interface accessible${RESET}\n"
else
    echo -e "${RED}✗ Cannot access web interface${RESET}"
    echo "Please resolve the connectivity issues."
    read -p "Press Enter to continue..."
fi

# Step 9: Functional Testing
section "STEP 9: FUNCTIONAL TESTING"

echo -e "${YELLOW}🧪 Test the application:${RESET}\n"

steps=(
    "Create a new project (click 'New' or start designing)"
    "Add some furniture/walls to the design"
    "Save the project (should show 'Project saved' message)"
    "Refresh browser (F5)"
    "Verify project appears in project list"
    "Load and verify the saved project"
    "Check storage directory has .sh3d files: ls -la homes/"
)

for i in "${!steps[@]}"; do
    echo -n "  Step $((i+1)): ${steps[$i]}... "
    if confirm ""; then
        echo -e "${GREEN}✓${RESET}"
    else
        echo -e "${RED}✗ FAILED${RESET}"
    fi
done

echo ""

# Final Summary
section "✅ DEPLOYMENT COMPLETED"

cat << 'EOF'
Sweet Home 3D is now running on your Proxmox LXC container!

📊 Deployment Summary:
  • Container ID: 101 (adjust if different)
  • Container IP: 192.168.4.25
  • Access URL: http://192.168.4.25:8080
  • Storage Path: /opt/sweethome3d/homes
  • Config: /opt/sweethome3d/.env

🔗 Quick Links:
  • Web Interface: http://192.168.4.25:8080
  • Configuration: /opt/sweethome3d/.env
  • Logs: docker-compose logs -f
  • Backup: make backup
  • Restore: make restore

📚 Useful Commands:
  • Status: make test
  • View logs: make logs
  • Stop service: make stop
  • Restart service: make restart
  • Backup projects: make backup

🔒 Security Notes:
  • Default: No authentication (AUTH_ENABLED=false)
  • To enable: Set AUTH_ENABLED=true in .env
  • Auto-generated password: Check .env file
  • Restrict port 8080 access via firewall if needed
  • Use reverse proxy (NPMplus, Traefik) for HTTPS

📞 Troubleshooting:
  • Check status: docker-compose ps
  • View errors: docker-compose logs -f
  • Restart: make restart
  • Reset: make clean && make init && make build

🚀 Next Steps:
  1. Configure backups: man backup-homes.sh
  2. Set up reverse proxy (optional, recommended for HTTPS)
  3. Configure automatic backups via cron
  4. Monitor container resources

EOF

echo -e "${GREEN}Happy designing with Sweet Home 3D! 🏠${RESET}\n"

echo -e "${CYAN}For support or issues:${RESET}"
echo "  • GitHub: https://github.com/andry360/sweethome3d-docker"
echo "  • Issues: https://github.com/andry360/sweethome3d-docker/issues"
echo ""
