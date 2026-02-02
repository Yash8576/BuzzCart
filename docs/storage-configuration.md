# Storage Configuration Guide for Like2Share

## Storage Types

### 1. Local Storage (Development)
- **Path**: `storage/media/`
- **Suitable for**: Development, testing, small deployments
- **Pros**: Simple, no external dependencies
- **Cons**: Not scalable, single point of failure

### 2. Cloud Storage (Production Recommended)

#### AWS S3
```bash
# Environment variables
AWS_REGION=us-east-1
AWS_S3_BUCKET=like2share-media
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_CLOUDFRONT_DOMAIN=your_cdn_domain

# Backend configuration
STORAGE_TYPE=s3
STORAGE_BUCKET=like2share-media
```

**Setup Steps:**
1. Create S3 bucket
2. Configure CORS policy
3. Set up CloudFront distribution
4. Configure IAM user with S3 access
5. Update backend to use AWS SDK

#### Azure Blob Storage
```bash
# Environment variables
AZURE_STORAGE_ACCOUNT=like2share
AZURE_STORAGE_KEY=your_key
AZURE_STORAGE_CONTAINER=media
AZURE_CDN_ENDPOINT=your_cdn_endpoint

# Backend configuration
STORAGE_TYPE=azure
STORAGE_CONTAINER=media
```

**Setup Steps:**
1. Create storage account
2. Create blob container
3. Configure CDN profile
4. Set up CORS rules
5. Update backend to use Azure SDK

#### Google Cloud Storage
```bash
# Environment variables
GCP_PROJECT_ID=like2share
GCP_BUCKET_NAME=like2share-media
GCP_SERVICE_ACCOUNT_KEY=/path/to/key.json
GCP_CDN_URL=your_cdn_url

# Backend configuration
STORAGE_TYPE=gcs
STORAGE_BUCKET=like2share-media
```

**Setup Steps:**
1. Create GCS bucket
2. Configure Cloud CDN
3. Set up service account
4. Configure CORS policy
5. Update backend to use GCS SDK

## File Upload Flow

```
User Upload → Backend Validation → Virus Scan (optional) → 
Process/Resize → Store Original → Generate Thumbnails → 
Update Database → Return URLs
```

### Backend Processing Steps

1. **Receive Upload**
   - Validate file type
   - Check file size
   - Verify user quota

2. **Security Checks**
   - Scan for malware
   - Validate MIME type
   - Strip metadata

3. **Image Processing**
   - Optimize/compress
   - Generate thumbnails
   - Convert to web formats

4. **Video Processing**
   - Extract thumbnail
   - Transcode if needed
   - Generate preview

5. **Storage**
   - Save original
   - Save processed versions
   - Update database

6. **Response**
   - Return URLs
   - Update user quota
   - Log metrics

## File Naming Convention

```
Format: {type}/{user_id}/{timestamp}_{random}_{original_name}

Examples:
- images/posts/550e8400-e29b-41d4-a716-446655440000/20260121_abc123_sunset.jpg
- videos/posts/550e8400-e29b-41d4-a716-446655440000/20260121_def456_birthday.mp4
- profiles/avatars/550e8400-e29b-41d4-a716-446655440000/20260121_ghi789_avatar.png
```

## URL Structure

### Development
```
http://localhost/media/images/posts/{user_id}/{filename}
http://localhost/media/videos/posts/{user_id}/{filename}
http://localhost/media/profiles/avatars/{user_id}/{filename}
```

### Production with CDN
```
https://cdn.like2share.com/images/posts/{user_id}/{filename}
https://cdn.like2share.com/videos/posts/{user_id}/{filename}
https://cdn.like2share.com/profiles/avatars/{user_id}/{filename}
```

## Image Processing

### Recommended Libraries

**Go (Backend):**
```go
import (
    "github.com/disintegration/imaging"
    "github.com/h2non/bimg"  // For complex operations
)
```

**Node.js Alternative:**
```javascript
const sharp = require('sharp');
```

**Python Alternative:**
```python
from PIL import Image
```

### Example Go Image Processing

```go
package storage

import (
    "image"
    "github.com/disintegration/imaging"
)

func ProcessImage(src image.Image, maxWidth, maxHeight int) (image.Image, error) {
    // Resize if needed
    bounds := src.Bounds()
    if bounds.Dx() > maxWidth || bounds.Dy() > maxHeight {
        src = imaging.Fit(src, maxWidth, maxHeight, imaging.Lanczos)
    }
    
    // Optimize quality
    return src, nil
}

func GenerateThumbnails(src image.Image) map[string]image.Image {
    return map[string]image.Image{
        "small":  imaging.Fill(src, 150, 150, imaging.Center, imaging.Lanczos),
        "medium": imaging.Fill(src, 300, 300, imaging.Center, imaging.Lanczos),
        "large":  imaging.Fill(src, 600, 600, imaging.Center, imaging.Lanczos),
    }
}
```

## Video Processing

### Recommended: FFmpeg

```bash
# Install FFmpeg
# Ubuntu/Debian
sudo apt-get install ffmpeg

# macOS
brew install ffmpeg

# Windows - Download from https://ffmpeg.org
```

