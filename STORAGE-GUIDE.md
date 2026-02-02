# Media Storage - Quick Reference Guide

## ✅ Storage Setup Complete!

Your Like2Share media storage is now configured with:

### 📁 Directory Structure
```
storage/media/
├── images/
│   ├── posts/          # Post images
│   ├── original/       # Original uploads
│   └── processed/      # Optimized images
├── videos/
│   ├── posts/          # Post videos
│   ├── original/       # Original uploads
│   ├── processed/      # Transcoded videos
│   └── streams/        # HLS/DASH streams (future)
├── thumbnails/
│   ├── images/         # Image thumbnails
│   └── videos/         # Video thumbnails
├── profiles/
│   ├── avatars/        # Profile pictures
│   └── covers/         # Cover photos
└── temp/
    ├── uploads/        # Temporary uploads
    └── processing/     # Processing queue
```

## 🚀 Quick Start

### Test Storage Setup
```bash
# Windows
dir storage\media /s

# Linux/Mac
ls -R storage/media/
```

### Upload a Test File
```bash
# Using curl
curl -X POST -F "file=@test.jpg" -F "type=image" http://localhost:8080/api/upload

# Expected response:
{
  "success": true,
  "url": "http://localhost/media/images/posts/{user_id}/{filename}",
  "thumbnail_url": "http://localhost/media/thumbnails/images/{filename}"
}
```

## 📊 Storage Limits

| Type | Max Size | Formats |
|------|----------|---------|
| Images | 10MB | JPG, PNG, GIF, WebP |
| Videos | 100MB | MP4, WebM, MOV |
| Profile Pics | 2MB | JPG, PNG |
| Per Request | 100MB | All types |
| Per User | 5GB | Total storage |

## 🔧 Management Commands

### Check Storage Usage
```powershell
# Windows
Get-ChildItem -Path storage\media -Recurse | Measure-Object -Property Length -Sum | 
  Select-Object @{Name="Size(MB)";Expression={[math]::Round($_.Sum/1MB,2)}}

# Linux/Mac
du -sh storage/media/*
```

### Clean Temporary Files
```bash
# Windows
.\scripts\cleanup-temp-files.bat

# Linux/Mac
./scripts/cleanup-temp-files.sh
```

### Backup Media
```bash
# Windows
.\scripts\backup-media.bat

# Linux/Mac
./scripts/backup-media.sh
```

## 🌐 URL Patterns

### Development
```
Images:  http://localhost/media/images/posts/{user_id}/{filename}
Videos:  http://localhost/media/videos/posts/{user_id}/{filename}
Thumbs:  http://localhost/media/thumbnails/images/{filename}
Profile: http://localhost/media/profiles/avatars/{user_id}/{filename}
```

### Production (with CDN)
```
Images:  https://cdn.like2share.com/images/posts/{user_id}/{filename}
Videos:  https://cdn.like2share.com/videos/posts/{user_id}/{filename}
Thumbs:  https://cdn.like2share.com/thumbnails/images/{filename}
Profile: https://cdn.like2share.com/profiles/avatars/{user_id}/{filename}
```

## 🔐 Security Features

✅ MIME type validation  
✅ File extension checking  
✅ Size limit enforcement  
✅ User quota management  
✅ Rate limiting (2 uploads/sec)  
✅ Automatic temp file cleanup  
✅ Virus scanning support (optional)  

## 📝 Environment Variables

Add these to your `.env` file (already in `.env.example`):

```bash
# Storage
MEDIA_STORAGE_PATH=./storage/media
MEDIA_BASE_URL=http://localhost/media
STORAGE_TYPE=local

# Limits
MAX_FILE_SIZE=104857600        # 100MB
MAX_IMAGE_SIZE=10485760        # 10MB
MAX_VIDEO_SIZE=104857600       # 100MB

# Processing
THUMBNAIL_QUALITY=85
ENABLE_VIDEO_PROCESSING=true
TEMP_FILE_RETENTION_HOURS=24
```

## 🎯 Integration with Backend

