package storage

import (
	"buzzcart/internal/config"
	"fmt"
	"log"
)

var (
	// GlobalMinIOClient is the global MinIO client instance
	GlobalMinIOClient *MinIOClient
)

// InitializeStorage initializes the MinIO client with the given configuration
func InitializeStorage(cfg *config.Config) error {
	minioConfig := MinIOConfig{
		Endpoint:  cfg.MinIO.Endpoint,
		AccessKey: cfg.MinIO.AccessKey,
		SecretKey: cfg.MinIO.SecretKey,
		UseSSL:    cfg.MinIO.UseSSL,
		Bucket:    cfg.MinIO.Bucket,
	}

	client, err := NewMinIOClient(minioConfig)
	if err != nil {
		return fmt.Errorf("failed to initialize MinIO client: %w", err)
	}

	GlobalMinIOClient = client
	log.Printf("✓ MinIO storage initialized successfully (Bucket: %s, Endpoint: %s)", cfg.MinIO.Bucket, cfg.MinIO.Endpoint)

	return nil
}

// GetStorageClient returns the global MinIO client
// Panics if storage is not initialized
func GetStorageClient() *MinIOClient {
	if GlobalMinIOClient == nil {
		panic("storage client not initialized - call InitializeStorage first")
	}
	return GlobalMinIOClient
}
