# MinIO Storage Migration Guide for BuzzCart

## 🎯 Overview

This guide covers the complete migration from local file storage to MinIO (self-hosted S3) for the BuzzCart application.

## 📦 What's Included

✅ **Docker Compose**: MinIO service configuration with persistent volumes  
✅ **Go Backend**: Storage package with MinIO SDK integration  
✅ **Configuration**: Environment variables for MinIO credentials  
✅ **Example Handlers**: Ready-to-use upload/delete endpoints  
✅ **Documentation**: Complete API and usage documentation  

---

## 🚀 Quick Start

### Step 1: Update Dependencies

```bash
cd backend
go get github.com/minio/minio-go/v7
go mod tidy
```

### Step 2: Configure Environment Variables

Copy `.env.example` to `.env` and update MinIO settings:

```bash
cp .env.example .env
```

**`.env` configuration:**
```env
# MinIO Configuration
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin123
MINIO_USE_SSL=false
MINIO_BUCKET=buzzcart-media
```

### Step 3: Start Services

```bash
cd ../docker
docker-compose up -d
```

This will start:
- PostgreSQL (port 5432)
- Redis (port 6379)
- **MinIO API** (port 9000)
- **MinIO Console** (port 9001)
- Backend (port 8080)
- Frontend (port 80)
- Chatbot (port 8000)

### Step 4: Access MinIO Console

Open your browser and navigate to: **http://localhost:9001**

**Login credentials:**
- Username: `minioadmin`
- Password: `minioadmin123`

You should see the MinIO dashboard where you can:
- View buckets and files
- Upload files manually
- Configure bucket policies
- Monitor storage usage

### Step 5: Initialize Storage in Your Application

Update your `main.go` or startup file:

```go
package main

import (
    "buzzcart/internal/config"
    "buzzcart/internal/storage"
    "log"
)

func main() {
    // Load configuration from .env
    cfg := config.Load()
    
    // Initialize MinIO storage
    if err := storage.InitializeStorage(cfg); err != nil {
        log.Fatalf("Failed to initialize MinIO storage: %v", err)
    }
    
    // ... rest of your application setup
    // router setup, database connection, etc.
}
```

### Step 6: Add Upload Routes

Add the upload routes to your router:

```go
// In your router setup
api := router.Group("/api")
{
    // Upload endpoints
    upload := api.Group("/upload")
    {
        upload.POST("/image", handlers.UploadImageHandler)
        upload.POST("/video", handlers.UploadVideoHandler)
        upload.POST("/product-image", handlers.UploadProductImageHandler)
        
        // Protected routes (require authentication)
        upload.POST("/avatar", middleware.AuthMiddleware(), handlers.UploadAvatarHandler)
        upload.DELETE("/:objectName", middleware.AuthMiddleware(), handlers.DeleteFileHandler)
    }
}
```

---

## 📝 File Structure

```
backend/
├── internal/
│   ├── config/
│   │   └── config.go              # Updated with MinIO config
│   ├── storage/
│   │   ├── minio.go               # MinIO client implementation
│   │   ├── client.go              # Global client initialization
│   │   └── README.md              # Storage documentation
│   └── handlers/
│       ├── upload_handlers.go     # Upload/delete handlers
│       └── privacy_handlers_example.go
├── .env.example                    # Updated with MinIO vars
└── go.mod                          # Added minio-go dependency

docker/
└── docker-compose.yml              # Added MinIO service
```

---

## 🧪 Testing

### Test MinIO Health

```bash
curl http://localhost:9000/minio/health/live
```

**Expected response:** Empty 200 OK

### Test Image Upload

```bash
# Create a test image or use any existing image
curl -X POST http://localhost:8000/api/upload/image \
  -F "image=@/path/to/your/image.jpg"
```

**Expected response:**
```json
{
  "success": true,
  "url": "http://localhost:9000/buzzcart-media/images/uuid-here.jpg",
  "message": "File uploaded successfully"
}
```

