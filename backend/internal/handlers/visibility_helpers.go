package handlers

import (
	"encoding/json"
	"strings"
)

const (
	contentBucketPhotos    = "photos"
	contentBucketVideos    = "videos"
	contentBucketReels     = "reels"
	contentBucketPurchases = "purchases"
)

func defaultVisibilityPreferences(mode string) map[string]bool {
	preferences := map[string]bool{
		contentBucketPhotos:    true,
		contentBucketVideos:    true,
		contentBucketReels:     true,
		contentBucketPurchases: true,
	}

	if strings.ToLower(mode) == "private" {
		preferences[contentBucketPhotos] = false
		preferences[contentBucketVideos] = false
		preferences[contentBucketReels] = false
		preferences[contentBucketPurchases] = false
	}

	return preferences
}

func normalizeVisibilityPreferences(mode string, preferences map[string]bool) map[string]bool {
	normalized := defaultVisibilityPreferences(mode)
	for key, value := range preferences {
		normalized[strings.ToLower(key)] = value
	}

	switch strings.ToLower(mode) {
	case "public":
		normalized[contentBucketPhotos] = true
		normalized[contentBucketVideos] = true
		normalized[contentBucketReels] = true
		normalized[contentBucketPurchases] = true
	case "private":
		normalized[contentBucketPhotos] = false
		normalized[contentBucketVideos] = false
		normalized[contentBucketReels] = false
		normalized[contentBucketPurchases] = false
	}

	return normalized
}

func parseVisibilityPreferences(raw string, mode string) map[string]bool {
	if strings.TrimSpace(raw) == "" {
		return defaultVisibilityPreferences(mode)
	}

	var preferences map[string]bool
	if err := json.Unmarshal([]byte(raw), &preferences); err != nil {
		return defaultVisibilityPreferences(mode)
	}

	return normalizeVisibilityPreferences(mode, preferences)
}

func visibilityBucketAllowed(mode string, rawPreferences string, bucket string, isOwnProfile bool) bool {
	if isOwnProfile {
		return true
	}

	switch strings.ToLower(mode) {
	case "private":
		return false
	case "custom":
		preferences := parseVisibilityPreferences(rawPreferences, mode)
		allowed, ok := preferences[strings.ToLower(bucket)]
		if !ok {
			return true
		}
		return allowed
	default:
		return true
	}
}
