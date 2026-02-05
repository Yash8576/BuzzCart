package storage

import (
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"path/filepath"
	"time"

	"github.com/google/uuid"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// MinIOClient wraps the MinIO client with configuration
type MinIOClient struct {
	client   *minio.Client
	bucket   string
	endpoint string
	useSSL   bool
}

// MinIOConfig holds the configuration for MinIO
type MinIOConfig struct {
	Endpoint  string
	AccessKey string
	SecretKey string
	UseSSL    bool
	Bucket    string
}

// NewMinIOClient creates a new MinIO client
func NewMinIOClient(config MinIOConfig) (*MinIOClient, error) {
	// Initialize MinIO client
	minioClient, err := minio.New(config.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(config.AccessKey, config.SecretKey, ""),
		Secure: config.UseSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create minio client: %w", err)
	}

	client := &MinIOClient{
		client:   minioClient,
		bucket:   config.Bucket,
		endpoint: config.Endpoint,
		useSSL:   config.UseSSL,
	}

	// Ensure bucket exists
	if err := client.ensureBucket(); err != nil {
		return nil, err
	}

	return client, nil
}

// ensureBucket creates the bucket if it doesn't exist
func (m *MinIOClient) ensureBucket() error {
	ctx := context.Background()

	// Check if bucket exists
	exists, err := m.client.BucketExists(ctx, m.bucket)
	if err != nil {
		return fmt.Errorf("failed to check bucket existence: %w", err)
	}

	if exists {
		return nil
	}

	// Create bucket
	err = m.client.MakeBucket(ctx, m.bucket, minio.MakeBucketOptions{})
	if err != nil {
		return fmt.Errorf("failed to create bucket: %w", err)
	}

	// Set bucket policy to public read (optional - for public access to uploaded files)
	policy := fmt.Sprintf(`{
		"Version": "2012-10-17",
		"Statement": [
			{
				"Effect": "Allow",
				"Principal": {"AWS": ["*"]},
				"Action": ["s3:GetObject"],
				"Resource": ["arn:aws:s3:::%s/*"]
			}
		]
	}`, m.bucket)

	err = m.client.SetBucketPolicy(ctx, m.bucket, policy)
	if err != nil {
		return fmt.Errorf("failed to set bucket policy: %w", err)
	}

	return nil
}

// UploadFile uploads a file to MinIO and returns the public URL
func (m *MinIOClient) UploadFile(file multipart.File, header *multipart.FileHeader, folder string) (string, error) {
	ctx := context.Background()

	// Generate unique filename
	ext := filepath.Ext(header.Filename)
	filename := fmt.Sprintf("%s%s", uuid.New().String(), ext)

	// Add folder prefix if provided
	objectName := filename
	if folder != "" {
		objectName = fmt.Sprintf("%s/%s", folder, filename)
	}

	// Get file size
	fileSize := header.Size

	// Get content type
	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	// Upload file
	_, err := m.client.PutObject(ctx, m.bucket, objectName, file, fileSize, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", fmt.Errorf("failed to upload file: %w", err)
	}

	// Generate public URL
	url := m.GetPublicURL(objectName)
	return url, nil
}

// UploadFileFromReader uploads a file from an io.Reader
func (m *MinIOClient) UploadFileFromReader(reader io.Reader, filename string, size int64, contentType string, folder string) (string, error) {
	ctx := context.Background()

	// Generate unique filename
	ext := filepath.Ext(filename)
	uniqueFilename := fmt.Sprintf("%s%s", uuid.New().String(), ext)

	// Add folder prefix if provided
	objectName := uniqueFilename
	if folder != "" {
		objectName = fmt.Sprintf("%s/%s", folder, uniqueFilename)
	}

	if contentType == "" {
		contentType = "application/octet-stream"
	}

	// Upload file
	_, err := m.client.PutObject(ctx, m.bucket, objectName, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", fmt.Errorf("failed to upload file: %w", err)
	}

	// Generate public URL
	url := m.GetPublicURL(objectName)
	return url, nil
}

// GetPublicURL returns the public URL for an object
func (m *MinIOClient) GetPublicURL(objectName string) string {
	protocol := "http"
	if m.useSSL {
		protocol = "https"
	}
	return fmt.Sprintf("%s://%s/%s/%s", protocol, m.endpoint, m.bucket, objectName)
}

// GetPresignedURL generates a presigned URL for temporary access (expires in 7 days by default)
func (m *MinIOClient) GetPresignedURL(objectName string, expiry time.Duration) (string, error) {
	if expiry == 0 {
		expiry = 7 * 24 * time.Hour // Default 7 days
	}

	ctx := context.Background()
	presignedURL, err := m.client.PresignedGetObject(ctx, m.bucket, objectName, expiry, nil)
	if err != nil {
		return "", fmt.Errorf("failed to generate presigned URL: %w", err)
	}

	return presignedURL.String(), nil
}

// DeleteFile deletes a file from MinIO
func (m *MinIOClient) DeleteFile(objectName string) error {
	ctx := context.Background()

	err := m.client.RemoveObject(ctx, m.bucket, objectName, minio.RemoveObjectOptions{})
	if err != nil {
		return fmt.Errorf("failed to delete file: %w", err)
	}

	return nil
}

// ListFiles lists all files in a folder (prefix)
func (m *MinIOClient) ListFiles(folder string) ([]string, error) {
	ctx := context.Background()

	var files []string
	objectCh := m.client.ListObjects(ctx, m.bucket, minio.ListObjectsOptions{
		Prefix:    folder,
		Recursive: true,
	})

	for object := range objectCh {
		if object.Err != nil {
			return nil, fmt.Errorf("error listing objects: %w", object.Err)
		}
		files = append(files, object.Key)
	}

	return files, nil
}

// FileExists checks if a file exists in MinIO
func (m *MinIOClient) FileExists(objectName string) (bool, error) {
	ctx := context.Background()

	_, err := m.client.StatObject(ctx, m.bucket, objectName, minio.StatObjectOptions{})
	if err != nil {
		errResponse := minio.ToErrorResponse(err)
		if errResponse.Code == "NoSuchKey" {
			return false, nil
		}
		return false, fmt.Errorf("failed to check file existence: %w", err)
	}

	return true, nil
}
