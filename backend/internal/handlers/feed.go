package handlers

import (
	"buzzcart/internal/models"
	"context"
	"net/http"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func GetFeed(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		opts := options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetLimit(20)

		// Get videos
		videoCursor, _ := db.Collection("videos").Find(context.Background(), bson.M{}, opts)
		var videos []models.Video
		videoCursor.All(context.Background(), &videos)

		// Get reels
		reelCursor, _ := db.Collection("reels").Find(context.Background(), bson.M{}, opts)
		var reels []models.Reel
		reelCursor.All(context.Background(), &reels)

		if videos == nil {
			videos = []models.Video{}
		}
		if reels == nil {
			reels = []models.Reel{}
		}

		c.JSON(http.StatusOK, gin.H{
			"videos": videos,
			"reels":  reels,
		})
	}
}

func GetDiscover(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		opts := options.Find().SetSort(bson.D{{Key: "views", Value: -1}}).SetLimit(20)

		// Get trending videos
		videoCursor, _ := db.Collection("videos").Find(context.Background(), bson.M{}, opts)
		var videos []models.Video
		videoCursor.All(context.Background(), &videos)

		// Get trending products
		productCursor, _ := db.Collection("products").Find(context.Background(), bson.M{}, opts)
		var products []models.Product
		productCursor.All(context.Background(), &products)

		if videos == nil {
			videos = []models.Video{}
		}
		if products == nil {
			products = []models.Product{}
		}

		c.JSON(http.StatusOK, gin.H{
			"videos":   videos,
			"products": products,
		})
	}
}

func Search(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		query := c.Query("q")
		if query == "" {
			c.JSON(http.StatusOK, models.SearchResponse{
				Products: []models.Product{},
				Videos:   []models.Video{},
				Reels:    []models.Reel{},
				Users:    []models.User{},
			})
			return
		}

		filter := bson.M{"$or": []bson.M{
			{"title": bson.M{"$regex": query, "$options": "i"}},
			{"description": bson.M{"$regex": query, "$options": "i"}},
		}}

		opts := options.Find().SetLimit(10)

		// Search products
		productCursor, _ := db.Collection("products").Find(context.Background(), filter, opts)
		var products []models.Product
		productCursor.All(context.Background(), &products)

		// Search videos
		videoCursor, _ := db.Collection("videos").Find(context.Background(), filter, opts)
		var videos []models.Video
		videoCursor.All(context.Background(), &videos)

		// Search reels
		reelFilter := bson.M{"caption": bson.M{"$regex": query, "$options": "i"}}
		reelCursor, _ := db.Collection("reels").Find(context.Background(), reelFilter, opts)
		var reels []models.Reel
		reelCursor.All(context.Background(), &reels)

		// Search users
		userFilter := bson.M{"$or": []bson.M{
			{"name": bson.M{"$regex": query, "$options": "i"}},
			{"bio": bson.M{"$regex": query, "$options": "i"}},
		}}
		userCursor, _ := db.Collection("users").Find(context.Background(), userFilter, opts)
		var users []models.User
		userCursor.All(context.Background(), &users)

		if products == nil {
			products = []models.Product{}
		}
		if videos == nil {
			videos = []models.Video{}
		}
		if reels == nil {
			reels = []models.Reel{}
		}
		if users == nil {
			users = []models.User{}
		}

		c.JSON(http.StatusOK, models.SearchResponse{
			Products: products,
			Videos:   videos,
			Reels:    reels,
			Users:    users,
		})
	}
}
