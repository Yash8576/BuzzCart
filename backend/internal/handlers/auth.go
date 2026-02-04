package handlers

import (
	"buzzcart/internal/config"
	"buzzcart/internal/models"
	"buzzcart/internal/utils"
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

func Register(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req models.UserCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Check if email already exists
		var existingUser models.User
		err := db.Collection("users").FindOne(context.Background(), bson.M{"email": req.Email}).Decode(&existingUser)
		if err == nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Email already registered"})
			return
		}

		// Hash password
		hashedPassword, err := utils.HashPassword(req.Password)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
			return
		}

		// Create user
		user := models.User{
			ID:             uuid.New().String(),
			Email:          req.Email,
			Password:       hashedPassword,
			Name:           req.Name,
			Bio:            "",
			FollowersCount: 0,
			FollowingCount: 0,
			CreatedAt:      time.Now(),
		}

		_, err = db.Collection("users").InsertOne(context.Background(), user)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
			return
		}

		// Create token
		cfg := config.Load()
		token, err := utils.CreateToken(user.ID, cfg.JWTSecret)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create token"})
			return
		}

		c.JSON(http.StatusOK, models.TokenResponse{
			AccessToken: token,
			TokenType:   "bearer",
			User:        user,
		})
	}
}

func Login(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req models.UserLogin
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Find user
		var user models.User
		err := db.Collection("users").FindOne(context.Background(), bson.M{"email": req.Email}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
			return
		}

		// Verify password
		if !utils.VerifyPassword(req.Password, user.Password) {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
			return
		}

		// Create token
		cfg := config.Load()
		token, err := utils.CreateToken(user.ID, cfg.JWTSecret)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create token"})
			return
		}

		c.JSON(http.StatusOK, models.TokenResponse{
			AccessToken: token,
			TokenType:   "bearer",
			User:        user,
		})
	}
}

func GetMe(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var user models.User
		err := db.Collection("users").FindOne(context.Background(), bson.M{"id": userID}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		c.JSON(http.StatusOK, user)
	}
}

func UpdateProfile(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.ProfileUpdate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Build update document
		updateDoc := bson.M{}
		if req.Name != nil {
			updateDoc["name"] = *req.Name
		}
		if req.Bio != nil {
			updateDoc["bio"] = *req.Bio
		}
		if req.Avatar != nil {
			updateDoc["avatar"] = *req.Avatar
		}

		if len(updateDoc) > 0 {
			_, err := db.Collection("users").UpdateOne(
				context.Background(),
				bson.M{"id": userID},
				bson.M{"$set": updateDoc},
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update profile"})
				return
			}
		}

		var user models.User
		err := db.Collection("users").FindOne(context.Background(), bson.M{"id": userID}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		c.JSON(http.StatusOK, user)
	}
}

func GetUser(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("user_id")

		var user models.User
		err := db.Collection("users").FindOne(context.Background(), bson.M{"id": userID}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		c.JSON(http.StatusOK, user)
	}
}
