# MinIO Storage Integration for BuzzCart

This package provides MinIO (S3-compatible) storage integration for the BuzzCart application, replacing local file storage.

## Features

- ✅ File upload with automatic unique filename generation
- ✅ Folder organization (images, videos, products, avatars, etc.)
- ✅ Public URL generation for uploaded files
- ✅ Presigned URL generation for temporary access
- ✅ File deletion
- ✅ File existence checking
- ✅ List files in a folder
- ✅ Automatic bucket creation with public read policy

## Configuration

### Environment Variables

Add the following to your `.env` file:

```env
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin123
MINIO_USE_SSL=false
MINIO_BUCKET=buzzcart-media
```

### Docker Compose

MinIO service is configured in `docker-compose.yml`:

```yaml
minio:
  image: minio/minio:latest
  ports:
    - "9000:9000"  # API
    - "9001:9001"  # Console
  environment:
    MINIO_ROOT_USER: minioadmin
    MINIO_ROOT_PASSWORD: minioadmin123
```

**Access MinIO Console**: http://localhost:9001
- Username: `minioadmin`
- Password: `minioadmin123`

## Usage

### 1. Initialize Storage in main.go

```go
package main

import (
    "buzzcart/internal/config"
    "buzzcart/internal/storage"
    "log"
)

func main() {
    // Load configuration
    cfg := config.Load()
    
    // Initialize MinIO storage
    if err := storage.InitializeStorage(cfg); err != nil {
        log.Fatalf("Failed to initialize storage: %v", err)
    }
    
    // ... rest of your application
}
```

### 2. Upload Files in Handlers

```go
package handlers

import (
    "buzzcart/internal/storage"
    "github.com/gin-gonic/gin"
    "net/http"
)

func UploadProductImage(c *gin.Context) {
    // Get file from request
    file, header, err := c.Request.FormFile("image")
    if err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
        return
    }
    defer file.Close()

    // Get storage client
    storageClient := storage.GetStorageClient()
    
    // Upload file to "products" folder
    url, err := storageClient.UploadFile(file, header, "products")
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "url": url,
        "message": "File uploaded successfully",
    })
}
```

### 3. Example API Routes

Add these routes to your router:

```go
// Upload routes
api.POST("/upload/image", handlers.UploadImageHandler)
api.POST("/upload/video", handlers.UploadVideoHandler)
api.POST("/upload/product-image", handlers.UploadProductImageHandler)
api.POST("/upload/avatar", middleware.AuthMiddleware(), handlers.UploadAvatarHandler)

// Delete route
api.DELETE("/upload/:objectName", middleware.AuthMiddleware(), handlers.DeleteFileHandler)
```

## API Examples

### Upload Image

```bash
curl -X POST http://localhost:8000/api/upload/image \
  -F "image=@/path/to/image.jpg" \
  -F "folder=products"
```

**Response:**
```json
{
  "success": true,
  "url": "http://localhost:9000/buzzcart-media/products/a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg",
  "message": "File uploaded successfully"
}
```

### Upload Video

```bash
curl -X POST http://localhost:8000/api/upload/video \
  -F "video=@/path/to/video.mp4" \
  -F "folder=videos"
```

### Upload Avatar (Authenticated)

```bash
curl -X POST http://localhost:8000/api/upload/avatar \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "avatar=@/path/to/avatar.jpg"
```

### Delete File (Authenticated)

