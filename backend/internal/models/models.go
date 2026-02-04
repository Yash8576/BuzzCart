package models

import "time"

type User struct {
	ID             string    `json:"id" bson:"id"`
	Email          string    `json:"email" bson:"email"`
	Password       string    `json:"-" bson:"password"`
	Name           string    `json:"name" bson:"name"`
	Avatar         *string   `json:"avatar,omitempty" bson:"avatar,omitempty"`
	Bio            string    `json:"bio" bson:"bio"`
	FollowersCount int       `json:"followers_count" bson:"followers_count"`
	FollowingCount int       `json:"following_count" bson:"following_count"`
	CreatedAt      time.Time `json:"created_at" bson:"created_at"`
}

type UserCreate struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
	Name     string `json:"name" binding:"required"`
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
	ID          string  `json:"id" bson:"id"`
	Title       string  `json:"title" bson:"title"`
	Price       float64 `json:"price" bson:"price"`
	Image       string  `json:"image" bson:"image"`
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

type SearchResponse struct {
	Products []Product `json:"products"`
	Videos   []Video   `json:"videos"`
	Reels    []Reel    `json:"reels"`
	Users    []User    `json:"users"`
}
