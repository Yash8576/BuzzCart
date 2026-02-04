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

func GetCart(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var cart models.Cart
		err := db.Collection("carts").FindOne(context.Background(), bson.M{"user_id": userID}).Decode(&cart)
		if err != nil {
			// Return empty cart if not found
			c.JSON(http.StatusOK, models.CartResponse{
				Items:     []models.CartItem{},
				Subtotal:  0,
				Total:     0,
				ItemCount: 0,
			})
			return
		}

		// Calculate totals
		subtotal := 0.0
		itemCount := 0
		for _, item := range cart.Items {
			subtotal += item.Price * float64(item.Quantity)
			itemCount += item.Quantity
		}

		c.JSON(http.StatusOK, models.CartResponse{
			Items:     cart.Items,
			Subtotal:  subtotal,
			Total:     subtotal,
			ItemCount: itemCount,
		})
	}
}

func AddToCart(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.CartItemAdd
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		if req.Quantity <= 0 {
			req.Quantity = 1
		}

		// Get product details
		var product models.Product
		err := db.Collection("products").FindOne(context.Background(), bson.M{"id": req.ProductID}).Decode(&product)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		}

		image := ""
		if len(product.Images) > 0 {
			image = product.Images[0]
		}

		cartItem := models.CartItem{
			ProductID: product.ID,
			Title:     product.Title,
			Price:     product.Price,
			Image:     image,
			Quantity:  req.Quantity,
		}

		// Find or create cart
		var cart models.Cart
		err = db.Collection("carts").FindOne(context.Background(), bson.M{"user_id": userID}).Decode(&cart)

		if err == mongo.ErrNoDocuments {
			// Create new cart
			cart = models.Cart{
				UserID:    userID,
				Items:     []models.CartItem{cartItem},
				UpdatedAt: time.Now(),
			}
			_, err = db.Collection("carts").InsertOne(context.Background(), cart)
		} else {
			// Update existing cart
			found := false
			for i, item := range cart.Items {
				if item.ProductID == req.ProductID {
					cart.Items[i].Quantity += req.Quantity
					found = true
					break
				}
			}

			if !found {
				cart.Items = append(cart.Items, cartItem)
			}

			_, err = db.Collection("carts").UpdateOne(
				context.Background(),
				bson.M{"user_id": userID},
				bson.M{"$set": bson.M{"items": cart.Items, "updated_at": time.Now()}},
			)
		}

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add to cart"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Added to cart"})
	}
}

func RemoveFromCart(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req struct {
			ProductID string `json:"product_id" binding:"required"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		_, err := db.Collection("carts").UpdateOne(
			context.Background(),
			bson.M{"user_id": userID},
			bson.M{"$pull": bson.M{"items": bson.M{"product_id": req.ProductID}}},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove from cart"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Removed from cart"})
	}
}

func UpdateCartItem(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req struct {
			ProductID string `json:"product_id" binding:"required"`
			Quantity  int    `json:"quantity" binding:"required,gt=0"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		_, err := db.Collection("carts").UpdateOne(
			context.Background(),
			bson.M{"user_id": userID, "items.product_id": req.ProductID},
			bson.M{"$set": bson.M{"items.$.quantity": req.Quantity}},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update cart"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Cart updated"})
	}
}

func ClearCart(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		_, err := db.Collection("carts").DeleteOne(context.Background(), bson.M{"user_id": userID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to clear cart"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Cart cleared"})
	}
}
