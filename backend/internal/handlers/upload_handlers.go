package handlers

import (
	"buzzcart/internal/storage"
	"database/sql"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func UploadImageHandler(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		if userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}

		file, header, err := c.Request.FormFile("image")
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "No file uploaded",
			})
			return
		}
		defer file.Close()

		folder := c.DefaultQuery("folder", "images")
		storageClient := storage.GetStorageClient()
		url, err := storageClient.UploadFile(file, header, folder)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": fmt.Sprintf("Failed to upload file: %v", err),
			})
			return
		}

		var privacyMode string
		err = db.QueryRow("SELECT privacy_mode FROM user_profiles WHERE user_id = $1", userID).Scan(&privacyMode)
		if err != nil {
			privacyMode = "public"
		}

		contentID := uuid.New().String()
		_, err = db.Exec(
			`INSERT INTO content_items (id, creator_id, content_type, video_url, is_published, created_at, published_at)
			 VALUES ($1, $2, 'photo', $3, TRUE, $4, $5)`,
			contentID, userID, url, time.Now(), time.Now(),
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": fmt.Sprintf("Failed to save to database: %v", err),
			})
			return
		}

		var followerCount int
		if privacyMode == "public" {
			db.QueryRow("SELECT COUNT(*) FROM user_follows WHERE following_id = $1", userID).Scan(&followerCount)
		}

		c.JSON(http.StatusOK, gin.H{
			"success":        true,
			"url":            url,
			"content_id":     contentID,
			"message":        "File uploaded successfully",
			"follower_count": followerCount,
		})
	}
}

// UploadUserPhotoHandler handles user photo uploads with database persistence
// Example endpoint: POST /api/upload/user-photo
func UploadUserPhotoHandler(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		if userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}

		// Get the file from the form
		file, header, err := c.Request.FormFile("image")
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "No file uploaded",
			})
			return
		}
		defer file.Close()

		// Get caption and create_post flag from form data
		caption := c.PostForm("caption")
		createPost := c.DefaultPostForm("create_post", "false") == "true"
		visibility := c.DefaultPostForm("visibility", "followers") // followers, public, close_friends

		// Upload to MinIO
		storageClient := storage.GetStorageClient()
		url, err := storageClient.UploadFile(file, header, "user-photos")
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": fmt.Sprintf("Failed to upload file: %v", err),
			})
			return
		}

		// Save to user_media table
		mediaID := uuid.New().String()
		_, err = db.Exec(
			`INSERT INTO user_media (id, user_id, media_type, media_url, caption) 
			 VALUES ($1, $2, 'photo', $3, $4)`,
			mediaID, userID, url, caption,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": fmt.Sprintf("Failed to save photo to database: %v", err),
			})
			return
		}

		// Optionally create a post and fan out to followers
		var postID *string
		var followerCount int
		if createPost {
			// Get user's privacy profile
			var privacyProfile string
			err := db.QueryRow("SELECT privacy_profile FROM users WHERE id = $1", userID).Scan(&privacyProfile)
			if err == nil {
				isPrivate := privacyProfile == "private"
				pID := uuid.New().String()
				postID = &pID

				// Create post
				_, err = db.Exec(
					`INSERT INTO posts (id, user_id, media_id, caption, media_type, media_url, is_private, visibility, created_at)
					 VALUES ($1, $2, $3, $4, 'photo', $5, $6, $7, $8)`,
					*postID, userID, mediaID, caption, url, isPrivate, visibility, time.Now(),
				)
				if err == nil {
					// Fan out to followers
					db.QueryRow("SELECT fanout_post_to_followers($1, $2)", *postID, userID).Scan(&followerCount)
				}
			}
		}

		response := gin.H{
			"success":  true,
			"url":      url,
			"media_id": mediaID,
			"message":  "Photo uploaded successfully",
		}

		if postID != nil {
			response["post_id"] = *postID
			response["follower_count"] = followerCount
			response["post_created"] = true
		}

		c.JSON(http.StatusOK, response)
	}
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

// GetUserMedia retrieves all media for a user's profile gallery
// Example endpoint: GET /api/users/:user_id/media
func GetUserMedia(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("user_id")
		if userID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
			return
		}

		requestingUserID := c.GetString("user_id")
		mediaType := c.Query("type")
		limit := c.DefaultQuery("limit", "50")

		query := `
			SELECT ci.id, ci.content_type, ci.video_url, ci.thumbnail_url, ci.title, 
			       ci.view_count, ci.like_count, ci.comment_count, ci.created_at
			FROM content_items ci
			WHERE ci.creator_id = $1 AND ci.is_published = TRUE
		`

		args := []interface{}{userID}

		if requestingUserID != userID {
			query += ` AND (
				NOT EXISTS (SELECT 1 FROM user_profiles WHERE user_id = ci.creator_id AND privacy_mode = 'private')
				OR EXISTS (SELECT 1 FROM user_follows WHERE follower_id = $2 AND following_id = $1)
			)`
			args = append(args, requestingUserID)
		}

		argIndex := len(args) + 1
		if mediaType != "" {
			query += fmt.Sprintf(" AND ci.content_type = $%d", argIndex)
			args = append(args, mediaType)
			argIndex++
		}

		query += fmt.Sprintf(" ORDER BY ci.created_at DESC LIMIT $%d", argIndex)
		args = append(args, limit)

		rows, err := db.Query(query, args...)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch media"})
			return
		}
		defer rows.Close()

		type MediaItem struct {
			ID           string  `json:"id"`
			MediaType    string  `json:"media_type"`
			MediaURL     string  `json:"media_url"`
			ThumbnailURL *string `json:"thumbnail_url"`
			Caption      *string `json:"caption"`
			ViewCount    int     `json:"view_count"`
			LikeCount    int     `json:"like_count"`
			CommentCount int     `json:"comment_count"`
			CreatedAt    string  `json:"created_at"`
		}

		var media []MediaItem
		for rows.Next() {
			var item MediaItem
			var createdAt time.Time
			err := rows.Scan(
				&item.ID, &item.MediaType, &item.MediaURL, &item.ThumbnailURL,
				&item.Caption, &item.ViewCount, &item.LikeCount, &item.CommentCount,
				&createdAt,
			)
			if err != nil {
				continue
			}
			item.CreatedAt = createdAt.Format(time.RFC3339)
			media = append(media, item)
		}

		if media == nil {
			media = []MediaItem{}
		}

		c.JSON(http.StatusOK, media)
	}
}
