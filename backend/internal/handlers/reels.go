package handlers

import (
	"buzzcart/internal/models"
	"database/sql"
	"encoding/json"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/lib/pq"
)

func CreateReel(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.ReelCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Get user info
		var user models.User
		err := db.QueryRow("SELECT id, name, avatar FROM users WHERE id = $1", userID).Scan(
			&user.ID, &user.Name, &user.Avatar,
		)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		// Fetch products
		var products []models.ProductSimple
		if len(req.ProductIDs) > 0 {
			rows, err := db.Query(
				"SELECT id, title, price, images FROM products WHERE id = ANY($1)",
				pq.Array(req.ProductIDs),
			)
			if err == nil {
				defer rows.Close()
				for rows.Next() {
					var p models.Product
					var imagesJSON []byte
					rows.Scan(&p.ID, &p.Title, &p.Price, &imagesJSON)
					var images []string
					json.Unmarshal(imagesJSON, &images)
					image := ""
					if len(images) > 0 {
						image = images[0]
					}
					products = append(products, models.ProductSimple{
						ID:    p.ID,
						Title: p.Title,
						Price: p.Price,
						Image: image,
					})
				}
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

		productsJSON, _ := json.Marshal(reel.Products)
		_, err = db.Exec(
			`INSERT INTO reels (id, url, thumbnail, caption, views, likes, creator_id, creator_name, creator_avatar, products, created_at) 
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
			reel.ID, reel.URL, reel.Thumbnail, reel.Caption, reel.Views, reel.Likes,
			reel.CreatorID, reel.CreatorName, reel.CreatorAvatar, productsJSON, reel.CreatedAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create reel"})
			return
		}

		c.JSON(http.StatusOK, reel)
	}
}

func GetReels(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		rows, err := db.Query(
			`SELECT id, url, thumbnail, caption, views, likes, creator_id, creator_name, creator_avatar, products, created_at 
			 FROM reels ORDER BY created_at DESC LIMIT 20`,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch reels"})
			return
		}
		defer rows.Close()

		var reels []models.Reel
		for rows.Next() {
			var reel models.Reel
			var productsJSON []byte
			err := rows.Scan(
				&reel.ID, &reel.URL, &reel.Thumbnail, &reel.Caption, &reel.Views, &reel.Likes,
				&reel.CreatorID, &reel.CreatorName, &reel.CreatorAvatar, &productsJSON, &reel.CreatedAt,
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode reels"})
				return
			}
			json.Unmarshal(productsJSON, &reel.Products)
			if reel.Products == nil {
				reel.Products = []models.ProductSimple{}
			}
			reels = append(reels, reel)
		}

		if reels == nil {
			reels = []models.Reel{}
		}

		c.JSON(http.StatusOK, reels)
	}
}

func GetReel(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		reelID := c.Param("reel_id")

		var reel models.Reel
		var productsJSON []byte
		err := db.QueryRow(
			`SELECT id, url, thumbnail, caption, views, likes, creator_id, creator_name, creator_avatar, products, created_at 
			 FROM reels WHERE id = $1`, reelID,
		).Scan(
			&reel.ID, &reel.URL, &reel.Thumbnail, &reel.Caption, &reel.Views, &reel.Likes,
			&reel.CreatorID, &reel.CreatorName, &reel.CreatorAvatar, &productsJSON, &reel.CreatedAt,
		)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Reel not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch reel"})
			return
		}

		json.Unmarshal(productsJSON, &reel.Products)
		if reel.Products == nil {
			reel.Products = []models.ProductSimple{}
		}

		// Increment views
		db.Exec("UPDATE reels SET views = views + 1 WHERE id = $1", reelID)

		c.JSON(http.StatusOK, reel)
	}
}

func LikeReel(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		reelID := c.Param("reel_id")

		_, err := db.Exec("UPDATE reels SET likes = likes + 1 WHERE id = $1", reelID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to like reel"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Reel liked"})
	}
}
