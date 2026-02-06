package handlers

import (
	"buzzcart/internal/models"
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/lib/pq"
)

func GetFeed(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get videos
		videoRows, _ := db.Query(
			`SELECT id, title, description, url, thumbnail, duration, views, likes, creator_id, creator_name, creator_avatar, products, created_at 
			 FROM videos ORDER BY created_at DESC LIMIT 20`,
		)
		var videos []models.Video
		if videoRows != nil {
			defer videoRows.Close()
			for videoRows.Next() {
				var video models.Video
				var productsJSON []byte
				videoRows.Scan(
					&video.ID, &video.Title, &video.Description, &video.URL, &video.Thumbnail, &video.Duration,
					&video.Views, &video.Likes, &video.CreatorID, &video.CreatorName, &video.CreatorAvatar,
					&productsJSON, &video.CreatedAt,
				)
				json.Unmarshal(productsJSON, &video.Products)
				if video.Products == nil {
					video.Products = []models.ProductSimple{}
				}
				videos = append(videos, video)
			}
		}

		// Get reels
		reelRows, _ := db.Query(
			`SELECT id, url, thumbnail, caption, views, likes, creator_id, creator_name, creator_avatar, products, created_at 
			 FROM reels ORDER BY created_at DESC LIMIT 20`,
		)
		var reels []models.Reel
		if reelRows != nil {
			defer reelRows.Close()
			for reelRows.Next() {
				var reel models.Reel
				var productsJSON []byte
				reelRows.Scan(
					&reel.ID, &reel.URL, &reel.Thumbnail, &reel.Caption, &reel.Views, &reel.Likes,
					&reel.CreatorID, &reel.CreatorName, &reel.CreatorAvatar, &productsJSON, &reel.CreatedAt,
				)
				json.Unmarshal(productsJSON, &reel.Products)
				if reel.Products == nil {
					reel.Products = []models.ProductSimple{}
				}
				reels = append(reels, reel)
			}
		}

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

func GetDiscover(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get trending videos
		videoRows, _ := db.Query(
			`SELECT id, title, description, url, thumbnail, duration, views, likes, creator_id, creator_name, creator_avatar, products, created_at 
			 FROM videos ORDER BY views DESC LIMIT 20`,
		)
		var videos []models.Video
		if videoRows != nil {
			defer videoRows.Close()
			for videoRows.Next() {
				var video models.Video
				var productsJSON []byte
				videoRows.Scan(
					&video.ID, &video.Title, &video.Description, &video.URL, &video.Thumbnail, &video.Duration,
					&video.Views, &video.Likes, &video.CreatorID, &video.CreatorName, &video.CreatorAvatar,
					&productsJSON, &video.CreatedAt,
				)
				json.Unmarshal(productsJSON, &video.Products)
				if video.Products == nil {
					video.Products = []models.ProductSimple{}
				}
				videos = append(videos, video)
			}
		}

		// Get trending products
		productRows, _ := db.Query(
			`SELECT id, title, description, price, images, category, tags, seller_id, seller_name, rating, reviews_count, views, created_at 
			 FROM products ORDER BY views DESC LIMIT 20`,
		)
		var products []models.Product
		if productRows != nil {
			defer productRows.Close()
			for productRows.Next() {
				var product models.Product
				productRows.Scan(
					&product.ID, &product.Title, &product.Description, &product.Price, pq.Array(&product.Images),
					&product.Category, pq.Array(&product.Tags), &product.SellerID, &product.SellerName,
					&product.Rating, &product.ReviewsCount, &product.Views, &product.CreatedAt,
				)
				products = append(products, product)
			}
		}

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

func Search(db *sql.DB) gin.HandlerFunc {
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

		searchPattern := "%" + query + "%"

		// Search products
		productRows, _ := db.Query(
			`SELECT id, title, description, price, images, category, tags, seller_id, seller_name, rating, reviews_count, views, created_at 
			 FROM products WHERE title ILIKE $1 OR description ILIKE $1 LIMIT 10`,
			searchPattern,
		)
		var products []models.Product
		if productRows != nil {
			defer productRows.Close()
			for productRows.Next() {
				var product models.Product
				productRows.Scan(
					&product.ID, &product.Title, &product.Description, &product.Price, pq.Array(&product.Images),
					&product.Category, pq.Array(&product.Tags), &product.SellerID, &product.SellerName,
					&product.Rating, &product.ReviewsCount, &product.Views, &product.CreatedAt,
				)
				products = append(products, product)
			}
		}

		// Search videos
		videoRows, _ := db.Query(
			`SELECT id, title, description, url, thumbnail, duration, views, likes, creator_id, creator_name, creator_avatar, products, created_at 
			 FROM videos WHERE title ILIKE $1 OR description ILIKE $1 LIMIT 10`,
			searchPattern,
		)
		var videos []models.Video
		if videoRows != nil {
			defer videoRows.Close()
			for videoRows.Next() {
				var video models.Video
				var productsJSON []byte
				videoRows.Scan(
					&video.ID, &video.Title, &video.Description, &video.URL, &video.Thumbnail, &video.Duration,
					&video.Views, &video.Likes, &video.CreatorID, &video.CreatorName, &video.CreatorAvatar,
					&productsJSON, &video.CreatedAt,
				)
				json.Unmarshal(productsJSON, &video.Products)
				if video.Products == nil {
					video.Products = []models.ProductSimple{}
				}
				videos = append(videos, video)
			}
		}

		// Search reels
		reelRows, _ := db.Query(
			`SELECT id, url, thumbnail, caption, views, likes, creator_id, creator_name, creator_avatar, products, created_at 
			 FROM reels WHERE caption ILIKE $1 LIMIT 10`,
			searchPattern,
		)
		var reels []models.Reel
		if reelRows != nil {
			defer reelRows.Close()
			for reelRows.Next() {
				var reel models.Reel
				var productsJSON []byte
				reelRows.Scan(
					&reel.ID, &reel.URL, &reel.Thumbnail, &reel.Caption, &reel.Views, &reel.Likes,
					&reel.CreatorID, &reel.CreatorName, &reel.CreatorAvatar, &productsJSON, &reel.CreatedAt,
				)
				json.Unmarshal(productsJSON, &reel.Products)
				if reel.Products == nil {
					reel.Products = []models.ProductSimple{}
				}
				reels = append(reels, reel)
			}
		}

		// Search users
		userRows, _ := db.Query(
			`SELECT id, name, email, avatar, bio, followers_count, following_count, created_at 
			 FROM users WHERE name ILIKE $1 OR bio ILIKE $1 LIMIT 10`,
			searchPattern,
		)
		var users []models.User
		if userRows != nil {
			defer userRows.Close()
			for userRows.Next() {
				var user models.User
				userRows.Scan(
					&user.ID, &user.Name, &user.Email, &user.Avatar, &user.Bio,
					&user.FollowersCount, &user.FollowingCount, &user.CreatedAt,
				)
				users = append(users, user)
			}
		}

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