### Example Video Operations

```bash
# Extract thumbnail at 1 second
ffmpeg -i input.mp4 -ss 00:00:01 -vframes 1 -vf scale=300:300 thumbnail.jpg

# Transcode to web-friendly format
ffmpeg -i input.mov -c:v libx264 -c:a aac -movflags +faststart output.mp4

# Generate multiple quality versions
ffmpeg -i input.mp4 -c:v libx264 -crf 23 -preset fast \
  -vf scale=1280:720 -c:a aac -b:a 128k output_720p.mp4
```

## Security Best Practices

### 1. File Validation
```go
// Validate MIME type
allowedTypes := map[string]bool{
    "image/jpeg": true,
    "image/png":  true,
    "image/gif":  true,
    "image/webp": true,
    "video/mp4":  true,
}

// Check file extension
allowedExts := []string{".jpg", ".jpeg", ".png", ".gif", ".webp", ".mp4"}
```

### 2. Virus Scanning
```bash
# Use ClamAV for virus scanning
sudo apt-get install clamav
clamscan --infected --remove file.jpg
```

### 3. Content Security Policy
```nginx
# In nginx.conf
add_header Content-Security-Policy "default-src 'self'; img-src 'self' data: https:; media-src 'self' https:;";
```

### 4. Rate Limiting
```nginx
# In nginx.conf
limit_req_zone $binary_remote_addr zone=upload_limit:10m rate=2r/s;
limit_req zone=upload_limit burst=5 nodelay;
```

## Monitoring and Metrics

### Key Metrics to Track

1. **Storage Metrics**
   - Total storage used
   - Storage per user
   - Storage growth rate

2. **Upload Metrics**
   - Upload success rate
   - Upload failure reasons
   - Average upload time

3. **Performance Metrics**
   - Processing time
   - Thumbnail generation time
   - CDN cache hit ratio

4. **Cost Metrics**
   - Storage costs
   - Bandwidth costs
   - CDN costs

### Monitoring Tools

- **Prometheus + Grafana**: Metrics and visualization
- **CloudWatch**: AWS monitoring
- **Azure Monitor**: Azure metrics
- **Stackdriver**: GCP monitoring

## Backup Strategy

### Automated Backups

```bash
# Cron job for daily backups (Linux)
0 2 * * * /path/to/like2share/scripts/backup-media.sh

# Windows Task Scheduler
# Run: scripts\backup-media.bat
# Schedule: Daily at 2:00 AM
```

### Backup Retention Policy

- **Daily backups**: Keep for 7 days
- **Weekly backups**: Keep for 4 weeks
- **Monthly backups**: Keep for 12 months

### Disaster Recovery

1. **Regular Testing**: Test restores quarterly
2. **Off-site Storage**: Store backups in different region
3. **Documentation**: Maintain recovery procedures
4. **Monitoring**: Alert on backup failures

## Cost Optimization

### 1. Use Appropriate Storage Classes

**AWS S3:**
- Frequent access: S3 Standard
- Infrequent access: S3 IA
- Archive: S3 Glacier

**Azure:**
- Hot tier: Frequent access
- Cool tier: Infrequent access
- Archive tier: Long-term storage

### 2. Lifecycle Policies

```json
{
  "Rules": [{
    "Id": "MoveOldMedia",
    "Status": "Enabled",
    "Transitions": [{
      "Days": 90,
      "StorageClass": "STANDARD_IA"
    }, {
      "Days": 365,
      "StorageClass": "GLACIER"
    }]
  }]
}
```

### 3. CDN Optimization

- Enable compression
- Set appropriate cache headers
- Use image optimization services
- Implement lazy loading

## Scaling Considerations

### When to Scale

- Storage > 100GB
- >1000 uploads/day
- Multiple regions needed
- Performance degradation

### Scaling Options

1. **Horizontal Scaling**: Multiple storage servers
2. **CDN**: Global content delivery
3. **Object Storage**: S3, Azure Blob, GCS
4. **Database Optimization**: Separate metadata from files

## Troubleshooting

### Common Issues

**Upload fails:**
- Check file size limits
- Verify storage quota
- Check network connectivity
- Review backend logs

**Slow uploads:**
- Implement chunked uploads
- Check network bandwidth
- Optimize backend processing
- Consider CDN

**Permission errors:**
- Verify directory permissions
- Check user quotas
- Review CORS settings
- Validate credentials

### Debug Commands

```bash
# Check storage usage
df -h

# Monitor uploads in real-time
tail -f /var/log/nginx/access.log | grep upload

# Check file permissions
ls -la storage/media/

# Test upload endpoint
curl -X POST -F "file=@test.jpg" http://localhost:8080/api/upload
```

## Migration Guide

See migration scripts for detailed instructions:
- `scripts/migrate-to-s3.sh` - AWS S3 migration
- `scripts/migrate-to-azure.sh` - Azure Blob migration
- `scripts/migrate-to-gcs.sh` - Google Cloud Storage migration

For complete setup instructions, see `storage/README.md`
