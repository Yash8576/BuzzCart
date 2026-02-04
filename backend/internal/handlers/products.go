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

func CreateProduct(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.ProductCreate
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

		product := models.Product{
			ID:           uuid.New().String(),
			Title:        req.Title,
			Description:  req.Description,
			Price:        req.Price,
			Images:       req.Images,
			Category:     req.Category,
			Tags:         req.Tags,
			SellerID:     userID,
			SellerName:   user.Name,
			Rating:       0.0,
			ReviewsCount: 0,
			Views:        0,
			CreatedAt:    time.Now(),
		}

		if product.Images == nil {
			product.Images = []string{}
		}
		if product.Tags == nil {
			product.Tags = []string{}
		}

		_, err = db.Collection("products").InsertOne(context.Background(), product)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create product"})
			return
		}

		c.JSON(http.StatusOK, product)
	}
}

func GetProducts(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		opts := options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetLimit(20)

		cursor, err := db.Collection("products").Find(context.Background(), bson.M{}, opts)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch products"})
			return
		}
		defer cursor.Close(context.Background())

		var products []models.Product
		if err = cursor.All(context.Background(), &products); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode products"})
			return
		}

		if products == nil {
			products = []models.Product{}
		}

		c.JSON(http.StatusOK, products)
	}
}

func GetProduct(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		productID := c.Param("product_id")

		var product models.Product
		err := db.Collection("products").FindOne(context.Background(), bson.M{"id": productID}).Decode(&product)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		}

		// Increment views
		db.Collection("products").UpdateOne(
			context.Background(),
			bson.M{"id": productID},
			bson.M{"$inc": bson.M{"views": 1}},
		)

		c.JSON(http.StatusOK, product)
	}
}

func UpdateProduct(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		productID := c.Param("product_id")

		var product models.Product
		err := db.Collection("products").FindOne(context.Background(), bson.M{"id": productID}).Decode(&product)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		}

		if product.SellerID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized"})
			return
		}

		var req models.ProductCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		updateDoc := bson.M{
			"title":       req.Title,
			"description": req.Description,
			"price":       req.Price,
			"images":      req.Images,
			"category":    req.Category,
			"tags":        req.Tags,
		}

		_, err = db.Collection("products").UpdateOne(
			context.Background(),
			bson.M{"id": productID},
			bson.M{"$set": updateDoc},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update product"})
			return
		}

		err = db.Collection("products").FindOne(context.Background(), bson.M{"id": productID}).Decode(&product)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch updated product"})
			return
		}

		c.JSON(http.StatusOK, product)
	}
}

func DeleteProduct(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		productID := c.Param("product_id")

		var product models.Product
		err := db.Collection("products").FindOne(context.Background(), bson.M{"id": productID}).Decode(&product)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		}

		if product.SellerID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized"})
			return
		}

		_, err = db.Collection("products").DeleteOne(context.Background(), bson.M{"id": productID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete product"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Product deleted"})
	}
}

func GetSellerProducts(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		sellerID := c.Param("seller_id")

		cursor, err := db.Collection("products").Find(context.Background(), bson.M{"seller_id": sellerID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch products"})
			return
		}
		defer cursor.Close(context.Background())

		var products []models.Product
		if err = cursor.All(context.Background(), &products); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode products"})
			return
		}

		if products == nil {
			products = []models.Product{}
		}

		c.JSON(http.StatusOK, products)
	}
}
