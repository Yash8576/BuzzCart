package handlers

import (
	"buzzcart/internal/config"
	"buzzcart/internal/models"
	"buzzcart/internal/utils"
	"database/sql"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func Register(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req models.UserCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Validate business rules (sellers must be public, etc.)
		if err := req.Validate(); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Check if email already exists
		var existingID string
		err := db.QueryRow("SELECT id FROM users WHERE email = $1", req.Email).Scan(&existingID)
		if err == nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Email already registered"})
			return
		} else if err != sql.ErrNoRows {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}

		// Hash password
		hashedPassword, err := utils.HashPassword(req.Password)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
			return
		}

		// Create user with account type and privacy settings
		user := models.User{
			ID:             uuid.New().String(),
			Email:          req.Email,
			Password:       hashedPassword,
			Name:           req.Name,
			Bio:            "",
			AccountType:    req.AccountType,
			Role:           req.Role,
			Status:         models.StatusActive,
			IsVerified:     false,
			PhoneNumber:    req.PhoneNumber,
			PrivacyProfile: req.PrivacyProfile,
			FollowersCount: 0,
			FollowingCount: 0,
			CreatedAt:      time.Now(),
		}

		// Generate username from email if not provided (use part before @)
		username := req.Email[:strings.Index(req.Email, "@")]

		// Insert user into database
		_, err = db.Exec(`
		INSERT INTO users (id, username, email, password_hash, name, bio, account_type, role, status, is_verified, 
			phone_number, privacy_profile, followers_count, following_count, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
	`, user.ID, username, user.Email, user.Password, user.Name, user.Bio, user.AccountType, user.Role,
			user.Status, user.IsVerified, user.PhoneNumber, user.PrivacyProfile,
			user.FollowersCount, user.FollowingCount, user.CreatedAt, user.CreatedAt)

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

func Login(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req models.UserLogin
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Find user
		var user models.User
		err := db.QueryRow(`
			SELECT id, email, password_hash, name, avatar, bio, account_type, role, status, 
				is_verified, phone_number, privacy_profile, followers_count, following_count, created_at
			FROM users WHERE email = $1
		`, req.Email).Scan(
			&user.ID, &user.Email, &user.Password, &user.Name, &user.Avatar, &user.Bio,
			&user.AccountType, &user.Role, &user.Status, &user.IsVerified, &user.PhoneNumber,
			&user.PrivacyProfile, &user.FollowersCount, &user.FollowingCount, &user.CreatedAt,
		)

		if err == sql.ErrNoRows {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
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

func GetMe(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var user models.User
		err := db.QueryRow(`
			SELECT id, email, password_hash, name, avatar, bio, account_type, role, status, 
				is_verified, phone_number, privacy_profile, followers_count, following_count, created_at
			FROM users WHERE id = $1
		`, userID).Scan(
			&user.ID, &user.Email, &user.Password, &user.Name, &user.Avatar, &user.Bio,
			&user.AccountType, &user.Role, &user.Status, &user.IsVerified, &user.PhoneNumber,
			&user.PrivacyProfile, &user.FollowersCount, &user.FollowingCount, &user.CreatedAt,
		)

		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}

		c.JSON(http.StatusOK, user)
	}
}

func UpdateProfile(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.ProfileUpdate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Build update query dynamically
		query := "UPDATE users SET "
		args := []interface{}{}
		argCount := 1

		if req.Name != nil {
			if argCount > 1 {
				query += ", "
			}
			query += fmt.Sprintf("name = $%d", argCount)
			args = append(args, *req.Name)
			argCount++
		}
		if req.Bio != nil {
			if argCount > 1 {
				query += ", "
			}
			query += fmt.Sprintf("bio = $%d", argCount)
			args = append(args, *req.Bio)
			argCount++
		}
		if req.Avatar != nil {
			if argCount > 1 {
				query += ", "
			}
			query += fmt.Sprintf("avatar = $%d", argCount)
			args = append(args, *req.Avatar)
			argCount++
		}

		if len(args) > 0 {
			query += fmt.Sprintf(" WHERE id = $%d", argCount)
			args = append(args, userID)

			_, err := db.Exec(query, args...)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update profile"})
				return
			}
		}

		// Fetch updated user
		var user models.User
		err := db.QueryRow(`
			SELECT id, email, password_hash, name, avatar, bio, account_type, role, status, 
				is_verified, phone_number, privacy_profile, followers_count, following_count, created_at
			FROM users WHERE id = $1
		`, userID).Scan(
			&user.ID, &user.Email, &user.Password, &user.Name, &user.Avatar, &user.Bio,
			&user.AccountType, &user.Role, &user.Status, &user.IsVerified, &user.PhoneNumber,
			&user.PrivacyProfile, &user.FollowersCount, &user.FollowingCount, &user.CreatedAt,
		)

		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}

		c.JSON(http.StatusOK, user)
	}
}

func GetUser(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("user_id")
		viewerID := c.GetString("user_id")

		var user models.User
		err := db.QueryRow(`
			SELECT id, email, password_hash, name, avatar, bio, account_type, role, status, 
				is_verified, phone_number, privacy_profile, followers_count, following_count, created_at
			FROM users WHERE id = $1
		`, userID).Scan(
			&user.ID, &user.Email, &user.Password, &user.Name, &user.Avatar, &user.Bio,
			&user.AccountType, &user.Role, &user.Status, &user.IsVerified, &user.PhoneNumber,
			&user.PrivacyProfile, &user.FollowersCount, &user.FollowingCount, &user.CreatedAt,
		)

		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}

		user.CanViewConnections = user.PrivacyProfile != models.PrivacyPrivate || viewerID == userID
		if viewerID != "" && viewerID != userID {
			err = db.QueryRow(
				`SELECT
					EXISTS(SELECT 1 FROM user_follows WHERE follower_id = $1 AND following_id = $2),
					EXISTS(SELECT 1 FROM user_follows WHERE follower_id = $2 AND following_id = $1)`,
				viewerID,
				userID,
			).Scan(&user.IsFollowing, &user.IsFollowedBy)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load relationship state"})
				return
			}
			user.IsConnection = user.IsFollowing && user.IsFollowedBy
			if user.PrivacyProfile == models.PrivacyPrivate {
				user.CanViewConnections = user.IsConnection
			}
		} else if viewerID == userID {
			user.CanViewConnections = true
		}

		c.JSON(http.StatusOK, user)
	}
}
