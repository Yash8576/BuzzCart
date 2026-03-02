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

func CreateVideo(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.VideoCreate
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

		// Insert into content_items table
		_, err = db.Exec(
			`INSERT INTO content_items (id, creator_id, content_type, title, description, video_url, thumbnail_url, duration_seconds, view_count, like_count, created_at) 
			 VALUES ($1, $2, 'video', $3, $4, $5, $6, $7, $8, $9, $10)`,
			video.ID, video.CreatorID, video.Title, video.Description, video.URL, video.Thumbnail, video.Duration,
			video.Views, video.Likes, video.CreatedAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create video"})
			return
		}

		// Also insert into user_media for profile gallery
		_, err = db.Exec(
			`INSERT INTO user_media (user_id, media_type, media_url, thumbnail_url, caption, duration_seconds, content_id) 
			 VALUES ($1, 'video', $2, $3, $4, $5, $6)`,
			userID, video.URL, video.Thumbnail, video.Description, video.Duration, video.ID,
		)
		if err != nil {
			// Log but don't fail the request
			c.Writer.Header().Add("X-Media-Gallery-Error", "Failed to add to media gallery")
		}

		c.JSON(http.StatusOK, video)
	}
}

func GetVideos(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		rows, err := db.Query(
			`SELECT ci.id, ci.title, ci.description, ci.video_url, ci.thumbnail_url, ci.duration_seconds, 
			        ci.view_count, ci.like_count, ci.creator_id, u.name, u.avatar, '[]'::jsonb as products, ci.created_at 
			 FROM content_items ci
			 JOIN users u ON ci.creator_id = u.id
			 WHERE ci.content_type = 'video'
			 ORDER BY ci.created_at DESC LIMIT 20`,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch videos"})
			return
		}
		defer rows.Close()

		var videos []models.Video
		for rows.Next() {
			var video models.Video
			var productsJSON []byte
			err := rows.Scan(
				&video.ID, &video.Title, &video.Description, &video.URL, &video.Thumbnail, &video.Duration,
				&video.Views, &video.Likes, &video.CreatorID, &video.CreatorName, &video.CreatorAvatar,
				&productsJSON, &video.CreatedAt,
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode videos"})
				return
			}
			json.Unmarshal(productsJSON, &video.Products)
			if video.Products == nil {
				video.Products = []models.ProductSimple{}
			}
			videos = append(videos, video)
		}

		if videos == nil {
			videos = []models.Video{}
		}

		c.JSON(http.StatusOK, videos)
	}
}

func GetVideo(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		videoID := c.Param("video_id")

		var video models.Video
		var productsJSON []byte
		err := db.QueryRow(
			`SELECT ci.id, ci.title, ci.description, ci.video_url, ci.thumbnail_url, ci.duration_seconds, 
			        ci.view_count, ci.like_count, ci.creator_id, u.name, u.avatar, '[]'::jsonb as products, ci.created_at 
			 FROM content_items ci
			 JOIN users u ON ci.creator_id = u.id
			 WHERE ci.id = $1 AND ci.content_type = 'video'`, videoID,
		).Scan(
			&video.ID, &video.Title, &video.Description, &video.URL, &video.Thumbnail, &video.Duration,
			&video.Views, &video.Likes, &video.CreatorID, &video.CreatorName, &video.CreatorAvatar,
			&productsJSON, &video.CreatedAt,
		)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Video not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch video"})
			return
		}

		json.Unmarshal(productsJSON, &video.Products)
		if video.Products == nil {
			video.Products = []models.ProductSimple{}
		}

		// Increment views
		db.Exec("UPDATE content_items SET view_count = view_count + 1 WHERE id = $1", videoID)

		c.JSON(http.StatusOK, video)
	}
}

func LikeVideo(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		videoID := c.Param("video_id")

		_, err := db.Exec("UPDATE content_items SET like_count = like_count + 1 WHERE id = $1 AND content_type = 'video'", videoID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to like video"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Video liked"})
	}
}
