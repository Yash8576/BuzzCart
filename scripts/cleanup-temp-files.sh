#!/bin/bash
# Cleanup script for temporary files
# Removes files older than specified retention period

set -e

STORAGE_DIR="$(dirname "$0")/../storage/media"
RETENTION_HOURS=${1:-24}  # Default 24 hours
RETENTION_MINUTES=$((RETENTION_HOURS * 60))

echo "========================================="
echo "Like2Share Temporary Files Cleanup"
echo "========================================="
echo ""
echo "Retention period: $RETENTION_HOURS hours"
echo ""

# Check if storage directory exists
if [ ! -d "$STORAGE_DIR" ]; then
    echo "❌ Error: Storage directory not found: $STORAGE_DIR"
    exit 1
fi

cd "$STORAGE_DIR"

# Count files before cleanup
TEMP_FILES_BEFORE=$(find temp/ -type f 2>/dev/null | wc -l)
echo "📊 Temporary files before cleanup: $TEMP_FILES_BEFORE"

# Clean temp uploads
if [ -d "temp/uploads" ]; then
    echo "🧹 Cleaning temp uploads..."
    find temp/uploads -type f -mmin +$RETENTION_MINUTES -delete 2>/dev/null || true
    DELETED_UPLOADS=$(($TEMP_FILES_BEFORE - $(find temp/uploads -type f 2>/dev/null | wc -l)))
    echo "   Deleted: $DELETED_UPLOADS files"
fi

# Clean temp processing
if [ -d "temp/processing" ]; then
    echo "🧹 Cleaning temp processing..."
    find temp/processing -type f -mmin +$RETENTION_MINUTES -delete 2>/dev/null || true
fi

# Clean orphaned thumbnails (older than 90 days)
if [ -d "thumbnails" ]; then
    echo "🧹 Cleaning old thumbnails..."
    find thumbnails -type f -mtime +90 -delete 2>/dev/null || true
fi

# Remove empty directories
echo "🧹 Removing empty directories..."
find temp -type d -empty -delete 2>/dev/null || true

# Count files after cleanup
TEMP_FILES_AFTER=$(find temp/ -type f 2>/dev/null | wc -l)
echo "📊 Temporary files after cleanup: $TEMP_FILES_AFTER"
echo ""

# Calculate storage saved
STORAGE_USED=$(du -sh temp 2>/dev/null | cut -f1)
echo "💾 Temp storage used: $STORAGE_USED"

echo ""
echo "✅ Cleanup completed!"
echo ""
echo "Total files removed: $((TEMP_FILES_BEFORE - TEMP_FILES_AFTER))"
echo ""
