package handlers

import (
	"buzzcart/internal/database"
	"buzzcart/internal/storage"
	"buzzcart/internal/utils"
	"database/sql"
	"fmt"
	"log"
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
			c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
			return
		}
		defer file.Close()

		// Validate image
		if err := utils.ValidateImage(header); err != nil {
			log.Printf("[UploadImage] Validation failed for user %s: %v", userID, err)
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		folder := c.DefaultQuery("folder", "images")
		storageClient := storage.GetStorageClient()
		url, err := storageClient.UploadFile(file, header, folder)
		if err != nil {
			log.Printf("[UploadImage] Storage upload failed for user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload file"})
			return
		}

		// Create context with timeout
		ctx, cancel := database.NewContext()
		defer cancel()

		var privacyMode string
		err = db.QueryRowContext(ctx, "SELECT privacy_mode FROM user_profiles WHERE user_id = $1", userID).Scan(&privacyMode)
		if err != nil {
			privacyMode = "public"
		}

		contentID := uuid.New().String()
		_, err = db.ExecContext(ctx,
			`INSERT INTO content_items (id, creator_id, content_type, video_url, is_published, created_at, published_at)
			 VALUES ($1, $2, 'photo', $3, TRUE, $4, $5)`,
			contentID, userID, url, time.Now(), time.Now(),
		)
		if err != nil {
			log.Printf("[UploadImage] Database insert failed for user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save to database"})
			return
		}

		var followerCount int
		if privacyMode == "public" {
			db.QueryRowContext(ctx, "SELECT COUNT(*) FROM user_follows WHERE following_id = $1", userID).Scan(&followerCount)
		}

		log.Printf("[UploadImage] Image uploaded successfully for user %s: %s", userID, contentID)
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
			c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
			return
		}
		defer file.Close()

		// Validate image
		if err := utils.ValidateImage(header); err != nil {
			log.Printf("[UploadUserPhoto] Validation failed for user %s: %v", userID, err)
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Get caption and create_post flag from form data
		caption := c.PostForm("caption")
		createPost := c.DefaultPostForm("create_post", "false") == "true"
		visibility := c.DefaultPostForm("visibility", "followers") // followers, public, close_friends

		// Upload to MinIO
		storageClient := storage.GetStorageClient()
		url, err := storageClient.UploadFile(file, header, "user-photos")
		if err != nil {
			log.Printf("[UploadUserPhoto] Storage upload failed for user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload file"})
			return
		}

		// Create context with timeout
		ctx, cancel := database.NewContext()
		defer cancel()

		// Save to user_media table
		mediaID := uuid.New().String()
		_, err = db.ExecContext(ctx,
			`INSERT INTO user_media (id, user_id, media_type, media_url, caption) 
			 VALUES ($1, $2, 'photo', $3, $4)`,
			mediaID, userID, url, caption,
		)
		if err != nil {
			log.Printf("[UploadUserPhoto] Database insert failed for user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save photo to database"})
			return
		}

		// Optionally create a post and fan out to followers
		var postID *string
		var followerCount int
		if createPost {
			// Get user's privacy profile
			var privacyProfile string
			err := db.QueryRowContext(ctx, "SELECT privacy_profile FROM users WHERE id = $1", userID).Scan(&privacyProfile)
			if err == nil {
				isPrivate := privacyProfile == "private"
				pID := uuid.New().String()
				postID = &pID

				// Create post
				_, err = db.ExecContext(ctx,
					`INSERT INTO posts (id, user_id, media_id, caption, media_type, media_url, is_private, visibility, created_at)
					 VALUES ($1, $2, $3, $4, 'photo', $5, $6, $7, $8)`,
					*postID, userID, mediaID, caption, url, isPrivate, visibility, time.Now(),
				)
				if err == nil {
					// Fan out to followers
					db.QueryRowContext(ctx, "SELECT fanout_post_to_followers($1, $2)", *postID, userID).Scan(&followerCount)
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
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
		return
	}
	defer file.Close()

	// Validate video
	if err := utils.ValidateVideo(header); err != nil {
		log.Printf("[UploadVideo] Validation failed: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get folder from query param (optional)
	folder := c.DefaultQuery("folder", "videos")

	// Upload to MinIO
	storageClient := storage.GetStorageClient()
	url, err := storageClient.UploadFile(file, header, folder)
	if err != nil {
		log.Printf("[UploadVideo] Storage upload failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload video"})
		return
	}

	log.Printf("[UploadVideo] Video uploaded successfully: %s", url)
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
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
		return
	}
	defer file.Close()

	// Validate image
	if err := utils.ValidateImage(header); err != nil {
		log.Printf("[UploadProductImage] Validation failed: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Upload to MinIO in products folder
	storageClient := storage.GetStorageClient()
	url, err := storageClient.UploadFile(file, header, "products")
	if err != nil {
		log.Printf("[UploadProductImage] Storage upload failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload product image"})
		return
	}

	log.Printf("[UploadProductImage] Product image uploaded successfully: %s", url)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"url":     url,
		"message": "Product image uploaded successfully",
	})
}

