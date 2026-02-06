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

type UserRole string

const (
	RoleConsumer UserRole = "consumer"
	RoleSeller   UserRole = "seller"
	RoleAdmin    UserRole = "admin"
)

type AccountStatus string

const (
	StatusActive    AccountStatus = "active"
	StatusInactive  AccountStatus = "inactive"
	StatusSuspended AccountStatus = "suspended"
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
	ID             string         `json:"id" db:"id"`
	Email          string         `json:"email" db:"email"`
	Password       string         `json:"-" db:"password"`
	Name           string         `json:"name" db:"name"`
	Avatar         *string        `json:"avatar,omitempty" db:"avatar"`
	Bio            string         `json:"bio" db:"bio"`
	AccountType    AccountType    `json:"account_type" db:"account_type"`
	Role           UserRole       `json:"role" db:"role"`
	Status         AccountStatus  `json:"status" db:"status"`
	IsVerified     bool           `json:"is_verified" db:"is_verified"`
	PhoneNumber    *string        `json:"phone_number,omitempty" db:"phone_number"`
	PrivacyProfile PrivacyProfile `json:"privacy_profile" db:"privacy_profile"`
	FollowersCount int            `json:"followers_count" db:"followers_count"`
	FollowingCount int            `json:"following_count" db:"following_count"`
	CreatedAt      time.Time      `json:"created_at" db:"created_at"`
}

