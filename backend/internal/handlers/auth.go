package handlers

import (
	"buzzcart/internal/config"
	"buzzcart/internal/models"
	"buzzcart/internal/utils"
	"database/sql"
	"encoding/json"
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
			ID:                    uuid.New().String(),
			Email:                 req.Email,
			Password:              hashedPassword,
			Name:                  req.Name,
			Bio:                   "",
			AccountType:           req.AccountType,
			Role:                  req.Role,
			Status:                models.StatusActive,
			IsVerified:            false,
			PhoneNumber:           req.PhoneNumber,
			PrivacyProfile:        req.PrivacyProfile,
			VisibilityMode:        string(req.PrivacyProfile),
			VisibilityPreferences: defaultVisibilityPreferences(string(req.PrivacyProfile)),
			FollowersCount:        0,
			FollowingCount:        0,
			CreatedAt:             time.Now(),
		}
		if req.AccountType == models.AccountTypeSeller {
			user.VisibilityMode = "public"
			user.VisibilityPreferences = defaultVisibilityPreferences("public")
		}

		// Generate username from email if not provided (use part before @)
		username := req.Email[:strings.Index(req.Email, "@")]

		// Insert user into database
		_, err = db.Exec(`
		INSERT INTO users (id, username, email, password_hash, name, bio, account_type, role, status, is_verified, 
			phone_number, privacy_profile, visibility_mode, visibility_preferences, followers_count, following_count, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
	`, user.ID, username, user.Email, user.Password, user.Name, user.Bio, user.AccountType, user.Role,
			user.Status, user.IsVerified, user.PhoneNumber, user.PrivacyProfile,
			user.VisibilityMode, user.VisibilityPreferences,
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
		var visibilityPreferencesJSON string
		err := db.QueryRow(`
			SELECT id, email, password_hash, name, avatar, bio, account_type, role, status, 
				is_verified, phone_number, privacy_profile, visibility_mode, visibility_preferences, followers_count, following_count, created_at
			FROM users WHERE email = $1
		`, req.Email).Scan(
			&user.ID, &user.Email, &user.Password, &user.Name, &user.Avatar, &user.Bio,
			&user.AccountType, &user.Role, &user.Status, &user.IsVerified, &user.PhoneNumber,
			&user.PrivacyProfile, &user.VisibilityMode, &visibilityPreferencesJSON, &user.FollowersCount, &user.FollowingCount, &user.CreatedAt,
		)

		if err == sql.ErrNoRows {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}

		user.VisibilityPreferences = parseVisibilityPreferences(visibilityPreferencesJSON, user.VisibilityMode)
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
		var visibilityPreferencesJSON string
		err := db.QueryRow(`
			SELECT id, email, password_hash, name, avatar, bio, account_type, role, status, 
				is_verified, phone_number, privacy_profile, visibility_mode, visibility_preferences, followers_count, following_count, created_at
			FROM users WHERE id = $1
		`, userID).Scan(
			&user.ID, &user.Email, &user.Password, &user.Name, &user.Avatar, &user.Bio,
			&user.AccountType, &user.Role, &user.Status, &user.IsVerified, &user.PhoneNumber,
			&user.PrivacyProfile, &user.VisibilityMode, &visibilityPreferencesJSON, &user.FollowersCount, &user.FollowingCount, &user.CreatedAt,
		)

		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}
		user.VisibilityPreferences = parseVisibilityPreferences(visibilityPreferencesJSON, user.VisibilityMode)

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

		var current models.User
		var currentAvatar sql.NullString
		var currentPhoneNumber sql.NullString
		var visibilityPreferencesJSON string
		err := db.QueryRow(`
			SELECT id, email, password_hash, name, avatar, bio, account_type, role, status,
				is_verified, phone_number, privacy_profile, visibility_mode, visibility_preferences, followers_count, following_count, created_at
			FROM users WHERE id = $1
		`, userID).Scan(
			&current.ID, &current.Email, &current.Password, &current.Name, &currentAvatar, &current.Bio,
			&current.AccountType, &current.Role, &current.Status, &current.IsVerified, &currentPhoneNumber,
			&current.PrivacyProfile, &current.VisibilityMode, &visibilityPreferencesJSON, &current.FollowersCount, &current.FollowingCount, &current.CreatedAt,
		)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}

		if currentAvatar.Valid {
			current.Avatar = &currentAvatar.String
		}
		if currentPhoneNumber.Valid {
			current.PhoneNumber = &currentPhoneNumber.String
		}
		current.VisibilityPreferences = parseVisibilityPreferences(visibilityPreferencesJSON, current.VisibilityMode)

		updatedName := current.Name
		updatedBio := current.Bio
		updatedAvatar := currentAvatar
		updatedPrivacyProfile := current.PrivacyProfile
		updatedVisibilityMode := strings.ToLower(current.VisibilityMode)
		updatedPreferences := current.VisibilityPreferences

		if req.Name != nil {
			updatedName = *req.Name
		}
		if req.Bio != nil {
			updatedBio = *req.Bio
		}
		if req.Avatar != nil {
			updatedAvatar = sql.NullString{String: *req.Avatar, Valid: strings.TrimSpace(*req.Avatar) != ""}
		}
		if req.PrivacyProfile != nil {
			updatedPrivacyProfile = *req.PrivacyProfile
		}
		if req.VisibilityMode != nil {
			updatedVisibilityMode = strings.ToLower(*req.VisibilityMode)
		}
		if req.VisibilityPreferences != nil {
			updatedPreferences = normalizeVisibilityPreferences(updatedVisibilityMode, req.VisibilityPreferences)
		}

		if current.AccountType == models.AccountTypeSeller {
			updatedPrivacyProfile = models.PrivacyPublic
			updatedVisibilityMode = "public"
			updatedPreferences = defaultVisibilityPreferences("public")
		}

		switch updatedVisibilityMode {
		case "private":
			updatedPrivacyProfile = models.PrivacyPrivate
			updatedPreferences = defaultVisibilityPreferences("private")
		case "custom":
			updatedPrivacyProfile = models.PrivacyPublic
			updatedPreferences = normalizeVisibilityPreferences(updatedVisibilityMode, updatedPreferences)
		default:
			updatedVisibilityMode = "public"
			updatedPrivacyProfile = models.PrivacyPublic
			updatedPreferences = defaultVisibilityPreferences("public")
		}

		updatedPreferencesJSON, err := json.Marshal(updatedPreferences)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to encode visibility settings"})
			return
		}

		_, err = db.Exec(`
			UPDATE users
			SET name = $1, bio = $2, avatar = $3, privacy_profile = $4, visibility_mode = $5, visibility_preferences = $6, updated_at = $7
			WHERE id = $8
		`, updatedName, updatedBio, updatedAvatar, updatedPrivacyProfile, updatedVisibilityMode, updatedPreferencesJSON, time.Now(), userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update profile"})
			return
		}

		var user models.User
		var updatedVisibilityPreferencesJSON string
		err = db.QueryRow(`
			SELECT id, email, password_hash, name, avatar, bio, account_type, role, status,
				is_verified, phone_number, privacy_profile, visibility_mode, visibility_preferences, followers_count, following_count, created_at
			FROM users WHERE id = $1
		`, userID).Scan(
			&user.ID, &user.Email, &user.Password, &user.Name, &user.Avatar, &user.Bio,
			&user.AccountType, &user.Role, &user.Status, &user.IsVerified, &user.PhoneNumber,
			&user.PrivacyProfile, &user.VisibilityMode, &updatedVisibilityPreferencesJSON, &user.FollowersCount, &user.FollowingCount, &user.CreatedAt,
		)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}

		user.VisibilityPreferences = parseVisibilityPreferences(updatedVisibilityPreferencesJSON, user.VisibilityMode)

		c.JSON(http.StatusOK, user)
	}
}

func GetUser(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("user_id")
		viewerID := c.GetString("user_id")

		var user models.User
		var visibilityPreferencesJSON string
		err := db.QueryRow(`
			SELECT id, email, password_hash, name, avatar, bio, account_type, role, status, 
				is_verified, phone_number, privacy_profile, visibility_mode, visibility_preferences, followers_count, following_count, created_at
			FROM users WHERE id = $1
		`, userID).Scan(
			&user.ID, &user.Email, &user.Password, &user.Name, &user.Avatar, &user.Bio,
			&user.AccountType, &user.Role, &user.Status, &user.IsVerified, &user.PhoneNumber,
			&user.PrivacyProfile, &user.VisibilityMode, &visibilityPreferencesJSON, &user.FollowersCount, &user.FollowingCount, &user.CreatedAt,
		)

		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}
		user.VisibilityPreferences = parseVisibilityPreferences(visibilityPreferencesJSON, user.VisibilityMode)

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
