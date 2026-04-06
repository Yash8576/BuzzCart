package handlers

import (
	"buzzcart/internal/cache"
	"buzzcart/internal/config"
	"buzzcart/internal/models"
	"buzzcart/internal/utils"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

const (
	maxFailedLoginAttempts = 5
	loginLockoutDuration   = 1 * time.Minute
	loginRateLimitTTL      = 30 * time.Minute
	defaultVisibilityMode  = "public"
	defaultVisibilityPrefs = `{"photos": true, "videos": true, "reels": true, "purchases": true}`
)

type loginAttemptState struct {
	FailedAttempts  int   `json:"failed_attempts"`
	LockedUntilUnix int64 `json:"locked_until_unix"`
}

var (
	loginAttemptStateMu  sync.RWMutex
	loginAttemptStateMap = make(map[string]loginAttemptState)
)

func loginRateLimitKey(email, clientIP string) string {
	normalizedEmail := strings.ToLower(strings.TrimSpace(email))
	return fmt.Sprintf("auth:login:attempts:%s:%s", normalizedEmail, clientIP)
}

func getLoginAttemptState(ctx context.Context, key string) loginAttemptState {
	if client := cache.GetClient(); client != nil {
		value, err := client.Get(ctx, key).Result()
		if err == nil {
			var state loginAttemptState
			if json.Unmarshal([]byte(value), &state) == nil {
				return state
			}
		}
		if err != nil && err != redis.Nil {
			// Fall back to in-memory state when Redis is unavailable.
		}
	}

	loginAttemptStateMu.RLock()
	state := loginAttemptStateMap[key]
	loginAttemptStateMu.RUnlock()
	return state
}

func saveLoginAttemptState(ctx context.Context, key string, state loginAttemptState) {
	if client := cache.GetClient(); client != nil {
		payload, err := json.Marshal(state)
		if err == nil {
			if client.Set(ctx, key, payload, loginRateLimitTTL).Err() == nil {
				return
			}
		}
	}

	loginAttemptStateMu.Lock()
	loginAttemptStateMap[key] = state
	loginAttemptStateMu.Unlock()
}

func clearLoginAttemptState(ctx context.Context, key string) {
	if client := cache.GetClient(); client != nil {
		if client.Del(ctx, key).Err() == nil {
			return
		}
	}

	loginAttemptStateMu.Lock()
	delete(loginAttemptStateMap, key)
	loginAttemptStateMu.Unlock()
}

func writeTooManyAttemptsResponse(c *gin.Context, retryAfter int64) {
	if retryAfter < 1 {
		retryAfter = int64(loginLockoutDuration.Seconds())
	}

	c.Header("Retry-After", fmt.Sprintf("%d", retryAfter))
	c.JSON(http.StatusTooManyRequests, gin.H{
		"error":               "Too many attempts-try again in 1 minute.",
		"retry_after_seconds": retryAfter,
	})
}

func registerFailedLoginAttempt(c *gin.Context, key string, state *loginAttemptState) bool {
	state.FailedAttempts++
	if state.FailedAttempts >= maxFailedLoginAttempts {
		state.LockedUntilUnix = time.Now().Add(loginLockoutDuration).Unix()
		saveLoginAttemptState(c.Request.Context(), key, *state)
		writeTooManyAttemptsResponse(c, int64(loginLockoutDuration.Seconds()))
		return true
	}

	saveLoginAttemptState(c.Request.Context(), key, *state)
	return false
}

func buildUserSelectQuery(filterColumn string) string {
	return fmt.Sprintf(`
		SELECT id, email, password_hash, name, avatar,
			COALESCE(bio, ''),
			COALESCE(account_type::text, 'consumer')::account_type,
			COALESCE(role::text, 'consumer')::user_role,
			COALESCE(status::text, 'active')::account_status,
			COALESCE(is_verified, false),
			phone_number,
			COALESCE(privacy_profile::text, 'public')::privacy_profile,
			'%s' AS visibility_mode,
			'%s' AS visibility_preferences,
			COALESCE(followers_count, 0),
			COALESCE(following_count, 0),
			created_at
		FROM users WHERE %s = $1
	`, defaultVisibilityMode, defaultVisibilityPrefs, filterColumn)
}

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

		rateLimitKey := loginRateLimitKey(req.Email, c.ClientIP())
		attemptState := getLoginAttemptState(c.Request.Context(), rateLimitKey)
		nowUnix := time.Now().Unix()
		if attemptState.LockedUntilUnix > nowUnix {
			retryAfter := attemptState.LockedUntilUnix - nowUnix
			writeTooManyAttemptsResponse(c, retryAfter)
			return
		}

		// Find user
		var user models.User
		var visibilityPreferencesJSON string
		err := db.QueryRow(buildUserSelectQuery("email"), req.Email).Scan(
			&user.ID, &user.Email, &user.Password, &user.Name, &user.Avatar, &user.Bio,
			&user.AccountType, &user.Role, &user.Status, &user.IsVerified, &user.PhoneNumber,
			&user.PrivacyProfile, &user.VisibilityMode, &visibilityPreferencesJSON, &user.FollowersCount, &user.FollowingCount, &user.CreatedAt,
		)

		if err == sql.ErrNoRows {
			if registerFailedLoginAttempt(c, rateLimitKey, &attemptState) {
				return
			}
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
			return
		} else if err != nil {
			log.Printf("[Auth Login] Database query failed for email=%s: %v", req.Email, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}

		user.VisibilityPreferences = parseVisibilityPreferences(visibilityPreferencesJSON, user.VisibilityMode)
		// Verify password
		if !utils.VerifyPassword(req.Password, user.Password) {
			if registerFailedLoginAttempt(c, rateLimitKey, &attemptState) {
				return
			}
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
			return
		}

		clearLoginAttemptState(c.Request.Context(), rateLimitKey)

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
		err := db.QueryRow(buildUserSelectQuery("id"), userID).Scan(
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
		err := db.QueryRow(buildUserSelectQuery("id"), userID).Scan(
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
		err = db.QueryRow(buildUserSelectQuery("id"), userID).Scan(
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
		err := db.QueryRow(buildUserSelectQuery("id"), userID).Scan(
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
