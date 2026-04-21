package config

import (
	"os"
	"strconv"
)

type Config struct {
	DatabaseURL  string
	JWTSecret    string
	Port         string
	OpenAIAPIKey string
	RedisURL     string
	Storage      StorageConfig
}

type StorageConfig struct {
	Bucket          string
	ProjectID       string
	Location        string
	CredentialsFile string
	PublicBaseURL   string
}

func Load() *Config {
	return &Config{
		DatabaseURL:  getEnv("DATABASE_URL", "postgres://like2share_user:like2share_dev_password@localhost:5432/like2share_db?sslmode=disable"),
		JWTSecret:    getEnv("JWT_SECRET", "buzz-social-cart-secret-key-2024"),
		Port:         getEnv("PORT", "8000"),
		OpenAIAPIKey: getEnv("OPENAI_API_KEY", ""),
		RedisURL:     getEnv("REDIS_URL", "redis://localhost:6379/0"),
		Storage: StorageConfig{
			Bucket:          getEnv("FIREBASE_STORAGE_BUCKET", getEnv("MINIO_BUCKET", "buzzcart-media")),
			ProjectID:       getEnv("FIREBASE_PROJECT_ID", getEnv("GOOGLE_CLOUD_PROJECT", "")),
			Location:        getEnv("FIREBASE_STORAGE_LOCATION", "us-east4"),
			CredentialsFile: getEnv("FIREBASE_STORAGE_CREDENTIALS_FILE", getEnv("GOOGLE_APPLICATION_CREDENTIALS", "")),
			PublicBaseURL:   getEnv("FIREBASE_STORAGE_PUBLIC_BASE_URL", "https://firebasestorage.googleapis.com/v0/b"),
		},
	}
}

func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

func getEnvBool(key string, defaultValue bool) bool {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	boolVal, err := strconv.ParseBool(value)
	if err != nil {
		return defaultValue
	}
	return boolVal
}
