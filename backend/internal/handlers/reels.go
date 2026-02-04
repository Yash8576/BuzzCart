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

func CreateReel(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.ReelCreate
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

		reel := models.Reel{
			ID:            uuid.New().String(),
			URL:           req.URL,
			Thumbnail:     req.Thumbnail,
			Caption:       req.Caption,
			Views:         0,
			Likes:         0,
			CreatorID:     userID,
			CreatorName:   user.Name,
			CreatorAvatar: user.Avatar,
			Products:      products,
			CreatedAt:     time.Now(),
		}

		_, err = db.Collection("reels").InsertOne(context.Background(), reel)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create reel"})
			return
		}

		c.JSON(http.StatusOK, reel)
	}
}

func GetReels(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		opts := options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetLimit(20)

		cursor, err := db.Collection("reels").Find(context.Background(), bson.M{}, opts)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch reels"})
			return
		}
		defer cursor.Close(context.Background())

		var reels []models.Reel
		if err = cursor.All(context.Background(), &reels); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode reels"})
			return
		}

		if reels == nil {
			reels = []models.Reel{}
		}

		c.JSON(http.StatusOK, reels)
	}
}

func GetReel(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		reelID := c.Param("reel_id")

		var reel models.Reel
		err := db.Collection("reels").FindOne(context.Background(), bson.M{"id": reelID}).Decode(&reel)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Reel not found"})
			return
		}

		// Increment views
		db.Collection("reels").UpdateOne(
			context.Background(),
			bson.M{"id": reelID},
			bson.M{"$inc": bson.M{"views": 1}},
		)

		c.JSON(http.StatusOK, reel)
	}
}

func LikeReel(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		reelID := c.Param("reel_id")

		_, err := db.Collection("reels").UpdateOne(
			context.Background(),
			bson.M{"id": reelID},
			bson.M{"$inc": bson.M{"likes": 1}},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to like reel"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Reel liked"})
	}
}
