package config

import "os"

type Config struct {
	MongoURL      string
	DBName        string
	JWTSecret     string
	Port          string
	OpenAIAPIKey  string
}

func Load() *Config {
	return &Config{
		MongoURL:     getEnv("MONGO_URL", "mongodb://localhost:27017"),
		DBName:       getEnv("DB_NAME", "buzzcart_dev"),
		JWTSecret:    getEnv("JWT_SECRET", "buzz-social-cart-secret-key-2024"),
		Port:         getEnv("PORT", "8000"),
		OpenAIAPIKey: getEnv("OPENAI_API_KEY", ""),
	}
}

func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}
