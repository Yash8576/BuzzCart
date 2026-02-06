package handlers

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

func FollowUser(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		targetUserID := c.Param("user_id")

		if userID == targetUserID {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot follow yourself"})
			return
		}

		// Check if already following
		var count int
		err := db.QueryRow(
			"SELECT COUNT(*) FROM user_follows WHERE follower_id = $1 AND following_id = $2",
			userID, targetUserID,
		).Scan(&count)

		if err == nil && count > 0 {
			c.JSON(http.StatusOK, gin.H{"message": "Already following"})
			return
		}

		// Create follow relationship
		_, err = db.Exec(
			"INSERT INTO user_follows (follower_id, following_id, created_at) VALUES ($1, $2, $3)",
			userID, targetUserID, time.Now(),
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to follow user"})
			return
		}

		// Update counts
		db.Exec("UPDATE users SET following_count = following_count + 1 WHERE id = $1", userID)
		db.Exec("UPDATE users SET followers_count = followers_count + 1 WHERE id = $1", targetUserID)

		c.JSON(http.StatusOK, gin.H{"message": "User followed"})
	}
}

func UnfollowUser(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		targetUserID := c.Param("user_id")

		result, err := db.Exec(
			"DELETE FROM user_follows WHERE follower_id = $1 AND following_id = $2",
			userID, targetUserID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unfollow user"})
			return
		}

		rowsAffected, _ := result.RowsAffected()
		if rowsAffected > 0 {
			// Update counts
			db.Exec("UPDATE users SET following_count = following_count - 1 WHERE id = $1", userID)
			db.Exec("UPDATE users SET followers_count = followers_count - 1 WHERE id = $1", targetUserID)
		}

		c.JSON(http.StatusOK, gin.H{"message": "User unfollowed"})
	}
}