type UserCreate struct {
	Email          string         `json:"email" binding:"required,email"`
	Password       string         `json:"password" binding:"required,min=6"`
	Name           string         `json:"name" binding:"required"`
	AccountType    AccountType    `json:"account_type" binding:"required,oneof=seller consumer"`
	Role           UserRole       `json:"role" binding:"required,oneof=consumer seller admin"`
	PhoneNumber    *string        `json:"phone_number,omitempty"`
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

	// Sync role with account_type if not explicitly set
	if uc.Role == "" {
		if uc.AccountType == AccountTypeSeller {
			uc.Role = RoleSeller
		} else {
			uc.Role = RoleConsumer
		}
	}

	// Ensure role matches account_type (sellers can't be consumers and vice versa)
	if uc.AccountType == AccountTypeSeller && uc.Role == RoleConsumer {
		return fmt.Errorf("seller account cannot have consumer role")
	}
	if uc.AccountType == AccountTypeConsumer && uc.Role == RoleSeller {
		return fmt.Errorf("consumer account cannot have seller role")
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
	ID           string    `json:"id" db:"id"`
	Title        string    `json:"title" db:"title"`
	Description  string    `json:"description" db:"description"`
	Price        float64   `json:"price" db:"price"`
	Images       []string  `json:"images" db:"images"`
	Category     string    `json:"category" db:"category"`
	Tags         []string  `json:"tags" db:"tags"`
	SellerID     string    `json:"seller_id" db:"seller_id"`
	SellerName   string    `json:"seller_name" db:"seller_name"`
	Rating       float64   `json:"rating" db:"rating"`
	ReviewsCount int       `json:"reviews_count" db:"reviews_count"`
	Views        int       `json:"views" db:"views"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
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
	ID            string          `json:"id" db:"id"`
	Title         string          `json:"title" db:"title"`
	Description   string          `json:"description" db:"description"`
	URL           string          `json:"url" db:"url"`
	Thumbnail     string          `json:"thumbnail" db:"thumbnail"`
	Duration      int             `json:"duration" db:"duration"`
	Views         int             `json:"views" db:"views"`
	Likes         int             `json:"likes" db:"likes"`
	CreatorID     string          `json:"creator_id" db:"creator_id"`
	CreatorName   string          `json:"creator_name" db:"creator_name"`
	CreatorAvatar *string         `json:"creator_avatar,omitempty" db:"creator_avatar"`
	Products      []ProductSimple `json:"products" db:"products"`
	CreatedAt     time.Time       `json:"created_at" db:"created_at"`
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
	ID            string          `json:"id" db:"id"`
	URL           string          `json:"url" db:"url"`
	Thumbnail     string          `json:"thumbnail" db:"thumbnail"`
	Caption       string          `json:"caption" db:"caption"`
	Views         int             `json:"views" db:"views"`
	Likes         int             `json:"likes" db:"likes"`
	CreatorID     string          `json:"creator_id" db:"creator_id"`
	CreatorName   string          `json:"creator_name" db:"creator_name"`
	CreatorAvatar *string         `json:"creator_avatar,omitempty" db:"creator_avatar"`
	Products      []ProductSimple `json:"products" db:"products"`
	CreatedAt     time.Time       `json:"created_at" db:"created_at"`
}

type ReelCreate struct {
	URL        string   `json:"url" binding:"required"`
	Thumbnail  string   `json:"thumbnail" binding:"required"`
	Caption    string   `json:"caption"`
	ProductIDs []string `json:"product_ids"`
}

type ProductSimple struct {
	ID    string  `json:"id" db:"id"`
	Title string  `json:"title" db:"title"`
	Price float64 `json:"price" db:"price"`
	Image string  `json:"image" db:"image"`
}

type CartItem struct {
	ProductID string  `json:"product_id" db:"product_id"`
	Title     string  `json:"title" db:"title"`
	Price     float64 `json:"price" db:"price"`
	Image     string  `json:"image" db:"image"`
	Quantity  int     `json:"quantity" db:"quantity"`
}

type Cart struct {
	UserID    string     `json:"user_id" db:"user_id"`
	Items     []CartItem `json:"items" db:"items"`
	UpdatedAt time.Time  `json:"updated_at" db:"updated_at"`
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
	ID             string    `json:"id" db:"id"`
	ConversationID string    `json:"conversation_id" db:"conversation_id"`
	SenderID       string    `json:"sender_id" db:"sender_id"`
	ReceiverID     string    `json:"receiver_id" db:"receiver_id"`
	Content        string    `json:"content" db:"content"`
	ProductID      *string   `json:"product_id,omitempty" db:"product_id"`
	CreatedAt      time.Time `json:"created_at" db:"created_at"`
	Read           bool      `json:"read" db:"read"`
}

type MessageCreate struct {
	ReceiverID string  `json:"receiver_id" binding:"required"`
	Content    string  `json:"content" binding:"required"`
	ProductID  *string `json:"product_id,omitempty"`
}

type Follow struct {
	FollowerID  string    `json:"follower_id" db:"follower_id"`
	FollowingID string    `json:"following_id" db:"following_id"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

// ============================================================================
// FOLLOW REQUEST MODEL (for Private accounts)
// ============================================================================

type FollowRequest struct {
	ID          string              `json:"id" db:"id"`
	RequesterID string              `json:"requester_id" db:"requester_id"`
	RequesteeID string              `json:"requestee_id" db:"requestee_id"`
	Status      FollowRequestStatus `json:"status" db:"status"`
	RequestedAt time.Time           `json:"requested_at" db:"requested_at"`
	RespondedAt *time.Time          `json:"responded_at,omitempty" db:"responded_at"`
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
	ID          string      `json:"id" db:"id"`
	UserID      string      `json:"user_id" db:"user_id"`
	OrderNumber string      `json:"order_number" db:"order_number"`
	Status      string      `json:"status" db:"status"`
	Subtotal    float64     `json:"subtotal" db:"subtotal"`
	Tax         float64     `json:"tax" db:"tax"`
	Shipping    float64     `json:"shipping" db:"shipping"`
	Discount    float64     `json:"discount" db:"discount"`
	Total       float64     `json:"total" db:"total"`
	IsPrivate   bool        `json:"is_private" db:"is_private"` // Privacy flag - defaults to false (public)
	Items       []OrderItem `json:"items,omitempty" db:"items"`
	CreatedAt   time.Time   `json:"created_at" db:"created_at"`
	CompletedAt *time.Time  `json:"completed_at,omitempty" db:"completed_at"`
}

type OrderItem struct {
	ID           string  `json:"id" db:"id"`
	ProductID    string  `json:"product_id" db:"product_id"`
	ProductTitle string  `json:"product_title" db:"product_title"`
	Quantity     int     `json:"quantity" db:"quantity"`
	UnitPrice    float64 `json:"unit_price" db:"unit_price"`
	Subtotal     float64 `json:"subtotal" db:"subtotal"`
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
	ID                 string    `json:"id" db:"id"`
	ProductID          string    `json:"product_id" db:"product_id"`
	UserID             string    `json:"user_id" db:"user_id"`
	Rating             int       `json:"rating" db:"rating"`
	ReviewTitle        string    `json:"review_title,omitempty" db:"review_title"`
	ReviewText         string    `json:"review_text,omitempty" db:"review_text"`
	IsVerifiedPurchase bool      `json:"is_verified_purchase" db:"is_verified_purchase"`
	IsPrivate          bool      `json:"is_private" db:"is_private"` // Privacy flag - defaults to false (public)
	HelpfulCount       int       `json:"helpful_count" db:"helpful_count"`
	CreatedAt          time.Time `json:"created_at" db:"created_at"`
	UpdatedAt          time.Time `json:"updated_at" db:"updated_at"`

	// Populated fields (not stored in DB)
	Username   string  `json:"username,omitempty" db:"-"`
	UserAvatar *string `json:"user_avatar,omitempty" db:"-"`
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