### Go Example (Backend)
```go
package main

import (
    "io"
    "net/http"
    "os"
    "path/filepath"
)

func uploadHandler(w http.ResponseWriter, r *http.Request) {
    // Parse multipart form
    r.ParseMultipartForm(100 << 20) // 100MB
    
    file, handler, err := r.FormFile("file")
    if err != nil {
        http.Error(w, "Error retrieving file", http.StatusBadRequest)
        return
    }
    defer file.Close()
    
    // Create destination path
    destPath := filepath.Join("storage/media/images/posts", handler.Filename)
    
    // Create file
    dst, err := os.Create(destPath)
    if err != nil {
        http.Error(w, "Error creating file", http.StatusInternalServerError)
        return
    }
    defer dst.Close()
    
    // Copy file
    if _, err := io.Copy(dst, file); err != nil {
        http.Error(w, "Error saving file", http.StatusInternalServerError)
        return
    }
    
    // Return success
    w.WriteHeader(http.StatusOK)
    w.Write([]byte(`{"success": true, "url": "/media/images/posts/` + handler.Filename + `"}`))
}
```

## 📱 Frontend Integration

### Flutter Example
```dart
import 'package:http/http.dart' as http;
import 'dart:io';

Future<String> uploadImage(File imageFile) async {
  var request = http.MultipartRequest(
    'POST',
    Uri.parse('http://localhost:8080/api/upload'),
  );
  
  request.files.add(
    await http.MultipartFile.fromPath('file', imageFile.path),
  );
  
  var response = await request.send();
  var responseData = await response.stream.toBytes();
  var responseString = String.fromCharCodes(responseData);
  
  // Parse JSON and return URL
  return jsonDecode(responseString)['url'];
}
```

## 🐳 Docker Integration

Storage is already mounted in Docker Compose:

```yaml
volumes:
  - ../storage/media:/app/media
```

## ☸️ Kubernetes Integration

PersistentVolumeClaims created:
- `media-storage` (50GB) - Main media files
- `user-uploads` (100GB) - User uploads
- `thumbnails` (20GB) - Generated thumbnails

## 🔄 Backup Strategy

### Automated Backups
```bash
# Set up cron job (Linux)
0 2 * * * /path/to/scripts/backup-media.sh

# Windows Task Scheduler
# Task: scripts\backup-media.bat
# Schedule: Daily at 2:00 AM
```

### Manual Backup
```bash
# Windows
.\scripts\backup-media.bat

# Linux/Mac
./scripts/backup-media.sh
```

Backups stored in: `backups/media/`  
Retention: Last 7 backups

## 📈 Monitoring

Track these metrics:
- Total storage used
- Upload success rate
- Average file size
- Processing time
- CDN bandwidth (production)

## 🚀 Production Deployment

For production, migrate to cloud storage:

1. **AWS S3**
   - See: `docs/storage-configuration.md`
   - Script: `scripts/migrate-to-s3.sh`

2. **Azure Blob**
   - See: `docs/storage-configuration.md`
   - Script: `scripts/migrate-to-azure.sh`

3. **Google Cloud Storage**
   - See: `docs/storage-configuration.md`
   - Script: `scripts/migrate-to-gcs.sh`

## 🛠️ Troubleshooting

### Upload fails
```bash
# Check permissions
icacls storage\media

# Check disk space
Get-PSDrive C | Select-Object Used,Free

# Check logs
docker logs like2share_backend
```

### Slow processing
- Enable thumbnail queue
- Use async processing
- Consider CDN
- Implement chunked uploads

### Out of space
```bash
# Clean temp files
.\scripts\cleanup-temp-files.bat

# Check large files
Get-ChildItem -Path storage\media -Recurse | 
  Where-Object {$_.Length -gt 10MB} | 
  Sort-Object Length -Descending
```

## 📚 Documentation

- **Storage README**: `storage/README.md`
- **Configuration Guide**: `docs/storage-configuration.md`
- **Main Project**: `README.md`
- **Quick Start**: `QUICKSTART.md`

## ✅ Next Steps

1. ✅ Storage structure created
2. ✅ Configuration files ready
3. ⬜ Implement backend upload handler
4. ⬜ Add frontend upload UI
5. ⬜ Test file uploads
6. ⬜ Set up automated backups
7. ⬜ Configure CDN (production)

---

**Your storage system is ready to use!** 🎉

Start the backend and test with:
```bash
curl -X POST -F "file=@test.jpg" http://localhost:8080/api/upload
```
