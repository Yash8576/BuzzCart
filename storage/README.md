# Storage Directory Structure for Like2Share

## Overview
This directory contains all media files and uploads for the Like2Share application.

## Directory Structure

```
storage/
├── media/                  # Main media storage
│   ├── images/            # User uploaded images
│   │   ├── posts/        # Post images
│   │   └── original/     # Original uploads
│   ├── videos/            # User uploaded videos
│   │   ├── posts/        # Post videos
│   │   └── original/     # Original uploads
│   ├── thumbnails/        # Auto-generated thumbnails
│   │   ├── images/       # Image thumbnails
│   │   └── videos/       # Video thumbnails
│   ├── profiles/          # User profile pictures
│   └── temp/             # Temporary uploads (auto-cleaned)
├── backend_db/            # Backend database files (if using local)
└── frontend_db/           # Frontend local storage
```

## Storage Limits

### File Size Limits
- **Images**: Max 10MB per file
- **Videos**: Max 100MB per file
- **Profile Pictures**: Max 2MB per file
- **Total Upload**: 100MB per request

### Supported Formats

#### Images
- JPEG/JPG
- PNG
- GIF
- WebP
- SVG (sanitized)

#### Videos
- MP4
- WebM
- MOV
- AVI (converted to MP4)

## Storage Quotas

### Per User
- Total storage: 5GB
- Max files: 1000 files
- Max video duration: 5 minutes per video

### System Wide
- Development: 50GB
- Production: Scalable (cloud storage)

## Automatic Cleanup

### Temporary Files
- Auto-deleted after 24 hours
- Cleaned on server restart
- Manual cleanup via script

### Deleted Content
- Soft-deleted files retained for 30 days
- Hard-deleted after 30 days
- Can be restored within retention period

## Thumbnail Generation

### Image Thumbnails
- Small: 150x150px
- Medium: 300x300px
- Large: 600x600px

### Video Thumbnails
- Generated from frame at 1 second
- Size: 300x300px
- Format: JPEG

## CDN Configuration (Production)

For production, consider using:
- **AWS S3** + CloudFront
- **Azure Blob Storage** + CDN
- **Google Cloud Storage** + CDN

Configuration files available in `/scripts/cdn-setup/`

## Security

### Access Control
- Public read for published content
- Private storage for unpublished/draft content
- Signed URLs for temporary access

### File Validation
- MIME type checking
- File extension validation
- Virus scanning (optional, recommended for production)
- Image metadata stripping

### Rate Limiting
- 10 uploads per minute per user
- 100MB total per minute per user

## Backup Strategy

### Local Development
- Manual backups via script
- Stored in `/backups/media/`

### Production
- Daily automated backups
- Retention: 30 days
- Off-site replication

## Monitoring

### Metrics to Track
- Total storage used
- Upload success/failure rate
- Average file size
- Storage growth rate
- CDN bandwidth usage

### Alerts
- Storage > 80% capacity
- Upload failure rate > 5%
- CDN costs spike

## Commands

### Check storage usage
```bash
# Linux/Mac
du -sh storage/media/*

# Windows
Get-ChildItem -Path storage\media -Recurse | Measure-Object -Property Length -Sum
```

### Clean temporary files
```bash
# Use the cleanup script
./scripts/cleanup-temp-files.sh
# or
.\scripts\cleanup-temp-files.bat
```

### Backup media files
```bash
./scripts/backup-media.sh
# or
.\scripts\backup-media.bat
```

## Environment Variables

```bash
# Storage configuration
MEDIA_STORAGE_PATH=/app/media
MAX_FILE_SIZE=104857600  # 100MB in bytes
MAX_IMAGE_SIZE=10485760  # 10MB in bytes
THUMBNAIL_QUALITY=85
ENABLE_VIDEO_PROCESSING=true
TEMP_FILE_RETENTION_HOURS=24

# CDN (Production)
USE_CDN=false
CDN_URL=https://cdn.like2share.com
CDN_ACCESS_KEY=your_key_here
CDN_SECRET_KEY=your_secret_here
```

## Troubleshooting

### Out of space
```bash
# Check disk usage
df -h

# Clean temp files
./scripts/cleanup-temp-files.sh

# Remove old thumbnails
find storage/media/thumbnails -mtime +90 -delete
```

### Permission issues
```bash
# Fix permissions (Linux/Mac)
chmod -R 755 storage/media
chown -R www-data:www-data storage/media

# Windows
icacls storage\media /grant Users:(OI)(CI)F /T
```

### Slow uploads
- Check network bandwidth
- Verify NGINX upload limits
- Monitor backend processing
- Consider implementing chunked uploads

## Best Practices

1. **Use object storage in production** (S3, Azure Blob, GCS)
2. **Implement CDN** for faster global delivery
3. **Generate thumbnails asynchronously**
4. **Compress images** before storage
5. **Use progressive JPEG** for web display
6. **Implement lazy loading** in frontend
7. **Set proper cache headers**
8. **Monitor storage costs**
9. **Regular backups**
10. **Security scanning** for uploaded files

## Migration to Cloud Storage

When ready to migrate to cloud storage, see:
- `/scripts/migrate-to-s3.sh` - AWS S3 migration
- `/scripts/migrate-to-azure.sh` - Azure Blob migration
- `/docs/cloud-storage-setup.md` - Detailed guide
