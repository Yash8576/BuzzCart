#!/bin/bash
# Media Backup Script
# Creates compressed backup of media files

set -e

STORAGE_DIR="$(dirname "$0")/../storage/media"
BACKUP_DIR="$(dirname "$0")/../backups/media"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="media_backup_${TIMESTAMP}.tar.gz"

echo "========================================="
echo "Like2Share Media Backup"
echo "========================================="
echo ""

# Check if storage directory exists
if [ ! -d "$STORAGE_DIR" ]; then
    echo "❌ Error: Storage directory not found: $STORAGE_DIR"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Calculate storage size
STORAGE_SIZE=$(du -sh "$STORAGE_DIR" 2>/dev/null | cut -f1)
echo "📊 Storage size: $STORAGE_SIZE"
echo ""

# Count files
FILE_COUNT=$(find "$STORAGE_DIR" -type f | wc -l)
echo "📁 Files to backup: $FILE_COUNT"
echo ""

# Create backup
echo "📦 Creating backup..."
echo "   Backup file: $BACKUP_NAME"
echo ""

cd "$(dirname "$STORAGE_DIR")"
tar -czf "$BACKUP_DIR/$BACKUP_NAME" \
    --exclude='temp/*' \
    --exclude='*.tmp' \
    "media/"

# Verify backup
if [ -f "$BACKUP_DIR/$BACKUP_NAME" ]; then
    BACKUP_SIZE=$(du -sh "$BACKUP_DIR/$BACKUP_NAME" 2>/dev/null | cut -f1)
    echo "✅ Backup created successfully!"
    echo "   Size: $BACKUP_SIZE"
    echo "   Location: $BACKUP_DIR/$BACKUP_NAME"
else
    echo "❌ Error: Backup failed!"
    exit 1
fi

echo ""

# Clean old backups (keep last 7)
echo "🧹 Cleaning old backups (keeping last 7)..."
cd "$BACKUP_DIR"
ls -t media_backup_*.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f 2>/dev/null || true

# List recent backups
echo ""
echo "📋 Recent backups:"
ls -lht "$BACKUP_DIR"/media_backup_*.tar.gz 2>/dev/null | head -7 || echo "   No backups found"

echo ""
echo "========================================="
echo "✅ Backup completed!"
echo "========================================="
echo ""
echo "To restore:"
echo "  tar -xzf $BACKUP_DIR/$BACKUP_NAME -C $(dirname "$STORAGE_DIR")"
echo ""
