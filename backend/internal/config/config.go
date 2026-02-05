package config

import (
	"os"
	"strconv"
)

type Config struct {
	MongoURL     string
	DBName       string
	JWTSecret    string
	Port         string
	OpenAIAPIKey string
	MinIO        MinIOConfig
}

type MinIOConfig struct {
	Endpoint  string
	AccessKey string
	SecretKey string
	UseSSL    bool
	Bucket    string
}

func Load() *Config {
	return &Config{
		MongoURL:     getEnv("MONGO_URL", "mongodb://localhost:27017"),
		DBName:       getEnv("DB_NAME", "buzzcart_dev"),
		JWTSecret:    getEnv("JWT_SECRET", "buzz-social-cart-secret-key-2024"),
		Port:         getEnv("PORT", "8000"),
		OpenAIAPIKey: getEnv("OPENAI_API_KEY", ""),
		MinIO: MinIOConfig{
			Endpoint:  getEnv("MINIO_ENDPOINT", "localhost:9000"),
			AccessKey: getEnv("MINIO_ACCESS_KEY", "minioadmin"),
			SecretKey: getEnv("MINIO_SECRET_KEY", "minioadmin123"),
			UseSSL:    getEnvBool("MINIO_USE_SSL", false),
			Bucket:    getEnv("MINIO_BUCKET", "buzzcart-media"),
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
