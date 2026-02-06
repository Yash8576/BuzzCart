package handlers

import (
	"buzzcart/internal/models"
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/lib/pq"
)

func CreateProduct(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.ProductCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Get user info
		var user models.User
		err := db.QueryRow("SELECT id, name, email, avatar, bio, followers_count, following_count, created_at FROM users WHERE id = $1", userID).Scan(
			&user.ID, &user.Name, &user.Email, &user.Avatar, &user.Bio, &user.FollowersCount, &user.FollowingCount, &user.CreatedAt,
		)
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

		_, err = db.Exec(
			`INSERT INTO products (id, title, description, price, images, category, tags, seller_id, seller_name, rating, reviews_count, views, created_at) 
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
			product.ID, product.Title, product.Description, product.Price, pq.Array(product.Images), product.Category, pq.Array(product.Tags),
			product.SellerID, product.SellerName, product.Rating, product.ReviewsCount, product.Views, product.CreatedAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create product"})
			return
		}

		c.JSON(http.StatusOK, product)
	}
}

func GetProducts(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		rows, err := db.Query(
			`SELECT id, title, description, price, images, category, tags, seller_id, seller_name, rating, reviews_count, views, created_at 
			 FROM products ORDER BY created_at DESC LIMIT 20`,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch products"})
			return
		}
		defer rows.Close()

		var products []models.Product
		for rows.Next() {
			var product models.Product
			err := rows.Scan(
				&product.ID, &product.Title, &product.Description, &product.Price, pq.Array(&product.Images),
				&product.Category, pq.Array(&product.Tags), &product.SellerID, &product.SellerName,
				&product.Rating, &product.ReviewsCount, &product.Views, &product.CreatedAt,
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode products"})
				return
			}
			products = append(products, product)
		}

		if products == nil {
			products = []models.Product{}
		}

		c.JSON(http.StatusOK, products)
	}
}

func GetProduct(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		productID := c.Param("product_id")

		var product models.Product
		err := db.QueryRow(
			`SELECT id, title, description, price, images, category, tags, seller_id, seller_name, rating, reviews_count, views, created_at 
			 FROM products WHERE id = $1`, productID,
		).Scan(
			&product.ID, &product.Title, &product.Description, &product.Price, pq.Array(&product.Images),
			&product.Category, pq.Array(&product.Tags), &product.SellerID, &product.SellerName,
			&product.Rating, &product.ReviewsCount, &product.Views, &product.CreatedAt,
		)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch product"})
			return
		}

		// Increment views
		db.Exec("UPDATE products SET views = views + 1 WHERE id = $1", productID)

		c.JSON(http.StatusOK, product)
	}
}

func UpdateProduct(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		productID := c.Param("product_id")

		var product models.Product
		err := db.QueryRow("SELECT seller_id FROM products WHERE id = $1", productID).Scan(&product.SellerID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch product"})
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

		_, err = db.Exec(
			`UPDATE products SET title = $1, description = $2, price = $3, images = $4, category = $5, tags = $6 
			 WHERE id = $7`,
			req.Title, req.Description, req.Price, pq.Array(req.Images), req.Category, pq.Array(req.Tags), productID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update product"})
			return
		}

		err = db.QueryRow(
			`SELECT id, title, description, price, images, category, tags, seller_id, seller_name, rating, reviews_count, views, created_at 
			 FROM products WHERE id = $1`, productID,
		).Scan(
			&product.ID, &product.Title, &product.Description, &product.Price, pq.Array(&product.Images),
			&product.Category, pq.Array(&product.Tags), &product.SellerID, &product.SellerName,
			&product.Rating, &product.ReviewsCount, &product.Views, &product.CreatedAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch updated product"})
			return
		}

		c.JSON(http.StatusOK, product)
	}
}

func DeleteProduct(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		productID := c.Param("product_id")

		var product models.Product
		err := db.QueryRow("SELECT seller_id FROM products WHERE id = $1", productID).Scan(&product.SellerID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch product"})
			return
		}

		if product.SellerID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized"})
			return
		}

		_, err = db.Exec("DELETE FROM products WHERE id = $1", productID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete product"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Product deleted"})
	}
}

func GetSellerProducts(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		sellerID := c.Param("seller_id")

		rows, err := db.Query(
			`SELECT id, title, description, price, images, category, tags, seller_id, seller_name, rating, reviews_count, views, created_at 
			 FROM products WHERE seller_id = $1`, sellerID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch products"})
			return
		}
		defer rows.Close()

		var products []models.Product
		for rows.Next() {
			var product models.Product
			err := rows.Scan(
				&product.ID, &product.Title, &product.Description, &product.Price, pq.Array(&product.Images),
				&product.Category, pq.Array(&product.Tags), &product.SellerID, &product.SellerName,
				&product.Rating, &product.ReviewsCount, &product.Views, &product.CreatedAt,
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode products"})
				return
			}
			products = append(products, product)
		}

		if products == nil {
			products = []models.Product{}
		}

		c.JSON(http.StatusOK, products)
	}
}
