package models

import (
	"fmt"
	"time"
)

// ============================================================================
// ENUMS - Match PostgreSQL ENUM types
// ============================================================================

type AccountType string

const (
	AccountTypeSeller   AccountType = "seller"
	AccountTypeConsumer AccountType = "consumer"
)

type PrivacyProfile string

const (
	PrivacyPublic  PrivacyProfile = "public"
	PrivacyPrivate PrivacyProfile = "private"
)

type FollowRequestStatus string

const (
	FollowRequestPending  FollowRequestStatus = "pending"
	FollowRequestAccepted FollowRequestStatus = "accepted"
	FollowRequestRejected FollowRequestStatus = "rejected"
)

// ============================================================================
// USER MODELS
// ============================================================================

type User struct {
	ID             string         `json:"id" bson:"id"`
	Email          string         `json:"email" bson:"email"`
	Password       string         `json:"-" bson:"password"`
	Name           string         `json:"name" bson:"name"`
	Avatar         *string        `json:"avatar,omitempty" bson:"avatar,omitempty"`
	Bio            string         `json:"bio" bson:"bio"`
	AccountType    AccountType    `json:"account_type" bson:"account_type"`
	PrivacyProfile PrivacyProfile `json:"privacy_profile" bson:"privacy_profile"`
	FollowersCount int            `json:"followers_count" bson:"followers_count"`
	FollowingCount int            `json:"following_count" bson:"following_count"`
	CreatedAt      time.Time      `json:"created_at" bson:"created_at"`
}

type UserCreate struct {
	Email          string         `json:"email" binding:"required,email"`
	Password       string         `json:"password" binding:"required,min=6"`
	Name           string         `json:"name" binding:"required"`
	AccountType    AccountType    `json:"account_type" binding:"required,oneof=seller consumer"`
	PrivacyProfile PrivacyProfile `json:"privacy_profile" binding:"required_if=AccountType consumer,oneof=public private"`
}

// Validate ensures business rules are enforced
func (uc *UserCreate) Validate() error {
	// Seller accounts must always be public
	if uc.AccountType == AccountTypeSeller && uc.PrivacyProfile != PrivacyPublic {
		uc.PrivacyProfile = PrivacyPublic // Force public for sellers
	}

	// Consumer accounts must specify privacy
	if uc.AccountType == AccountTypeConsumer && uc.PrivacyProfile == "" {
		return fmt.Errorf("consumers must specify privacy_profile (public or private)")
	}

	return nil
}

type UserLogin struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type ProfileUpdate struct {
	Name   *string `json:"name,omitempty"`
	Bio    *string `json:"bio,omitempty"`
	Avatar *string `json:"avatar,omitempty"`
}

type TokenResponse struct {
	AccessToken string `json:"access_token"`
	TokenType   string `json:"token_type"`
	User        User   `json:"user"`
}

type Product struct {
	ID           string    `json:"id" bson:"id"`
	Title        string    `json:"title" bson:"title"`
	Description  string    `json:"description" bson:"description"`
	Price        float64   `json:"price" bson:"price"`
	Images       []string  `json:"images" bson:"images"`
	Category     string    `json:"category" bson:"category"`
	Tags         []string  `json:"tags" bson:"tags"`
	SellerID     string    `json:"seller_id" bson:"seller_id"`
	SellerName   string    `json:"seller_name" bson:"seller_name"`
	Rating       float64   `json:"rating" bson:"rating"`
	ReviewsCount int       `json:"reviews_count" bson:"reviews_count"`
	Views        int       `json:"views" bson:"views"`
	CreatedAt    time.Time `json:"created_at" bson:"created_at"`
}

type ProductCreate struct {
	Title       string   `json:"title" binding:"required"`
	Description string   `json:"description" binding:"required"`
	Price       float64  `json:"price" binding:"required,gt=0"`
	Images      []string `json:"images"`
	Category    string   `json:"category"`
	Tags        []string `json:"tags"`
}

