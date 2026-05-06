#!/usr/bin/env bash

# Sweet Home 3D Online - Backup Script
# Backs up user projects to a compressed archive

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backups}"
STORAGE_PATH="${STORAGE_PATH:-$SCRIPT_DIR/homes}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="sweethome3d-backup-${TIMESTAMP}.tar.gz"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if storage path exists
if [ ! -d "$STORAGE_PATH" ]; then
    msg_error "Storage path $STORAGE_PATH does not exist"
    exit 1
fi

# Check if there are files to backup
if [ -z "$(ls -A "$STORAGE_PATH")" ]; then
    msg_info "Storage path is empty, nothing to backup"
    exit 0
fi

# Calculate storage size
STORAGE_SIZE=$(du -sh "$STORAGE_PATH" | cut -f1)
msg_info "Storage size: $STORAGE_SIZE"

# Create backup
msg_info "Creating backup..."
cd "$(dirname "$STORAGE_PATH")"
tar -czf "$BACKUP_DIR/$BACKUP_NAME" "$(basename "$STORAGE_PATH")"

# Check if backup was successful
if [ $? -eq 0 ]; then
    BACKUP_SIZE=$(du -sh "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)
    msg_ok "Backup created: $BACKUP_NAME (Size: $BACKUP_SIZE)"
    echo "   Location: $BACKUP_DIR/$BACKUP_NAME"
else
    msg_error "Backup failed"
    exit 1
fi

# Cleanup old backups
msg_info "Cleaning up backups older than $RETENTION_DAYS days..."
DELETED_COUNT=0
while IFS= read -r old_backup; do
    rm -f "$old_backup"
    DELETED_COUNT=$((DELETED_COUNT + 1))
    msg_info "Deleted: $(basename "$old_backup")"
done < <(find "$BACKUP_DIR" -name "sweethome3d-backup-*.tar.gz" -type f -mtime +$RETENTION_DAYS)

if [ $DELETED_COUNT -eq 0 ]; then
    msg_ok "No old backups to delete"
else
    msg_ok "Deleted $DELETED_COUNT old backup(s)"
fi

# Summary
echo ""
echo "========================================="
echo "BACKUP SUMMARY"
echo "========================================="
echo "Timestamp:        $TIMESTAMP"
echo "Backup file:      $BACKUP_NAME"
echo "Backup location:  $BACKUP_DIR"
echo "Backup size:      $BACKUP_SIZE"
echo "Storage size:     $STORAGE_SIZE"
echo "Retention:        $RETENTION_DAYS days"
echo "========================================="

# List all backups
echo ""
msg_info "Available backups:"
ls -lh "$BACKUP_DIR"/sweethome3d-backup-*.tar.gz 2>/dev/null | awk '{print "   " $9 " (" $5 ")"}'

msg_ok "Backup completed successfully!"
