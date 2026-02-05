package handlers

import (
	"buzzcart/internal/storage"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
)

// UploadImageHandler handles image uploads to MinIO
// Example endpoint: POST /api/upload/image
func UploadImageHandler(c *gin.Context) {
	// Get the file from the form
	file, header, err := c.Request.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "No file uploaded",
		})
		return
	}
	defer file.Close()

	// Get folder from query param (optional)
	folder := c.DefaultQuery("folder", "images")

	// Upload to MinIO
	storageClient := storage.GetStorageClient()
	url, err := storageClient.UploadFile(file, header, folder)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("Failed to upload file: %v", err),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"url":     url,
		"message": "File uploaded successfully",
	})
}

// UploadVideoHandler handles video uploads to MinIO
// Example endpoint: POST /api/upload/video
func UploadVideoHandler(c *gin.Context) {
	// Get the file from the form
	file, header, err := c.Request.FormFile("video")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "No file uploaded",
		})
		return
	}
	defer file.Close()

	// Get folder from query param (optional)
	folder := c.DefaultQuery("folder", "videos")

	// Upload to MinIO
	storageClient := storage.GetStorageClient()
	url, err := storageClient.UploadFile(file, header, folder)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("Failed to upload file: %v", err),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"url":     url,
		"message": "Video uploaded successfully",
	})
}

// UploadProductImageHandler handles product image uploads
// Example endpoint: POST /api/upload/product-image
func UploadProductImageHandler(c *gin.Context) {
	// Get the file from the form
	file, header, err := c.Request.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "No file uploaded",
		})
		return
	}
	defer file.Close()

	// Upload to MinIO in products folder
	storageClient := storage.GetStorageClient()
	url, err := storageClient.UploadFile(file, header, "products")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("Failed to upload file: %v", err),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"url":     url,
		"message": "Product image uploaded successfully",
	})
}

// UploadAvatarHandler handles user avatar uploads
// Example endpoint: POST /api/upload/avatar
func UploadAvatarHandler(c *gin.Context) {
	// Get the file from the form
	file, header, err := c.Request.FormFile("avatar")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "No file uploaded",
		})
		return
	}
	defer file.Close()

	// Get user ID from context (set by auth middleware)
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Upload to MinIO in avatars folder
	storageClient := storage.GetStorageClient()
	url, err := storageClient.UploadFile(file, header, "avatars")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("Failed to upload file: %v", err),
		})
		return
	}

	// TODO: Update user avatar URL in database
	_ = userID // Use this to update the database

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"url":     url,
		"message": "Avatar uploaded successfully",
	})
}

// DeleteFileHandler handles file deletion from MinIO
// Example endpoint: DELETE /api/upload/:objectName
func DeleteFileHandler(c *gin.Context) {
	objectName := c.Param("objectName")
	if objectName == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Object name is required",
		})
		return
	}

	storageClient := storage.GetStorageClient()
	err := storageClient.DeleteFile(objectName)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("Failed to delete file: %v", err),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "File deleted successfully",
	})
}