type Video struct {
	ID            string          `json:"id" bson:"id"`
	Title         string          `json:"title" bson:"title"`
	Description   string          `json:"description" bson:"description"`
	URL           string          `json:"url" bson:"url"`
	Thumbnail     string          `json:"thumbnail" bson:"thumbnail"`
	Duration      int             `json:"duration" bson:"duration"`
	Views         int             `json:"views" bson:"views"`
	Likes         int             `json:"likes" bson:"likes"`
	CreatorID     string          `json:"creator_id" bson:"creator_id"`
	CreatorName   string          `json:"creator_name" bson:"creator_name"`
	CreatorAvatar *string         `json:"creator_avatar,omitempty" bson:"creator_avatar,omitempty"`
	Products      []ProductSimple `json:"products" bson:"products"`
	CreatedAt     time.Time       `json:"created_at" bson:"created_at"`
}

type VideoCreate struct {
	Title       string   `json:"title" binding:"required"`
	Description string   `json:"description" binding:"required"`
	URL         string   `json:"url" binding:"required"`
	Thumbnail   string   `json:"thumbnail" binding:"required"`
	Duration    int      `json:"duration"`
	ProductIDs  []string `json:"product_ids"`
}

type Reel struct {
	ID            string          `json:"id" bson:"id"`
	URL           string          `json:"url" bson:"url"`
	Thumbnail     string          `json:"thumbnail" bson:"thumbnail"`
	Caption       string          `json:"caption" bson:"caption"`
	Views         int             `json:"views" bson:"views"`
	Likes         int             `json:"likes" bson:"likes"`
	CreatorID     string          `json:"creator_id" bson:"creator_id"`
	CreatorName   string          `json:"creator_name" bson:"creator_name"`
	CreatorAvatar *string         `json:"creator_avatar,omitempty" bson:"creator_avatar,omitempty"`
	Products      []ProductSimple `json:"products" bson:"products"`
	CreatedAt     time.Time       `json:"created_at" bson:"created_at"`
}

type ReelCreate struct {
	URL        string   `json:"url" binding:"required"`
	Thumbnail  string   `json:"thumbnail" binding:"required"`
	Caption    string   `json:"caption"`
	ProductIDs []string `json:"product_ids"`
}

type ProductSimple struct {
	ID    string  `json:"id" bson:"id"`
	Title string  `json:"title" bson:"title"`
	Price float64 `json:"price" bson:"price"`
	Image string  `json:"image" bson:"image"`
}

type CartItem struct {
	ProductID string  `json:"product_id" bson:"product_id"`
	Title     string  `json:"title" bson:"title"`
	Price     float64 `json:"price" bson:"price"`
	Image     string  `json:"image" bson:"image"`
	Quantity  int     `json:"quantity" bson:"quantity"`
}

type Cart struct {
	UserID    string     `json:"user_id" bson:"user_id"`
	Items     []CartItem `json:"items" bson:"items"`
	UpdatedAt time.Time  `json:"updated_at" bson:"updated_at"`
}

type CartResponse struct {
	Items     []CartItem `json:"items"`
	Subtotal  float64    `json:"subtotal"`
	Total     float64    `json:"total"`
	ItemCount int        `json:"item_count"`
}

type CartItemAdd struct {
	ProductID string `json:"product_id" binding:"required"`
	Quantity  int    `json:"quantity"`
}

type Message struct {
	ID             string    `json:"id" bson:"id"`
	ConversationID string    `json:"conversation_id" bson:"conversation_id"`
	SenderID       string    `json:"sender_id" bson:"sender_id"`
	ReceiverID     string    `json:"receiver_id" bson:"receiver_id"`
	Content        string    `json:"content" bson:"content"`
	ProductID      *string   `json:"product_id,omitempty" bson:"product_id,omitempty"`
	CreatedAt      time.Time `json:"created_at" bson:"created_at"`
	Read           bool      `json:"read" bson:"read"`
}

type MessageCreate struct {
	ReceiverID string  `json:"receiver_id" binding:"required"`
	Content    string  `json:"content" binding:"required"`
	ProductID  *string `json:"product_id,omitempty"`
}

type Follow struct {
	FollowerID  string    `json:"follower_id" bson:"follower_id"`
	FollowingID string    `json:"following_id" bson:"following_id"`
	CreatedAt   time.Time `json:"created_at" bson:"created_at"`
}

// ============================================================================
// FOLLOW REQUEST MODEL (for Private accounts)
// ============================================================================

type FollowRequest struct {
	ID          string              `json:"id" bson:"id"`
	RequesterID string              `json:"requester_id" bson:"requester_id"`
	RequesteeID string              `json:"requestee_id" bson:"requestee_id"`
	Status      FollowRequestStatus `json:"status" bson:"status"`
	RequestedAt time.Time           `json:"requested_at" bson:"requested_at"`
	RespondedAt *time.Time          `json:"responded_at,omitempty" bson:"responded_at,omitempty"`
}

