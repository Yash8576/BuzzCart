package handlers

import (
	"buzzcart/internal/models"
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func SendMessage(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.MessageCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Find existing conversation between these two users
		var conversationID string
		err := db.QueryRow(
			`SELECT conversation_id FROM messages 
			 WHERE (sender_id = $1 AND receiver_id = $2) OR (sender_id = $2 AND receiver_id = $1) 
			 LIMIT 1`,
			userID, req.ReceiverID,
		).Scan(&conversationID)

		// If no existing conversation found, create a new ID
		if err == sql.ErrNoRows {
			conversationID = uuid.New().String()
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check existing conversation"})
			return
		}

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

		_, err = db.Exec(
			`INSERT INTO messages (id, conversation_id, sender_id, receiver_id, content, product_id, created_at, read) 
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
			message.ID, message.ConversationID, message.SenderID, message.ReceiverID,
			message.Content, message.ProductID, message.CreatedAt, message.Read,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send message"})
			return
		}

		c.JSON(http.StatusOK, message)
	}
}

func GetConversations(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		// Get all messages where user is sender or receiver, grouped by conversation
		rows, err := db.Query(
			`SELECT DISTINCT ON (conversation_id) 
			 id, conversation_id, sender_id, receiver_id, content, product_id, created_at, read 
			 FROM messages 
			 WHERE sender_id = $1 OR receiver_id = $1 
			 ORDER BY conversation_id, created_at DESC`,
			userID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch conversations"})
			return
		}
		defer rows.Close()

		var conversations []gin.H
		for rows.Next() {
			var msg models.Message
			err := rows.Scan(
				&msg.ID, &msg.ConversationID, &msg.SenderID, &msg.ReceiverID,
				&msg.Content, &msg.ProductID, &msg.CreatedAt, &msg.Read,
			)
			if err != nil {
				continue
			}
			conversations = append(conversations, gin.H{
				"id":           msg.ConversationID,
				"last_message": msg,
				"updated_at":   msg.CreatedAt,
			})
		}

		if conversations == nil {
			conversations = []gin.H{}
		}

		c.JSON(http.StatusOK, conversations)
	}
}

func GetMessages(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		conversationID := c.Param("conversation_id")

		rows, err := db.Query(
			`SELECT id, conversation_id, sender_id, receiver_id, content, product_id, created_at, read 
			 FROM messages WHERE conversation_id = $1 ORDER BY created_at ASC`,
			conversationID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch messages"})
			return
		}
		defer rows.Close()

		var messages []models.Message
		for rows.Next() {
			var msg models.Message
			err := rows.Scan(
				&msg.ID, &msg.ConversationID, &msg.SenderID, &msg.ReceiverID,
				&msg.Content, &msg.ProductID, &msg.CreatedAt, &msg.Read,
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode messages"})
				return
			}
			messages = append(messages, msg)
		}

		if messages == nil {
			messages = []models.Message{}
		}

		c.JSON(http.StatusOK, messages)
	}
}
