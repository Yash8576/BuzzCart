package handlers

import (
	"buzzcart/internal/models"
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func SendMessage(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.MessageCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Create or get conversation ID
		conversationID := uuid.New().String()

		message := models.Message{
			ID:             uuid.New().String(),
			ConversationID: conversationID,
			SenderID:       userID,
			ReceiverID:     req.ReceiverID,
			Content:        req.Content,
			ProductID:      req.ProductID,
			CreatedAt:      time.Now(),
			Read:           false,
		}

		_, err := db.Collection("messages").InsertOne(context.Background(), message)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send message"})
			return
		}

		c.JSON(http.StatusOK, message)
	}
}

func GetConversations(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		// Get all messages where user is sender or receiver
		cursor, err := db.Collection("messages").Find(
			context.Background(),
			bson.M{"$or": []bson.M{
				{"sender_id": userID},
				{"receiver_id": userID},
			}},
			options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}),
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch conversations"})
			return
		}
		defer cursor.Close(context.Background())

		var messages []models.Message
		if err = cursor.All(context.Background(), &messages); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode messages"})
			return
		}

		// Group by conversation
		conversations := make(map[string]models.Message)
		for _, msg := range messages {
			if _, exists := conversations[msg.ConversationID]; !exists {
				conversations[msg.ConversationID] = msg
			}
		}

		result := []gin.H{}
		for _, msg := range conversations {
			result = append(result, gin.H{
				"id":           msg.ConversationID,
				"last_message": msg,
				"updated_at":   msg.CreatedAt,
			})
		}

		c.JSON(http.StatusOK, result)
	}
}

func GetMessages(db *mongo.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		conversationID := c.Param("conversation_id")

		cursor, err := db.Collection("messages").Find(
			context.Background(),
			bson.M{"conversation_id": conversationID},
			options.Find().SetSort(bson.D{{Key: "created_at", Value: 1}}),
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch messages"})
			return
		}
		defer cursor.Close(context.Background())

		var messages []models.Message
		if err = cursor.All(context.Background(), &messages); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode messages"})
			return
		}

		if messages == nil {
			messages = []models.Message{}
		}

		c.JSON(http.StatusOK, messages)
	}
}
