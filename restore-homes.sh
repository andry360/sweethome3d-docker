#!/usr/bin/env bash

# Sweet Home 3D Online - Restore Script
# Restores user projects from a backup archive

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backups}"
STORAGE_PATH="${STORAGE_PATH:-$SCRIPT_DIR/homes}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
msg_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

msg_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

msg_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

msg_warn() {
    echo -e "${RED}[WARNING]${NC} $1"
}

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    msg_error "Backup directory $BACKUP_DIR does not exist"
    exit 1
fi

# List available backups
echo ""
echo "========================================="
echo "AVAILABLE BACKUPS"
echo "========================================="

BACKUPS=($(ls -t "$BACKUP_DIR"/sweethome3d-backup-*.tar.gz 2>/dev/null))

if [ ${#BACKUPS[@]} -eq 0 ]; then
    msg_error "No backups found in $BACKUP_DIR"
    exit 1
fi

for i in "${!BACKUPS[@]}"; do
    BACKUP_FILE="${BACKUPS[$i]}"
    BACKUP_DATE=$(stat -c %y "$BACKUP_FILE" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
    BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    echo -e "${BLUE}[$((i+1))]${NC} $(basename "$BACKUP_FILE")"
    echo "    Date: $BACKUP_DATE | Size: $BACKUP_SIZE"
done

echo "========================================="
echo ""

# Prompt user to select backup
read -p "Enter backup number to restore (or 'q' to quit): " SELECTION

if [[ "$SELECTION" == "q" ]] || [[ "$SELECTION" == "Q" ]]; then
    msg_info "Restore cancelled"
    exit 0
fi

# Validate selection
if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt ${#BACKUPS[@]} ]; then
    msg_error "Invalid selection"
    exit 1
fi

SELECTED_BACKUP="${BACKUPS[$((SELECTION-1))]}"
msg_info "Selected: $(basename "$SELECTED_BACKUP")"

# Check if storage path exists and has content
if [ -d "$STORAGE_PATH" ] && [ "$(ls -A "$STORAGE_PATH")" ]; then
    msg_warn "Current storage contains data that will be OVERWRITTEN!"
    echo ""
    echo "Current storage: $STORAGE_PATH"
    echo "Current size: $(du -sh "$STORAGE_PATH" | cut -f1)"
    echo ""
    read -p "Do you want to backup current data before restore? [y/N]: " BACKUP_CURRENT
    
    if [[ "$BACKUP_CURRENT" =~ ^[Yy]$ ]]; then
        msg_info "Creating backup of current data..."
        bash "$SCRIPT_DIR/backup-homes.sh"
        if [ $? -ne 0 ]; then
            msg_error "Failed to backup current data"
            exit 1
        fi
        msg_ok "Current data backed up"
    fi
    
    echo ""
    read -p "Are you sure you want to restore and OVERWRITE current data? [y/N]: " CONFIRM
    
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        msg_info "Restore cancelled"
        exit 0
    fi
    
    msg_info "Removing current data..."
    rm -rf "$STORAGE_PATH"
fi

# Create parent directory if needed
mkdir -p "$(dirname "$STORAGE_PATH")"

# Restore backup
msg_info "Restoring backup..."
cd "$(dirname "$STORAGE_PATH")"
tar -xzf "$SELECTED_BACKUP"

if [ $? -eq 0 ]; then
    RESTORED_SIZE=$(du -sh "$STORAGE_PATH" | cut -f1)
    msg_ok "Restore completed successfully!"
    echo "   Restored to: $STORAGE_PATH"
    echo "   Restored size: $RESTORED_SIZE"
else
    msg_error "Restore failed"
    exit 1
fi

# Set proper permissions
chmod -R 755 "$STORAGE_PATH"

# Summary
echo ""
echo "========================================="
echo "RESTORE SUMMARY"
echo "========================================="
echo "Backup file:      $(basename "$SELECTED_BACKUP")"
echo "Restore location: $STORAGE_PATH"
echo "Restored size:    $RESTORED_SIZE"
echo "========================================="
echo ""
msg_ok "Remember to restart the Sweet Home 3D container if it's running:"
echo "   cd /opt/sweethome3d"
echo "   docker-compose restart"