// UploadAvatarHandler handles user avatar uploads
// Example endpoint: POST /api/upload/avatar
func UploadAvatarHandler(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get the file from the form
		file, header, err := c.Request.FormFile("avatar")
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
			return
		}
		defer file.Close()

		// Get user ID from context (set by auth middleware)
		userID := c.GetString("user_id")
		if userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}

		// Validate avatar
		if err := utils.ValidateAvatar(header); err != nil {
			log.Printf("[UploadAvatar] Validation failed for user %s: %v", userID, err)
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Upload to MinIO in avatars folder
		storageClient := storage.GetStorageClient()
		url, err := storageClient.UploadFile(file, header, "avatars")
		if err != nil {
			log.Printf("[UploadAvatar] Storage upload failed for user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload avatar"})
			return
		}

		// Create context with timeout
		ctx, cancel := database.NewContext()
		defer cancel()

		// Update user avatar URL in database
		_, err = db.ExecContext(ctx, "UPDATE users SET avatar = $1, updated_at = $2 WHERE id = $3", url, time.Now(), userID)
		if err != nil {
			// Try to delete the uploaded file on database error
			_ = storageClient.DeleteFile(url)
			log.Printf("[UploadAvatar] Database update failed for user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update user profile"})
			return
		}

		log.Printf("[UploadAvatar] Avatar updated successfully for user %s", userID)
		c.JSON(http.StatusOK, gin.H{
			"success":    true,
			"avatar_url": url,
			"message":    "Avatar updated successfully",
		})
	}
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

		// Create context with timeout
		ctx, cancel := database.NewContext()
		defer cancel()
		// Query from user_media table
		query := `
			SELECT um.id, um.media_type, um.media_url, um.thumbnail_url, um.caption, 
			       COALESCE(um.view_count, 0), COALESCE(um.like_count, 0), COALESCE(um.comment_count, 0), um.created_at
			FROM user_media um
			WHERE um.user_id = $1
		`

		args := []interface{}{userID}

		// Privacy check: if requesting user is different, check if profile is private
		if requestingUserID != userID && requestingUserID != "" {
			query += ` AND (
				NOT EXISTS (SELECT 1 FROM users WHERE id = um.user_id AND privacy_profile = 'PRIVATE')
				OR EXISTS (SELECT 1 FROM user_follows WHERE follower_id = $2 AND following_id = $1)
			)`
			args = append(args, requestingUserID)
		}

		argIndex := len(args) + 1
		if mediaType != "" {
			query += fmt.Sprintf(" AND um.media_type = $%d", argIndex)
			args = append(args, mediaType)
			argIndex++
		}

		query += " ORDER BY um.created_at DESC LIMIT $" + fmt.Sprint(argIndex)
		args = append(args, limit)

		rows, err := db.QueryContext(ctx, query, args...)
		if err != nil {
			log.Printf("[GetUserMedia] Database query failed for user %s: %v", userID, err)
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

		log.Printf("[GetUserMedia] Retrieved %d media items for user %s", len(media), userID)
		c.JSON(http.StatusOK, media)
	}
}
