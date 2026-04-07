package handlers

import (
	"buzzcart/internal/database"
	"context"
	"database/sql"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

func deletePostsByMediaID(ctx context.Context, tx *sql.Tx, mediaID string) error {
	if _, err := tx.ExecContext(ctx, "DELETE FROM user_feeds WHERE post_id IN (SELECT id FROM posts WHERE media_id = $1)", mediaID); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, "DELETE FROM post_likes WHERE post_id IN (SELECT id FROM posts WHERE media_id = $1)", mediaID); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, "DELETE FROM posts WHERE media_id = $1", mediaID); err != nil {
		return err
	}
	return nil
}

func DeleteUserMedia(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		mediaID := c.Param("media_id")
		if userID == "" || mediaID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid delete request"})
			return
		}

		ctx, cancel := database.NewContext()
		defer cancel()

		var ownerID string
		var mediaType string
		var contentID sql.NullString
		err := db.QueryRowContext(
			ctx,
			"SELECT user_id, media_type, content_id FROM user_media WHERE id = $1",
			mediaID,
		).Scan(&ownerID, &mediaType, &contentID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Media not found"})
			return
		}
		if err != nil {
			log.Printf("[DeleteUserMedia] Failed to load media %s: %v", mediaID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch media"})
			return
		}
		if ownerID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized"})
			return
		}

		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
			return
		}
		defer tx.Rollback()

		if err := deletePostsByMediaID(ctx, tx, mediaID); err != nil {
			log.Printf("[DeleteUserMedia] Failed to remove linked posts for media %s: %v", mediaID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete media"})
			return
		}

		if contentID.Valid && contentID.String != "" {
			if _, err := tx.ExecContext(
				ctx,
				"DELETE FROM content_items WHERE id = $1 AND creator_id = $2",
				contentID.String,
				userID,
			); err != nil {
				log.Printf("[DeleteUserMedia] Failed to remove linked content item %s: %v", contentID.String, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete media"})
				return
			}
		}

		result, err := tx.ExecContext(ctx, "DELETE FROM user_media WHERE id = $1 AND user_id = $2", mediaID, userID)
		if err != nil {
			log.Printf("[DeleteUserMedia] Failed to delete media %s: %v", mediaID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete media"})
			return
		}
		rowsAffected, _ := result.RowsAffected()
		if rowsAffected == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Media not found"})
			return
		}

		if err := tx.Commit(); err != nil {
			log.Printf("[DeleteUserMedia] Failed to commit delete for media %s: %v", mediaID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete media"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message":    "Media deleted",
			"media_id":   mediaID,
			"media_type": mediaType,
		})
	}
}

func DeletePost(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		postID := c.Param("post_id")
		if userID == "" || postID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid delete request"})
			return
		}

		ctx, cancel := database.NewContext()
		defer cancel()

		var ownerID string
		err := db.QueryRowContext(ctx, "SELECT user_id FROM posts WHERE id = $1", postID).Scan(&ownerID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Post not found"})
			return
		}
		if err != nil {
			log.Printf("[DeletePost] Failed to fetch post %s: %v", postID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch post"})
			return
		}
		if ownerID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized"})
			return
		}

		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
			return
		}
		defer tx.Rollback()

		if _, err := tx.ExecContext(ctx, "DELETE FROM user_feeds WHERE post_id = $1", postID); err != nil {
			log.Printf("[DeletePost] Failed to remove feed rows for post %s: %v", postID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete post"})
			return
		}
		if _, err := tx.ExecContext(ctx, "DELETE FROM post_likes WHERE post_id = $1", postID); err != nil {
			log.Printf("[DeletePost] Failed to remove likes for post %s: %v", postID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete post"})
			return
		}

		result, err := tx.ExecContext(ctx, "DELETE FROM posts WHERE id = $1 AND user_id = $2", postID, userID)
		if err != nil {
			log.Printf("[DeletePost] Failed to delete post %s: %v", postID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete post"})
			return
		}
		rowsAffected, _ := result.RowsAffected()
		if rowsAffected == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Post not found"})
			return
		}

		if err := tx.Commit(); err != nil {
			log.Printf("[DeletePost] Failed to commit delete for post %s: %v", postID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete post"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Post deleted", "post_id": postID})
	}
}

func DeleteVideo(db *sql.DB) gin.HandlerFunc {
	return deleteContentItemByType(db, "video")
}

func DeleteReel(db *sql.DB) gin.HandlerFunc {
	return deleteContentItemByType(db, "reel")
}

func deleteContentItemByType(db *sql.DB, contentType string) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		contentID := c.Param(contentType + "_id")
		if userID == "" || contentID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid delete request"})
			return
		}

		ctx, cancel := database.NewContext()
		defer cancel()

		var ownerID string
		err := db.QueryRowContext(
			ctx,
			"SELECT creator_id FROM content_items WHERE id = $1 AND content_type = $2",
			contentID,
			contentType,
		).Scan(&ownerID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Content not found"})
			return
		}
		if err != nil {
			log.Printf("[Delete%s] Failed to fetch content %s: %v", contentType, contentID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch content"})
			return
		}
		if ownerID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized"})
			return
		}

		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
			return
		}
		defer tx.Rollback()

		if _, err := tx.ExecContext(ctx, "DELETE FROM user_media WHERE content_id = $1 AND user_id = $2", contentID, userID); err != nil {
			log.Printf("[Delete%s] Failed to remove gallery media for %s: %v", contentType, contentID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete content"})
			return
		}

		result, err := tx.ExecContext(
			ctx,
			"DELETE FROM content_items WHERE id = $1 AND creator_id = $2 AND content_type = $3",
			contentID,
			userID,
			contentType,
		)
		if err != nil {
			log.Printf("[Delete%s] Failed to delete content %s: %v", contentType, contentID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete content"})
			return
		}
		rowsAffected, _ := result.RowsAffected()
		if rowsAffected == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Content not found"})
			return
		}

		if err := tx.Commit(); err != nil {
			log.Printf("[Delete%s] Failed to commit delete for %s: %v", contentType, contentID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete content"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message":    "Content deleted",
			"content_id": contentID,
			"type":       contentType,
		})
	}
}
