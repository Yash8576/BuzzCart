package handlers

import (
	"buzzcart/internal/models"
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

func FollowUser(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		targetUserID := c.Param("user_id")

		if userID == targetUserID {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot follow yourself"})
			return
		}

		// Check if already following
		var existing models.Follow
		err := db.Collection("follows").FindOne(
			context.Background(),
			bson.M{"follower_id": userID, "following_id": targetUserID},
		).Decode(&existing)

		if err == nil {
			c.JSON(http.StatusOK, gin.H{"message": "Already following"})
			return
		}

		// Create follow relationship
		follow := models.Follow{
			FollowerID:  userID,
			FollowingID: targetUserID,
			CreatedAt:   time.Now(),
		}

		_, err = db.Collection("follows").InsertOne(context.Background(), follow)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to follow user"})
			return
		}

		// Update counts
		db.Collection("users").UpdateOne(
			context.Background(),
			bson.M{"id": userID},
			bson.M{"$inc": bson.M{"following_count": 1}},
		)
		db.Collection("users").UpdateOne(
			context.Background(),
			bson.M{"id": targetUserID},
			bson.M{"$inc": bson.M{"followers_count": 1}},
		)

		c.JSON(http.StatusOK, gin.H{"message": "User followed"})
	}
}

func UnfollowUser(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		targetUserID := c.Param("user_id")

		result, err := db.Collection("follows").DeleteOne(
			context.Background(),
			bson.M{"follower_id": userID, "following_id": targetUserID},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unfollow user"})
			return
		}

		if result.DeletedCount > 0 {
			// Update counts
			db.Collection("users").UpdateOne(
				context.Background(),
				bson.M{"id": userID},
				bson.M{"$inc": bson.M{"following_count": -1}},
			)
			db.Collection("users").UpdateOne(
				context.Background(),
				bson.M{"id": targetUserID},
				bson.M{"$inc": bson.M{"followers_count": -1}},
			)
		}

		c.JSON(http.StatusOK, gin.H{"message": "User unfollowed"})
	}
}
