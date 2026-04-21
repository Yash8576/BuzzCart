package handlers

import (
	"bytes"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	"image/png"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

func ProxyMediaHandler(c *gin.Context) {
	rawURL := strings.TrimSpace(c.Query("url"))
	if rawURL == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "url is required"})
		return
	}

	parsedURL, err := url.Parse(rawURL)
	if err != nil || parsedURL.Scheme != "https" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid media url"})
		return
	}

	host := strings.ToLower(parsedURL.Hostname())
	if host != "firebasestorage.googleapis.com" && host != "storage.googleapis.com" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "unsupported media host"})
		return
	}

	client := &http.Client{Timeout: 20 * time.Second}
	req, err := http.NewRequestWithContext(c.Request.Context(), http.MethodGet, rawURL, nil)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid media url"})
		return
	}

	resp, err := client.Do(req)
	if err != nil {
		log.Printf("[ProxyMedia] fetch failed for %q: %v", rawURL, err)
		c.JSON(http.StatusBadGateway, gin.H{"error": "failed to fetch media"})
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		c.JSON(resp.StatusCode, gin.H{"error": "media fetch failed"})
		return
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, 12*1024*1024))
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "failed to read media"})
		return
	}

	contentType := http.DetectContentType(body)
	if !strings.HasPrefix(contentType, "image/") {
		c.JSON(http.StatusUnsupportedMediaType, gin.H{"error": "media is not an image"})
		return
	}

	if contentType == "image/webp" || contentType == "image/bmp" {
		c.Header("Cache-Control", "public, max-age=3600")
		c.Data(http.StatusOK, contentType, body)
		return
	}

	img, _, err := image.Decode(bytes.NewReader(body))
	if err != nil {
		log.Printf("[ProxyMedia] decode failed for %q: %v", rawURL, err)
		c.JSON(http.StatusUnsupportedMediaType, gin.H{"error": "image cannot be decoded"})
		return
	}

	var encoded bytes.Buffer
	if err := png.Encode(&encoded, img); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to encode image"})
		return
	}

	c.Header("Cache-Control", "public, max-age=3600")
	c.Data(http.StatusOK, "image/png", encoded.Bytes())
}
