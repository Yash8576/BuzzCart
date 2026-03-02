# Like2Share Backend - Quick Start Guide

## 🚀 Running the Production-Ready Backend

### Prerequisites
- Go 1.21+
- PostgreSQL database running
- MinIO storage running
- Redis (optional, for caching)

### Environment Setup

Create a `.env` file in the `backend/` directory:

```env
# Database
DATABASE_URL=postgresql://username:password@localhost:5432/like2share_db?sslmode=disable

# JWT
JWT_SECRET=your-super-secret-jwt-key-min-32-chars

# MinIO Storage
MINIO_ENDPOINT=localhost:9000
MINIO_PUBLIC_ENDPOINT=http://localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_USE_SSL=false
MINIO_BUCKET=like2share

# Redis (optional)
REDIS_URL=redis://localhost:6379

# Server
PORT=8080
GIN_MODE=debug  # Use 'release' for production
```

### Build and Run

1. **Build the server**:
   ```bash
   go build -o bin/server.exe ./cmd/server
   ```

2. **Run the server**:
   ```bash
   ./bin/server.exe
   ```

   Or directly:
   ```bash
   go run ./cmd/server
   ```

### Verify Server is Running

1. **Health Check**:
   ```bash
   curl http://localhost:8080/health
   ```

   Expected response:
   ```json
   {
     "status": "healthy",
     "timestamp": "2026-02-23T...",
     "services": {
       "database": "ok",
       "storage": "ok",
       "cache": "ok"
     }
   }
   ```

2. **Check Logs**:
   Look for these startup messages:
   ```
   ✓ Successfully connected to PostgreSQL
   Successfully connected to Redis
   ✓ MinIO storage initialized successfully (Bucket: like2share, Endpoint: localhost:9000)
   ```

### API Endpoints

#### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login
- `GET /api/auth/me` - Get current user (requires auth)

#### File Uploads
- `POST /api/upload/image` - Upload image (max 10MB)
- `POST /api/upload/video` - Upload video (max 100MB)
- `POST /api/upload/avatar` - Upload avatar (max 5MB)
- `POST /api/upload/product-image` - Upload product image
- `DELETE /api/upload/:objectName` - Delete file

#### Products
- `GET /api/products` - List products
- `POST /api/products` - Create product (requires auth)
- `GET /api/products/:id` - Get product details
- `PUT /api/products/:id` - Update product (requires auth)
- `DELETE /api/products/:id` - Delete product (requires auth)

### File Upload Example

```bash
# Upload avatar (requires authentication)
curl -X POST http://localhost:8080/api/upload/avatar \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "avatar=@/path/to/image.jpg"

# Response
{
  "success": true,
  "avatar_url": "http://localhost:9000/like2share/avatars/uuid.jpg",
  "message": "Avatar updated successfully"
}
```

### Validation Rules

#### Images (JPG, PNG, GIF, WebP, HEIC)
- Max size: 10MB (5MB for avatars)
- Allowed formats: JPEG, JPG, PNG, GIF, WebP, HEIC, HEIF
- Validated by both MIME type and file extension

#### Videos (MP4, MOV, AVI, WebM)
- Max size: 100MB
- Allowed formats: MP4, MPEG, MOV, AVI, WebM
- Validated by both MIME type and file extension

### Error Responses

#### Validation Error (400)
```json
{
  "error": "image size exceeds maximum allowed size of 10 MB"
}
```

#### Authentication Error (401)
```json
{
  "error": "User not authenticated"
}
```

#### Internal Error (500)
```json
{
  "error": "Internal server error occurred",
  "time": "2026-02-23T12:00:00Z"
}
```

### Monitoring

#### Logs Format
```
[POST] /api/upload/avatar 2026-02-23T12:00:00Z | Status: 200 | Latency: 45ms | IP: 127.0.0.1 | User: uuid | UA: curl/7.68.0 | Query: 
```

#### Health Check
Monitor the `/health` endpoint with your load balancer or monitoring tool:
- Returns 200 when healthy
- Returns 503 when critical services are down
- Returns 200 with "degraded" status when cache is unavailable

### Troubleshooting

#### Server won't start
1. Check if database is running:
   ```bash
   psql $DATABASE_URL -c "SELECT 1"
   ```

2. Check if MinIO is running:
   ```bash
   curl http://localhost:9000/minio/health/live
   ```

3. Check logs for specific error messages

#### File upload fails
1. Check file size limits:
   - Images: 10MB
   - Videos: 100MB
   - Avatars: 5MB

2. Check file format is supported

3. Check MinIO is accessible:
   ```bash
   curl http://localhost:9000/minio/health/live
   ```

#### Database timeout errors
- Check database connection pool settings
- Verify database isn't overloaded
- Check network latency to database

### Production Deployment

#### Recommended Settings

1. **Environment Variables**:
   ```env
   GIN_MODE=release
   DATABASE_URL=postgresql://user:pass@db-host:5432/like2share_db?sslmode=require
   MINIO_USE_SSL=true
   MINIO_ENDPOINT=storage.yourdomain.com:443
   ```

2. **System Resources**:
   - CPU: 2+ cores
   - RAM: 4GB+ recommended
   - Storage: Depends on media upload volume

3. **Security**:
   - Enable SSL/TLS for database connection
   - Use HTTPS for MinIO
   - Keep JWT_SECRET secure (32+ characters)
   - Run behind reverse proxy (nginx/Caddy)
   - Enable rate limiting (implement Redis-based limiter)

4. **Monitoring**:
   - Monitor `/health` endpoint
   - Set up log aggregation (ELK, Datadog, etc.)
   - Configure alerts for 503 responses

### Performance Tuning

#### Database Connection Pool
```go
db.SetMaxOpenConns(25)               // Adjust based on load
db.SetMaxIdleConns(5)                // Keep low for resource efficiency
db.SetConnMaxLifetime(5 * time.Minute)
db.SetConnMaxIdleTime(1 * time.Minute)
```

#### Timeout Configuration
- Default query timeout: 10 seconds
- Long query timeout: 30 seconds
- Modify in `internal/database/database.go` if needed

### Testing

```bash
# Run all tests
go test ./... -v

# Run specific package tests
go test ./internal/utils -v
go test ./internal/handlers -v

# Run with coverage
go test ./... -cover

# Run with race detector
go test ./... -race
```

### Additional Resources

- [Production Improvements Documentation](./PRODUCTION_IMPROVEMENTS.md)
- [Implementation Summary](./IMPLEMENTATION_SUMMARY.md)
- [API Documentation](./README.md)

---

**Last Updated**: February 23, 2026  
**Version**: 1.0.0 (Production-Ready)