type FollowRequestCreate struct {
	RequesteeID string `json:"requestee_id" binding:"required"`
}

type FollowRequestRespond struct {
	Action string `json:"action" binding:"required,oneof=accept reject"`
}

// ============================================================================
// ORDER MODEL (with Privacy flag)
// ============================================================================

type Order struct {
	ID          string      `json:"id" bson:"id"`
	UserID      string      `json:"user_id" bson:"user_id"`
	OrderNumber string      `json:"order_number" bson:"order_number"`
	Status      string      `json:"status" bson:"status"`
	Subtotal    float64     `json:"subtotal" bson:"subtotal"`
	Tax         float64     `json:"tax" bson:"tax"`
	Shipping    float64     `json:"shipping" bson:"shipping"`
	Discount    float64     `json:"discount" bson:"discount"`
	Total       float64     `json:"total" bson:"total"`
	IsPrivate   bool        `json:"is_private" bson:"is_private"` // Privacy flag - defaults to false (public)
	Items       []OrderItem `json:"items,omitempty" bson:"items,omitempty"`
	CreatedAt   time.Time   `json:"created_at" bson:"created_at"`
	CompletedAt *time.Time  `json:"completed_at,omitempty" bson:"completed_at,omitempty"`
}

type OrderItem struct {
	ID           string  `json:"id" bson:"id"`
	ProductID    string  `json:"product_id" bson:"product_id"`
	ProductTitle string  `json:"product_title" bson:"product_title"`
	Quantity     int     `json:"quantity" bson:"quantity"`
	UnitPrice    float64 `json:"unit_price" bson:"unit_price"`
	Subtotal     float64 `json:"subtotal" bson:"subtotal"`
}

type OrderCreate struct {
	Items     []OrderItemCreate `json:"items" binding:"required,min=1"`
	IsPrivate bool              `json:"is_private"` // Optional: user can mark order as private, defaults to false
	// Shipping and payment details would go here
}

type OrderItemCreate struct {
	ProductID string `json:"product_id" binding:"required"`
	Quantity  int    `json:"quantity" binding:"required,min=1"`
}

type OrderUpdatePrivacy struct {
	IsPrivate bool `json:"is_private" binding:"required"`
}

// ============================================================================
// REVIEW MODEL (with Privacy flag)
// ============================================================================

type Review struct {
	ID                 string    `json:"id" bson:"id"`
	ProductID          string    `json:"product_id" bson:"product_id"`
	UserID             string    `json:"user_id" bson:"user_id"`
	Rating             int       `json:"rating" bson:"rating"`
	ReviewTitle        string    `json:"review_title,omitempty" bson:"review_title,omitempty"`
	ReviewText         string    `json:"review_text,omitempty" bson:"review_text,omitempty"`
	IsVerifiedPurchase bool      `json:"is_verified_purchase" bson:"is_verified_purchase"`
	IsPrivate          bool      `json:"is_private" bson:"is_private"` // Privacy flag - defaults to false (public)
	HelpfulCount       int       `json:"helpful_count" bson:"helpful_count"`
	CreatedAt          time.Time `json:"created_at" bson:"created_at"`
	UpdatedAt          time.Time `json:"updated_at" bson:"updated_at"`

	// Populated fields (not stored in DB)
	Username   string  `json:"username,omitempty" bson:"-"`
	UserAvatar *string `json:"user_avatar,omitempty" bson:"-"`
}

type ReviewCreate struct {
	ProductID   string `json:"product_id" binding:"required"`
	Rating      int    `json:"rating" binding:"required,min=1,max=5"`
	ReviewTitle string `json:"review_title,omitempty"`
	ReviewText  string `json:"review_text,omitempty"`
	IsPrivate   bool   `json:"is_private"` // Optional: user can mark review as private, defaults to false
}

type ReviewUpdatePrivacy struct {
	IsPrivate bool `json:"is_private" binding:"required"`
}

type SearchResponse struct {
	Products []Product `json:"products"`
	Videos   []Video   `json:"videos"`
	Reels    []Reel    `json:"reels"`
	Users    []User    `json:"users"`
}
