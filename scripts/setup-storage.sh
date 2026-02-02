#!/bin/bash
# Media Storage Setup Script
# Creates directory structure for media files

set -e

echo "========================================="
echo "Like2Share Media Storage Setup"
echo "========================================="
echo ""

# Base directory
STORAGE_DIR="$(dirname "$0")/../storage"
cd "$STORAGE_DIR"

echo "📁 Creating media storage directories..."

# Create main directories
mkdir -p media/{images,videos,thumbnails,profiles,temp}

# Create subdirectories for images
mkdir -p media/images/{posts,original,processed}

# Create subdirectories for videos
mkdir -p media/videos/{posts,original,processed,streams}

# Create subdirectories for thumbnails
mkdir -p media/thumbnails/{images,videos}

# Create subdirectories for profiles
mkdir -p media/profiles/{avatars,covers}

# Create temp subdirectories
mkdir -p media/temp/{uploads,processing}

# Create backup directory
mkdir -p ../backups/media

echo "✅ Directory structure created!"
echo ""

# Set permissions (Linux/Mac only)
if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🔒 Setting permissions..."
    chmod -R 755 media/
    echo "✅ Permissions set!"
    echo ""
fi

# Create .gitkeep files to preserve empty directories
echo "📝 Creating .gitkeep files..."
find media -type d -empty -exec touch {}/.gitkeep \;
echo "✅ .gitkeep files created!"
echo ""

# Create sample .env additions
cat > ../storage.env.example << 'EOF'
# Storage Configuration
MEDIA_STORAGE_PATH=/app/media
MEDIA_BASE_URL=http://localhost/media

# File Size Limits (in bytes)
MAX_FILE_SIZE=104857600        # 100MB
MAX_IMAGE_SIZE=10485760        # 10MB
MAX_VIDEO_SIZE=104857600       # 100MB
MAX_PROFILE_PIC_SIZE=2097152   # 2MB

# Allowed file types
ALLOWED_IMAGE_TYPES=jpg,jpeg,png,gif,webp
ALLOWED_VIDEO_TYPES=mp4,webm,mov

# Thumbnail settings
THUMBNAIL_SMALL_SIZE=150
THUMBNAIL_MEDIUM_SIZE=300
THUMBNAIL_LARGE_SIZE=600
THUMBNAIL_QUALITY=85

# Video processing
ENABLE_VIDEO_PROCESSING=true
VIDEO_MAX_DURATION=300         # 5 minutes in seconds
VIDEO_TRANSCODE_FORMAT=mp4

# Cleanup
TEMP_FILE_RETENTION_HOURS=24
AUTO_CLEANUP_ENABLED=true

# Storage quotas per user
USER_STORAGE_QUOTA=5368709120  # 5GB in bytes
USER_MAX_FILES=1000
EOF

echo "✅ Created storage.env.example"
echo ""

# Display directory structure
echo "📊 Directory structure:"
tree -L 3 media 2>/dev/null || find media -type d | sed 's|[^/]*/|  |g'

echo ""
echo "========================================="
echo "✅ Media storage setup completed!"
echo "========================================="
echo ""
echo "Storage structure created at: $(pwd)/media"
echo ""
echo "Next steps:"
echo "1. Review storage.env.example and add to your .env file"
echo "2. Configure your backend to use these paths"
echo "3. Set up backup strategy"
echo "4. Consider CDN for production"
echo ""