### Test Video Upload

```bash
curl -X POST http://localhost:8000/api/upload/video \
  -F "video=@/path/to/your/video.mp4"
```

### Verify in MinIO Console

1. Go to http://localhost:9001
2. Click on the `buzzcart-media` bucket
3. Navigate to `images/` or `videos/` folder
4. You should see your uploaded files

---

## 🔄 Migration Steps

### Migrating Existing Files

If you have existing files in local storage (`storage/media/`), here's how to migrate them:

#### Option 1: Using MinIO Console (Manual)

1. Access MinIO Console: http://localhost:9001
2. Navigate to `buzzcart-media` bucket
3. Click "Upload" → "Upload Folder"
4. Select your `storage/media` directory
5. Wait for upload to complete

#### Option 2: Using MinIO CLI (Automated)

```bash
# Install MinIO Client (mc)
# Windows: Download from https://min.io/download
# Linux/Mac: wget https://dl.min.io/client/mc/release/linux-amd64/mc

# Configure MinIO alias
mc alias set local http://localhost:9000 minioadmin minioadmin123

# Upload entire media directory
mc cp --recursive ./storage/media/ local/buzzcart-media/

# Verify upload
mc ls local/buzzcart-media/
```

#### Option 3: Programmatic Migration (Go Script)

Create a migration script:

```go
package main

import (
    "buzzcart/internal/config"
    "buzzcart/internal/storage"
    "fmt"
    "io/ioutil"
    "log"
    "os"
    "path/filepath"
)

func main() {
    cfg := config.Load()
    
    if err := storage.InitializeStorage(cfg); err != nil {
        log.Fatalf("Failed to init storage: %v", err)
    }
    
    client := storage.GetStorageClient()
    localPath := "./storage/media"
    
    err := filepath.Walk(localPath, func(path string, info os.FileInfo, err error) error {
        if err != nil || info.IsDir() {
            return err
        }
        
        file, err := os.Open(path)
        if err != nil {
            return err
        }
        defer file.Close()
        
        relPath, _ := filepath.Rel(localPath, path)
        folder := filepath.Dir(relPath)
        
        url, err := client.UploadFileFromReader(
            file, 
            filepath.Base(path), 
            info.Size(), 
            "", 
            folder,
        )
        
        if err != nil {
            log.Printf("Failed to upload %s: %v", path, err)
            return nil
        }
        
        fmt.Printf("✓ Uploaded: %s -> %s\n", path, url)
        return nil
    })
    
    if err != nil {
        log.Fatalf("Migration failed: %v", err)
    }
    
    fmt.Println("✓ Migration completed!")
}
```

Run the migration:

```bash
go run migrate.go
```

### Update Database URLs

After migrating files, update database records to use new MinIO URLs:

```sql
-- Example: Update product images
UPDATE products 
SET image_url = REPLACE(
    image_url, 
    '/media/', 
    'http://localhost:9000/buzzcart-media/'
);

-- Example: Update user avatars
UPDATE users 
SET avatar = REPLACE(
    avatar, 
    '/media/avatars/', 
    'http://localhost:9000/buzzcart-media/avatars/'
);
```

---

## 🔐 Production Configuration

### 1. Change Default Credentials

**Update docker-compose.yml:**

```yaml
minio:
  environment:
    MINIO_ROOT_USER: your-secure-username
    MINIO_ROOT_PASSWORD: your-very-secure-password-min-32-chars
```

**Update .env:**

```env
MINIO_ACCESS_KEY=your-secure-username
MINIO_SECRET_KEY=your-very-secure-password-min-32-chars
```

### 2. Enable SSL/TLS

1. **Obtain SSL certificate** for your MinIO domain
2. **Configure MinIO with certificates**
3. **Update .env:**

```env
MINIO_ENDPOINT=minio.yourdomain.com:9000
MINIO_USE_SSL=true
```

### 3. Restrict Network Access

