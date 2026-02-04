package handlers

import (
	"buzzcart/internal/models"
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func CreateVideo(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.VideoCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Get user info
		var user models.User
		err := db.Collection("users").FindOne(context.Background(), bson.M{"id": userID}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		// Fetch products
		var products []models.ProductSimple
		if len(req.ProductIDs) > 0 {
			cursor, _ := db.Collection("products").Find(context.Background(), bson.M{"id": bson.M{"$in": req.ProductIDs}})
			var fullProducts []models.Product
			cursor.All(context.Background(), &fullProducts)
			for _, p := range fullProducts {
				image := ""
				if len(p.Images) > 0 {
					image = p.Images[0]
				}
				products = append(products, models.ProductSimple{
					ID:    p.ID,
					Title: p.Title,
					Price: p.Price,
					Image: image,
				})
			}
		}

		if products == nil {
			products = []models.ProductSimple{}
		}

		video := models.Video{
			ID:            uuid.New().String(),
			Title:         req.Title,
			Description:   req.Description,
			URL:           req.URL,
			Thumbnail:     req.Thumbnail,
			Duration:      req.Duration,
			Views:         0,
			Likes:         0,
			CreatorID:     userID,
			CreatorName:   user.Name,
			CreatorAvatar: user.Avatar,
			Products:      products,
			CreatedAt:     time.Now(),
		}

		_, err = db.Collection("videos").InsertOne(context.Background(), video)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create video"})
			return
		}

		c.JSON(http.StatusOK, video)
	}
}

func GetVideos(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		opts := options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetLimit(20)

		cursor, err := db.Collection("videos").Find(context.Background(), bson.M{}, opts)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch videos"})
			return
		}
		defer cursor.Close(context.Background())

		var videos []models.Video
		if err = cursor.All(context.Background(), &videos); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode videos"})
			return
		}

		if videos == nil {
			videos = []models.Video{}
		}

		c.JSON(http.StatusOK, videos)
	}
}

func GetVideo(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		videoID := c.Param("video_id")

		var video models.Video
		err := db.Collection("videos").FindOne(context.Background(), bson.M{"id": videoID}).Decode(&video)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Video not found"})
			return
		}

		// Increment views
		db.Collection("videos").UpdateOne(
			context.Background(),
			bson.M{"id": videoID},
			bson.M{"$inc": bson.M{"views": 1}},
		)

		c.JSON(http.StatusOK, video)
	}
}

func LikeVideo(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		videoID := c.Param("video_id")

		_, err := db.Collection("videos").UpdateOne(
			context.Background(),
			bson.M{"id": videoID},
			bson.M{"$inc": bson.M{"likes": 1}},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to like video"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Video liked"})
	}
}