```bash
curl -X DELETE http://localhost:8000/api/upload/products/a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Storage Client Methods

### UploadFile
Uploads a multipart file to MinIO.

```go
url, err := storageClient.UploadFile(file, header, "folder-name")
```

**Parameters:**
- `file`: multipart.File
- `header`: *multipart.FileHeader
- `folder`: string (e.g., "images", "videos", "products")

**Returns:** Public URL of the uploaded file

### UploadFileFromReader
Uploads a file from an io.Reader.

```go
url, err := storageClient.UploadFileFromReader(
    reader, 
    "original-filename.jpg", 
    fileSize, 
    "image/jpeg", 
    "folder-name",
)
```

### GetPublicURL
Gets the public URL for an object.

```go
url := storageClient.GetPublicURL("folder/filename.jpg")
// Returns: http://localhost:9000/buzzcart-media/folder/filename.jpg
```

### GetPresignedURL
Generates a presigned URL for temporary access (expires in 7 days by default).

```go
url, err := storageClient.GetPresignedURL("folder/filename.jpg", 24 * time.Hour)
```

### DeleteFile
Deletes a file from MinIO.

```go
err := storageClient.DeleteFile("folder/filename.jpg")
```

### ListFiles
Lists all files in a folder.

```go
files, err := storageClient.ListFiles("products")
// Returns: ["products/file1.jpg", "products/file2.jpg", ...]
```

### FileExists
Checks if a file exists.

```go
exists, err := storageClient.FileExists("folder/filename.jpg")
```

## Folder Structure

Recommended folder organization:

```
buzzcart-media/
├── avatars/          # User profile pictures
├── products/         # Product images
├── videos/           # Product video content
├── reels/            # Short-form video content
├── thumbnails/       # Video thumbnails
└── documents/        # Other documents
```

## Migration from Local Storage

To migrate existing files from local storage to MinIO:

1. **Access MinIO Console**: http://localhost:9001
2. **Upload existing files** manually or use the MinIO CLI (`mc`)
3. **Update database** to point to new MinIO URLs

### Using MinIO CLI (mc)

```bash
# Install MinIO Client
# Windows: Download mc.exe from https://min.io/download

# Configure alias
mc alias set local http://localhost:9000 minioadmin minioadmin123

# Upload directory
mc cp --recursive ./storage/media/ local/buzzcart-media/

# List files
mc ls local/buzzcart-media/
```

## Security Considerations

### Production Settings

For production, update the following:

1. **Change default credentials:**
   ```env
   MINIO_ACCESS_KEY=your-secure-access-key
   MINIO_SECRET_KEY=your-secure-secret-key-min-32-chars
   ```

2. **Enable SSL:**
   ```env
   MINIO_USE_SSL=true
   MINIO_ENDPOINT=minio.yourdomain.com:9000
   ```

3. **Restrict bucket policy** (if files should not be public):
   - Remove the public read policy from `ensureBucket()` method
   - Use presigned URLs for temporary access

4. **Add file validation:**
   - Check file types (MIME type validation)
   - Limit file sizes
   - Scan for malware (if applicable)

### Example File Validation

```go
// In your handler
func ValidateImage(header *multipart.FileHeader) error {
    // Check file size (max 10MB)
    if header.Size > 10 * 1024 * 1024 {
        return fmt.Errorf("file too large")
    }
    
    // Check MIME type
    contentType := header.Header.Get("Content-Type")
    allowedTypes := []string{"image/jpeg", "image/png", "image/webp"}
    
    for _, allowed := range allowedTypes {
        if contentType == allowed {
            return nil
        }
    }
    
    return fmt.Errorf("invalid file type")
}
```

## Troubleshooting

### Connection Errors

If you see connection errors:

1. **Check MinIO is running:**
   ```bash
   docker ps | grep minio
   ```

2. **Check MinIO logs:**
   ```bash
   docker logs like2share_minio
   ```

3. **Verify endpoint** in `.env` matches docker service name or localhost

### Bucket Not Created

If the bucket is not created automatically:

1. **Check MinIO logs** for errors
2. **Manually create bucket** via MinIO Console
3. **Set bucket policy** to public (if needed):
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {"AWS": ["*"]},
         "Action": ["s3:GetObject"],
         "Resource": ["arn:aws:s3:::buzzcart-media/*"]
       }
     ]
   }
   ```

### File Upload Fails

1. **Check file permissions** on MinIO container
2. **Verify MinIO credentials** in `.env`
3. **Check network connectivity** between backend and MinIO

## Dependencies

Add to `go.mod`:

```bash
go get github.com/minio/minio-go/v7
```

## Testing

```bash
# Start services
docker-compose up -d

# Test MinIO is accessible
curl http://localhost:9000/minio/health/live

# Test upload endpoint
curl -X POST http://localhost:8000/api/upload/image \
  -F "image=@test-image.jpg"
```

## Resources

- [MinIO Documentation](https://min.io/docs/minio/linux/index.html)
- [MinIO Go SDK](https://github.com/minio/minio-go)
- [MinIO Console](http://localhost:9001)
- [S3 API Compatibility](https://docs.min.io/docs/minio-client-complete-guide.html)
