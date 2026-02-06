package main

import (
	"buzzcart/internal/config"
	"buzzcart/internal/database"
	"buzzcart/internal/handlers"
	"buzzcart/internal/middleware"
	"buzzcart/internal/storage"
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using system environment variables")
	}

	// Initialize configuration
	cfg := config.Load()

	// Initialize database connection
	db, err := database.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Disconnect()

	// Initialize MinIO storage
	if err := storage.InitializeStorage(cfg); err != nil {
		log.Fatalf("Failed to initialize MinIO storage: %v", err)
	}
	log.Println("✓ MinIO storage initialized successfully")

	// Set Gin mode
	if os.Getenv("GIN_MODE") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	// Create router
	router := gin.Default()

	// CORS middleware
	router.Use(middleware.CORS())

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// API routes
	api := router.Group("/api")
	{
		// Auth routes
		auth := api.Group("/auth")
		{
			auth.POST("/register", handlers.Register(db))
			auth.POST("/login", handlers.Login(db))
			auth.GET("/me", middleware.Auth(cfg.JWTSecret), handlers.GetMe(db))
			auth.PUT("/profile", middleware.Auth(cfg.JWTSecret), handlers.UpdateProfile(db))
		}

		// User routes
		api.GET("/users/:user_id", handlers.GetUser(db))

		// Product routes
		products := api.Group("/products")
		{
			products.POST("", middleware.Auth(cfg.JWTSecret), handlers.CreateProduct(db))
			products.GET("", handlers.GetProducts(db))
			products.GET("/:product_id", handlers.GetProduct(db))
			products.PUT("/:product_id", middleware.Auth(cfg.JWTSecret), handlers.UpdateProduct(db))
			products.DELETE("/:product_id", middleware.Auth(cfg.JWTSecret), handlers.DeleteProduct(db))
			products.GET("/seller/:seller_id", handlers.GetSellerProducts(db))
		}

		// Video routes
		videos := api.Group("/videos")
		{
			videos.POST("", middleware.Auth(cfg.JWTSecret), handlers.CreateVideo(db))
			videos.GET("", handlers.GetVideos(db))
			videos.GET("/:video_id", handlers.GetVideo(db))
			videos.POST("/:video_id/like", middleware.Auth(cfg.JWTSecret), handlers.LikeVideo(db))
		}

		// Reel routes
		reels := api.Group("/reels")
		{
			reels.POST("", middleware.Auth(cfg.JWTSecret), handlers.CreateReel(db))
			reels.GET("", handlers.GetReels(db))
			reels.GET("/:reel_id", handlers.GetReel(db))
			reels.POST("/:reel_id/like", middleware.Auth(cfg.JWTSecret), handlers.LikeReel(db))
		}

		// Cart routes
		cart := api.Group("/cart")
		cart.Use(middleware.Auth(cfg.JWTSecret))
		{
			cart.GET("", handlers.GetCart(db))
			cart.POST("/add", handlers.AddToCart(db))
			cart.POST("/remove", handlers.RemoveFromCart(db))
			cart.POST("/update", handlers.UpdateCartItem(db))
			cart.DELETE("/clear", handlers.ClearCart(db))
		}

		// Upload routes
		upload := api.Group("/upload")
		{
			// Public upload endpoints
			upload.POST("/image", handlers.UploadImageHandler)
			upload.POST("/video", handlers.UploadVideoHandler)
			upload.POST("/product-image", handlers.UploadProductImageHandler)

			// Protected upload endpoints (require authentication)
			upload.POST("/avatar", middleware.Auth(cfg.JWTSecret), handlers.UploadAvatarHandler)
			upload.DELETE("/:objectName", middleware.Auth(cfg.JWTSecret), handlers.DeleteFileHandler)
		}

		// Follow routes
		api.POST("/follow/:user_id", middleware.Auth(cfg.JWTSecret), handlers.FollowUser(db))
		api.POST("/unfollow/:user_id", middleware.Auth(cfg.JWTSecret), handlers.UnfollowUser(db))

		// Feed routes
		api.GET("/feed", handlers.GetFeed(db))
		api.GET("/discover", handlers.GetDiscover(db))

		// Search route
		api.GET("/search", handlers.Search(db))

		// Message routes
		messages := api.Group("/messages")
		messages.Use(middleware.Auth(cfg.JWTSecret))
		{
			messages.POST("", handlers.SendMessage(db))
			messages.GET("/conversations", handlers.GetConversations(db))
			messages.GET("/conversations/:conversation_id", handlers.GetMessages(db))
		}
	}

	// Start server
	port := cfg.Port
	if port == "" {
		port = "8000"
	}

	log.Printf("Server starting on port %s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
