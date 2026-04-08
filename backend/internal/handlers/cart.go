package handlers

import (
	"buzzcart/internal/models"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

func GetCart(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		// Log the user_id for debugging
		fmt.Printf("GetCart - user_id from context: %s\n", userID)

		if userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}

		var itemsJSON []byte
		var updatedAt time.Time
		err := db.QueryRow("SELECT items, updated_at FROM carts WHERE user_id = $1", userID).Scan(&itemsJSON, &updatedAt)

		if err == sql.ErrNoRows {
			// Return empty cart if not found
			c.JSON(http.StatusOK, models.CartResponse{
				Items:     []models.CartItem{},
				Subtotal:  0,
				Total:     0,
				ItemCount: 0,
			})
			return
		} else if err != nil {
			fmt.Printf("GetCart - Database error: %v\n", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to fetch cart: %v", err)})
			return
		}

		var items []models.CartItem
		if err := json.Unmarshal(itemsJSON, &items); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse cart items"})
			return
		}

		// Calculate totals
		subtotal := 0.0
		itemCount := 0
		for _, item := range items {
			subtotal += item.Price * float64(item.Quantity)
			itemCount += item.Quantity
		}

		c.JSON(http.StatusOK, models.CartResponse{
			Items:     items,
			Subtotal:  subtotal,
			Total:     subtotal,
			ItemCount: itemCount,
		})
	}
}

func AddToCart(db *sql.DB) gin.HandlerFunc {
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

		// Get product details using schema-aware product queries.
		product, err := getProductByID(db, req.ProductID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		}
		if err != nil {
			product, err = getProductByIDLegacy(db, req.ProductID)
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
				return
			}
			if err != nil {
				fmt.Printf("AddToCart - Failed to fetch product %s: %v\n", req.ProductID, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch product"})
				return
			}
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
		var itemsJSON []byte
		err = db.QueryRow("SELECT items FROM carts WHERE user_id = $1", userID).Scan(&itemsJSON)

		var items []models.CartItem
		if err == sql.ErrNoRows {
			// Create new cart
			items = []models.CartItem{cartItem}
			itemsData, _ := json.Marshal(items)
			_, err = db.Exec(
				"INSERT INTO carts (user_id, items, updated_at) VALUES ($1, $2, $3)",
				userID, itemsData, time.Now(),
			)
		} else if err == nil {
			// Update existing cart
			json.Unmarshal(itemsJSON, &items)
			found := false
			for i, item := range items {
				if item.ProductID == req.ProductID {
					items[i].Quantity += req.Quantity
					found = true
					break
				}
			}

			if !found {
				items = append(items, cartItem)
			}

			itemsData, _ := json.Marshal(items)
			_, err = db.Exec(
				"UPDATE carts SET items = $1, updated_at = $2 WHERE user_id = $3",
				itemsData, time.Now(), userID,
			)
		}

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add to cart"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Added to cart"})
	}
}

func RemoveFromCart(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req struct {
			ProductID string `json:"product_id" binding:"required"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Get current cart items
		var itemsJSON []byte
		err := db.QueryRow("SELECT items FROM carts WHERE user_id = $1", userID).Scan(&itemsJSON)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Cart not found"})
			return
		}

		var items []models.CartItem
		json.Unmarshal(itemsJSON, &items)

		// Remove item
		newItems := []models.CartItem{}
		for _, item := range items {
			if item.ProductID != req.ProductID {
				newItems = append(newItems, item)
			}
		}

		itemsData, _ := json.Marshal(newItems)
		_, err = db.Exec("UPDATE carts SET items = $1, updated_at = $2 WHERE user_id = $3", itemsData, time.Now(), userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove from cart"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Removed from cart"})
	}
}

func UpdateCartItem(db *sql.DB) gin.HandlerFunc {
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

		// Get current cart items
		var itemsJSON []byte
		err := db.QueryRow("SELECT items FROM carts WHERE user_id = $1", userID).Scan(&itemsJSON)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Cart not found"})
			return
		}

		var items []models.CartItem
		json.Unmarshal(itemsJSON, &items)

		// Update quantity
		for i, item := range items {
			if item.ProductID == req.ProductID {
				items[i].Quantity = req.Quantity
				break
			}
		}

		itemsData, _ := json.Marshal(items)
		_, err = db.Exec("UPDATE carts SET items = $1, updated_at = $2 WHERE user_id = $3", itemsData, time.Now(), userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update cart"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Cart updated"})
	}
}

func ClearCart(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		_, err := db.Exec("DELETE FROM carts WHERE user_id = $1", userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to clear cart"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Cart cleared"})
	}
}