Update docker-compose.yml to restrict MinIO ports:

```yaml
minio:
  ports:
    - "127.0.0.1:9000:9000"  # Only accessible from localhost
    - "127.0.0.1:9001:9001"  # Only accessible from localhost
```

Use reverse proxy (nginx) for external access with authentication.

### 4. Backup Configuration

Set up automated backups:

```bash
# Using mc (MinIO Client)
mc mirror local/buzzcart-media /path/to/backup/

# Or use cron job
0 2 * * * mc mirror local/buzzcart-media /backup/buzzcart-media-$(date +\%Y\%m\%d)
```

---

## 📊 API Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/api/upload/image` | Upload image | No |
| POST | `/api/upload/video` | Upload video | No |
| POST | `/api/upload/product-image` | Upload product image | No |
| POST | `/api/upload/avatar` | Upload user avatar | Yes |
| DELETE | `/api/upload/:objectName` | Delete file | Yes |

### Example Requests

**Upload Image:**
```bash
curl -X POST http://localhost:8000/api/upload/image \
  -F "image=@photo.jpg" \
  -F "folder=products"
```

**Upload with Authentication:**
```bash
curl -X POST http://localhost:8000/api/upload/avatar \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "avatar=@profile.jpg"
```

**Delete File:**
```bash
curl -X DELETE http://localhost:8000/api/upload/products/uuid-filename.jpg \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## 🐛 Troubleshooting

### MinIO Not Starting

**Check logs:**
```bash
docker logs like2share_minio
```

**Common issues:**
- Port 9000 or 9001 already in use
- Insufficient disk space
- Invalid credentials

**Solution:**
```bash
# Stop conflicting services
docker-compose down

# Clear volumes (WARNING: deletes all data)
docker-compose down -v

# Restart
docker-compose up -d
```

### Cannot Connect to MinIO

**Check network:**
```bash
docker network inspect like2share_network
```

**Verify backend can reach MinIO:**
```bash
docker exec like2share_backend ping minio
```

**Solution:**
- Ensure both services are on same network
- Check MINIO_ENDPOINT in .env matches service name

### Files Not Uploading

**Check bucket policy:**
```bash
mc policy get local/buzzcart-media
```

**Set public read policy:**
```bash
mc policy set download local/buzzcart-media
```

**Or via MinIO Console:**
1. Go to Buckets → buzzcart-media
2. Access Policy → Custom
3. Add read-only policy

---

## 📚 Additional Resources

- **Storage Package Documentation**: `backend/internal/storage/README.md`
- **MinIO Documentation**: https://min.io/docs/minio/linux/index.html
- **MinIO Go SDK**: https://github.com/minio/minio-go
- **Docker Compose Docs**: https://docs.docker.com/compose/

---

## ✅ Checklist

- [ ] Added minio-go dependency to go.mod
- [ ] Updated .env with MinIO credentials
- [ ] Started MinIO service via docker-compose
- [ ] Accessed MinIO Console at http://localhost:9001
- [ ] Initialized storage in main.go
- [ ] Added upload routes to API
- [ ] Tested file upload endpoint
- [ ] Verified files in MinIO Console
- [ ] Migrated existing files (if any)
- [ ] Updated database URLs to MinIO URLs
- [ ] Configured production credentials (for production)
- [ ] Set up SSL/TLS (for production)
- [ ] Configured backups (for production)

---

## 🎉 Success!

If all tests pass, your BuzzCart application is now using MinIO for file storage instead of local disk storage!

**Benefits:**
✅ Scalable S3-compatible storage  
✅ Built-in redundancy and replication  
✅ Web-based management console  
✅ Compatible with AWS S3 APIs  
✅ Self-hosted and open-source  

**Next Steps:**
1. Update your application to use the new upload endpoints
2. Remove old file upload logic using `os.Create`
3. Monitor storage usage in MinIO Console
4. Set up automated backups
5. Configure CDN (optional) for better performance
