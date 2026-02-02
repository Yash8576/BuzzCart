# Buzz Social Cart - API Design & Contracts

## Base URL
- Development: `http://localhost:8080/api/v1`
- Production: `https://api.buzzsocialcart.com/api/v1`

## Authentication
All authenticated endpoints require JWT token in header:
```
Authorization: Bearer <jwt_token>
```

---

## 1. AUTHENTICATION & USER MANAGEMENT

### POST /auth/signup
Create new user account

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "password_confirm": "SecurePass123!",
  "username": "johndoe",
  "role": "consumer"
}
```

**Response (201):**
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "username": "johndoe",
    "role": "consumer",
    "created_at": "2026-01-29T10:00:00Z"
  },
  "token": "jwt_token_here",
  "expires_in": 86400
}
```

**Errors:**
- 400: Validation error (email format, password strength, username taken)
- 409: Email already exists

---

### POST /auth/login
Authenticate existing user

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

**Response (200):**
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "username": "johndoe",
    "role": "consumer",
    "profile": {
      "display_name": "John Doe",
      "profile_image_url": "https://..."
    }
  },
  "token": "jwt_token_here",
  "expires_in": 86400
}
```

**Errors:**
- 401: Invalid credentials
- 403: Account deactivated

---

### POST /auth/logout
Invalidate current session (requires auth)

**Request:** Empty body

**Response (200):**
```json
{
  "message": "Logged out successfully"
}
```

---

### POST /auth/refresh
Refresh JWT token

**Request:**
```json
{
  "refresh_token": "refresh_token_here"
}
```

**Response (200):**
```json
{
  "token": "new_jwt_token",
  "expires_in": 86400
}
```

---

### GET /auth/me
Get current user info (requires auth)

**Response (200):**
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "username": "johndoe",
  "role": "consumer",
  "profile": {
    "display_name": "John Doe",
    "bio": "Love shopping!",
    "profile_image_url": "https://...",
    "follower_count": 120,
    "following_count": 85
  },
  "settings": {
    "theme_mode": "dark",
    "notifications_enabled": true
  }
}
```

---

## 2. USER PROFILES

### GET /users/:userId
Get public profile

**Response (200):**
```json
{
  "id": "uuid",
  "username": "johndoe",
  "profile": {
    "display_name": "John Doe",
    "bio": "Content creator and seller",
    "profile_image_url": "https://...",
    "cover_image_url": "https://...",
    "location": "San Francisco, CA",
    "website": "https://johndoe.com"
  },
  "stats": {
    "follower_count": 1250,
    "following_count": 340,
    "content_count": 45,
    "product_count": 12
  },
  "is_following": false,
  "is_blocked": false
}
```

---

### PUT /users/profile
Update own profile (requires auth)

**Request:**
```json
{
  "display_name": "John Doe",
  "bio": "Updated bio",
  "profile_image_url": "https://...",
  "location": "Los Angeles, CA",
  "privacy_mode": "public"
}
```

**Response (200):**
```json
{
  "message": "Profile updated successfully",
  "profile": { /* updated profile */ }
}
```

---

### POST /users/:userId/follow
Follow a user (requires auth)

**Response (200):**
```json
{
  "message": "Successfully followed user",
  "is_following": true
}
```

---

### DELETE /users/:userId/follow
Unfollow a user (requires auth)

**Response (200):**
```json
{
  "message": "Successfully unfollowed user",
  "is_following": false
}
```

---

### GET /users/:userId/followers
Get user's followers

**Query Params:**
- `limit`: int (default 20, max 100)
- `offset`: int (default 0)

**Response (200):**
```json
{
  "followers": [
    {
      "id": "uuid",
      "username": "follower1",
      "display_name": "Follower One",
      "profile_image_url": "https://...",
      "followed_at": "2026-01-20T10:00:00Z"
    }
  ],
  "total": 1250,
  "limit": 20,
  "offset": 0
}
```

---

## 3. PRODUCTS & SHOPPING

### GET /products
Get product list with filters

**Query Params:**
- `category_id`: uuid
- `seller_id`: uuid
- `min_price`: decimal
- `max_price`: decimal
- `sort`: string (price_asc, price_desc, newest, popular, rating)
- `search`: string
- `limit`: int (default 20, max 100)
- `offset`: int (default 0)

**Response (200):**
```json
{
  "products": [
    {
      "id": "uuid",
      "seller_id": "uuid",
      "seller_username": "seller1",
      "category": {
        "id": "uuid",
        "name": "Electronics",
        "slug": "electronics"
      },
      "title": "Wireless Headphones",
      "description": "High quality...",
      "price": 99.99,
      "compare_at_price": 149.99,
      "currency": "USD",
      "stock_quantity": 50,
      "is_active": true,
      "condition": "new",
      "images": [
        {
          "id": "uuid",
          "image_url": "https://...",
          "thumbnail_url": "https://...",
          "is_primary": true
        }
      ],
      "rating": {
        "average": 4.5,
        "count": 128
      },
      "tags": ["wireless", "audio", "bluetooth"],
      "created_at": "2026-01-15T10:00:00Z"
    }
  ],
  "total": 523,
  "limit": 20,
  "offset": 0
}
```

---

### GET /products/:productId
Get product details

**Response (200):**
```json
{
  "id": "uuid",
  "seller": {
    "id": "uuid",
    "username": "seller1",
    "display_name": "Tech Seller",
    "profile_image_url": "https://..."
  },
  "category": {
    "id": "uuid",
    "name": "Electronics"
  },
  "title": "Wireless Headphones",
  "description": "Full description...",
  "price": 99.99,
  "compare_at_price": 149.99,
  "currency": "USD",
  "sku": "WH-001",
  "stock_quantity": 50,
  "images": [ /* array of images */ ],
  "rating": {
    "average": 4.5,
    "count": 128,
    "distribution": {
      "5": 80,
      "4": 30,
      "3": 10,
      "2": 5,
      "1": 3
    }
  },
  "tags": ["wireless", "audio"],
  "related_content": [
    {
      "id": "uuid",
      "type": "video",
      "title": "Product Review",
      "thumbnail_url": "https://...",
      "view_count": 5420
    }
  ],
  "created_at": "2026-01-15T10:00:00Z",
  "updated_at": "2026-01-29T10:00:00Z"
}
```

---

### POST /products
Create product (requires auth, seller role)

**Request:**
```json
{
  "category_id": "uuid",
  "title": "New Product",
  "description": "Description here",
  "price": 49.99,
  "compare_at_price": 69.99,
  "sku": "PROD-001",
  "stock_quantity": 100,
  "condition": "new",
  "tags": ["tag1", "tag2"],
  "images": [
    {
      "image_url": "https://...",
      "thumbnail_url": "https://...",
      "is_primary": true,
      "display_order": 0
    }
  ]
}
```

**Response (201):**
```json
{
  "message": "Product created successfully",
  "product": { /* full product object */ }
}
```

---

### PUT /products/:productId
Update product (requires auth, own product)

**Request:** Same as POST /products

**Response (200):**
```json
{
  "message": "Product updated successfully",
  "product": { /* updated product */ }
}
```

---

### DELETE /products/:productId
Deactivate product (requires auth, own product)

**Response (200):**
```json
{
  "message": "Product deactivated successfully"
}
```

---

### GET /products/:productId/reviews
Get product reviews

**Query Params:**
- `sort`: string (newest, helpful, rating_high, rating_low)
- `limit`: int
- `offset`: int

**Response (200):**
```json
{
  "reviews": [
    {
      "id": "uuid",
      "user": {
        "id": "uuid",
        "username": "reviewer1",
        "display_name": "Jane Doe",
        "profile_image_url": "https://..."
      },
      "rating": 5,
      "review_title": "Amazing product!",
      "review_text": "Really love this...",
      "is_verified_purchase": true,
      "helpful_count": 24,
      "created_at": "2026-01-20T10:00:00Z"
    }
  ],
  "total": 128,
  "limit": 20,
  "offset": 0
}
```

---

### POST /products/:productId/reviews
Add product review (requires auth, must have purchased)

**Request:**
```json
{
  "rating": 5,
  "review_title": "Great product",
  "review_text": "Really satisfied with..."
}
```

**Response (201):**
```json
{
  "message": "Review submitted successfully",
  "review": { /* review object */ }
}
```

---

## 4. SHOPPING CART

### GET /cart
Get current user's cart (requires auth)

**Response (200):**
```json
{
  "items": [
    {
      "id": "uuid",
      "product": {
        "id": "uuid",
        "title": "Wireless Headphones",
        "price": 99.99,
        "stock_quantity": 50,
        "images": [
          {
            "image_url": "https://...",
            "thumbnail_url": "https://..."
          }
        ],
        "seller": {
          "id": "uuid",
          "username": "seller1"
        }
      },
      "quantity": 2,
      "unit_price": 99.99,
      "subtotal": 199.98,
      "added_at": "2026-01-28T10:00:00Z"
    }
  ],
  "summary": {
    "item_count": 3,
    "subtotal": 299.97,
    "tax": 24.00,
    "shipping": 10.00,
    "discount": 0.00,
    "total": 333.97,
    "currency": "USD"
  }
}
```

---

### POST /cart/items
Add item to cart (requires auth)

**Request:**
```json
{
  "product_id": "uuid",
  "quantity": 1
}
```

**Response (201):**
```json
{
  "message": "Item added to cart",
  "cart": { /* full cart object */ }
}
```

---

### PUT /cart/items/:itemId
Update cart item quantity (requires auth)

**Request:**
```json
{
  "quantity": 3
}
```

**Response (200):**
```json
{
  "message": "Cart updated",
  "cart": { /* full cart */ }
}
```

---

### DELETE /cart/items/:itemId
Remove item from cart (requires auth)

**Response (200):**
```json
{
  "message": "Item removed from cart",
  "cart": { /* updated cart */ }
}
```

---

### DELETE /cart
Clear entire cart (requires auth)

**Response (200):**
```json
{
  "message": "Cart cleared successfully"
}
```

---

## 5. ORDERS & CHECKOUT

### POST /orders/checkout
Create order from cart (requires auth)

**Request:**
```json
{
  "shipping_address": {
    "name": "John Doe",
    "address_line1": "123 Main St",
    "address_line2": "Apt 4B",
    "city": "San Francisco",
    "state": "CA",
    "postal_code": "94102",
    "country": "US"
  },
  "payment_method": "credit_card",
  "notes": "Leave at door"
}
```

**Response (201):**
```json
{
  "message": "Order created successfully",
  "order": {
    "id": "uuid",
    "order_number": "ORD-2026-001234",
    "status": "pending",
    "items": [ /* order items */ ],
    "subtotal": 299.97,
    "tax": 24.00,
    "shipping": 10.00,
    "total": 333.97,
    "currency": "USD",
    "created_at": "2026-01-29T10:00:00Z"
  }
}
```

---

### GET /orders
Get user's order history (requires auth)

**Query Params:**
- `status`: string
- `limit`: int
- `offset`: int

**Response (200):**
```json
{
  "orders": [
    {
      "id": "uuid",
      "order_number": "ORD-2026-001234",
      "status": "delivered",
      "total": 333.97,
      "currency": "USD",
      "item_count": 3,
      "created_at": "2026-01-20T10:00:00Z",
      "completed_at": "2026-01-25T10:00:00Z"
    }
  ],
  "total": 12,
  "limit": 20,
  "offset": 0
}
```

---

### GET /orders/:orderId
Get order details (requires auth, own order)

**Response (200):**
```json
{
  "id": "uuid",
  "order_number": "ORD-2026-001234",
  "status": "shipped",
  "payment_status": "captured",
  "items": [
    {
      "id": "uuid",
      "product_id": "uuid",
      "product_title": "Wireless Headphones",
      "product_sku": "WH-001",
      "quantity": 2,
      "unit_price": 99.99,
      "subtotal": 199.98,
      "seller": {
        "id": "uuid",
        "username": "seller1"
      }
    }
  ],
  "subtotal": 299.97,
  "tax": 24.00,
  "shipping": 10.00,
  "total": 333.97,
  "shipping_address": { /* address object */ },
  "created_at": "2026-01-20T10:00:00Z",
  "updated_at": "2026-01-22T10:00:00Z"
}
```

---

## 6. CONTENT (VIDEOS & REELS)

### GET /content
Get content feed

**Query Params:**
- `type`: string (video, reel, all - default all)
- `creator_id`: uuid
- `tag`: string
- `sort`: string (newest, popular, trending)
- `limit`: int
- `offset`: int

**Response (200):**
```json
{
  "content": [
    {
      "id": "uuid",
      "creator": {
        "id": "uuid",
        "username": "creator1",
        "display_name": "Creator One",
        "profile_image_url": "https://..."
      },
      "content_type": "reel",
      "title": "Amazing Product Demo",
      "description": "Check out this cool product!",
      "video_url": "https://...",
      "thumbnail_url": "https://...",
      "duration_seconds": 30,
      "width": 1080,
      "height": 1920,
      "view_count": 15420,
      "like_count": 1234,
      "comment_count": 89,
      "is_liked": false,
      "tagged_products": [
        {
          "id": "uuid",
          "title": "Cool Product",
          "price": 29.99,
          "thumbnail_url": "https://...",
          "timestamp_seconds": 5
        }
      ],
      "tags": ["tech", "review"],
      "created_at": "2026-01-28T10:00:00Z"
    }
  ],
  "total": 8542,
  "limit": 20,
  "offset": 0
}
```

---

### GET /content/:contentId
Get content details

**Response (200):**
```json
{
  "id": "uuid",
  "creator": { /* creator info */ },
  "content_type": "video",
  "title": "Product Review",
  "description": "Full review of...",
  "video_url": "https://...",
  "thumbnail_url": "https://...",
  "duration_seconds": 600,
  "view_count": 15420,
  "like_count": 1234,
  "is_liked": false,
  "tagged_products": [ /* products */ ],
  "related_content": [ /* similar content */ ],
  "created_at": "2026-01-15T10:00:00Z"
}
```

---

### POST /content
Upload new content (requires auth)

**Request:**
```json
{
  "content_type": "video",
  "title": "My New Video",
  "description": "Description here",
  "video_url": "https://...",
  "thumbnail_url": "https://...",
  "duration_seconds": 300,
  "width": 1920,
  "height": 1080,
  "tagged_products": [
    {
      "product_id": "uuid",
      "timestamp_seconds": 30,
      "display_order": 0
    }
  ],
  "tags": ["tech", "review"],
  "is_published": true
}
```

**Response (201):**
```json
{
  "message": "Content uploaded successfully",
  "content": { /* content object */ }
}
```

---

### POST /content/:contentId/like
Like content (requires auth)

**Response (200):**
```json
{
  "message": "Content liked",
  "is_liked": true,
  "like_count": 1235
}
```

---

### DELETE /content/:contentId/like
Unlike content (requires auth)

**Response (200):**
```json
{
  "message": "Content unliked",
  "is_liked": false,
  "like_count": 1234
}
```

---

### POST /content/:contentId/view
Track content view

**Request:**
```json
{
  "watch_time_seconds": 45
}
```

**Response (200):**
```json
{
  "message": "View recorded"
}
```

---

## 7. SEARCH

### GET /search
Multi-category search

**Query Params:**
- `q`: string (required)
- `type`: string (products, videos, reels, users, all - default all)
- `limit`: int
- `offset`: int

**Response (200):**
```json
{
  "query": "wireless headphones",
  "results": {
    "products": {
      "items": [ /* product objects */ ],
      "total": 45
    },
    "videos": {
      "items": [ /* video objects */ ],
      "total": 12
    },
    "reels": {
      "items": [ /* reel objects */ ],
      "total": 8
    },
    "users": {
      "items": [ /* user objects */ ],
      "total": 3
    }
  },
  "total_results": 68
}
```

---

### GET /search/suggestions
Get search suggestions

**Query Params:**
- `q`: string (required)
- `limit`: int (default 10)

**Response (200):**
```json
{
  "suggestions": [
    "wireless headphones",
    "wireless headphones bluetooth",
    "wireless headphones noise cancelling"
  ],
  "recent_searches": [
    "laptop stand",
    "phone case"
  ]
}
```

---

## 8. MESSAGING

### GET /conversations
Get user's conversations (requires auth)

**Response (200):**
```json
{
  "conversations": [
    {
      "id": "uuid",
      "other_user": {
        "id": "uuid",
        "username": "seller1",
        "display_name": "Seller One",
        "profile_image_url": "https://..."
      },
      "last_message": {
        "id": "uuid",
        "message_text": "Thanks for your interest!",
        "sender_id": "uuid",
        "created_at": "2026-01-29T09:30:00Z",
        "is_read": true
      },
      "unread_count": 2,
      "last_message_at": "2026-01-29T09:30:00Z",
      "created_at": "2026-01-28T10:00:00Z"
    }
  ],
  "total": 15
}
```

---

### GET /conversations/:conversationId/messages
Get conversation messages (requires auth)

**Query Params:**
- `limit`: int (default 50)
- `before`: timestamp (for pagination)

**Response (200):**
```json
{
  "messages": [
    {
      "id": "uuid",
      "sender": {
        "id": "uuid",
        "username": "user1",
        "display_name": "User One",
        "profile_image_url": "https://..."
      },
      "message_text": "Is this still available?",
      "message_type": "text",
      "is_read": true,
      "created_at": "2026-01-29T09:00:00Z"
    },
    {
      "id": "uuid",
      "sender": {
        "id": "uuid",
        "username": "seller1"
      },
      "message_text": "Yes, it's available!",
      "message_type": "text",
      "is_read": true,
      "created_at": "2026-01-29T09:05:00Z"
    },
    {
      "id": "uuid",
      "sender": {
        "id": "uuid",
        "username": "seller1"
      },
      "message_text": "Check out this product:",
      "message_type": "product_link",
      "product": {
        "id": "uuid",
        "title": "Wireless Headphones",
        "price": 99.99,
        "thumbnail_url": "https://..."
      },
      "is_read": false,
      "created_at": "2026-01-29T09:30:00Z"
    }
  ],
  "total": 45,
  "limit": 50
}
```

---

### POST /conversations
Start new conversation (requires auth)

**Request:**
```json
{
  "recipient_id": "uuid",
  "initial_message": "Hi, is this product still available?"
}
```

**Response (201):**
```json
{
  "message": "Conversation started",
  "conversation": { /* conversation object */ }
}
```

---

### POST /conversations/:conversationId/messages
Send message (requires auth)

**Request:**
```json
{
  "message_text": "Thanks!",
  "message_type": "text",
  "product_id": "uuid"
}
```

**Response (201):**
```json
{
  "message": "Message sent",
  "message_object": { /* message object */ }
}
```

---

### PUT /conversations/:conversationId/read
Mark conversation as read (requires auth)

**Response (200):**
```json
{
  "message": "Conversation marked as read"
}
```

---

## 9. USER SETTINGS

### GET /settings
Get user settings (requires auth)

**Response (200):**
```json
{
  "theme_mode": "dark",
  "notifications_enabled": true,
  "email_notifications": true,
  "push_notifications": true,
  "message_notifications": true,
  "language": "en",
  "privacy_mode": "public"
}
```

---

### PUT /settings
Update user settings (requires auth)

**Request:**
```json
{
  "theme_mode": "dark",
  "notifications_enabled": true,
  "email_notifications": false,
  "privacy_mode": "public"
}
```

**Response (200):**
```json
{
  "message": "Settings updated successfully",
  "settings": { /* updated settings */ }
}
```

---

### PUT /settings/password
Change password (requires auth)

**Request:**
```json
{
  "current_password": "OldPass123!",
  "new_password": "NewSecurePass456!",
  "new_password_confirm": "NewSecurePass456!"
}
```

**Response (200):**
```json
{
  "message": "Password changed successfully"
}
```

---

## 10. ANALYTICS & TRACKING

### POST /analytics/events
Track analytics event (requires auth)

**Request:**
```json
{
  "event_type": "tab_visit",
  "event_category": "navigation",
  "entity_type": "tab",
  "entity_id": null,
  "properties": {
    "tab_name": "shopping",
    "session_duration": 120
  }
}
```

**Response (200):**
```json
{
  "message": "Event tracked"
}
```

---

### GET /analytics/seller/dashboard
Get seller analytics (requires auth, seller role)

**Query Params:**
- `start_date`: date (YYYY-MM-DD)
- `end_date`: date (YYYY-MM-DD)

**Response (200):**
```json
{
  "period": {
    "start_date": "2026-01-01",
    "end_date": "2026-01-29"
  },
  "summary": {
    "total_views": 15420,
    "total_sales": 45,
    "revenue": 4567.89,
    "content_uploaded": 12,
    "new_followers": 234
  },
  "products": [
    {
      "product_id": "uuid",
      "product_title": "Wireless Headphones",
      "views": 5420,
      "clicks": 342,
      "cart_adds": 89,
      "purchases": 23,
      "revenue": 2297.77,
      "conversion_rate": 6.72
    }
  ],
  "content": [
    {
      "content_id": "uuid",
      "content_title": "Product Demo",
      "content_type": "reel",
      "views": 8520,
      "likes": 456,
      "product_clicks": 234
    }
  ],
  "daily_metrics": [
    {
      "date": "2026-01-29",
      "views": 842,
      "sales": 3,
      "revenue": 299.97
    }
  ]
}
```

---

## 11. CATEGORIES

### GET /categories
Get all categories

**Response (200):**
```json
{
  "categories": [
    {
      "id": "uuid",
      "name": "Electronics",
      "slug": "electronics",
      "description": "Electronic devices and accessories",
      "image_url": "https://...",
      "product_count": 1234,
      "subcategories": [
        {
          "id": "uuid",
          "name": "Audio",
          "slug": "audio",
          "product_count": 456
        }
      ]
    }
  ]
}
```

---

## WebSocket Endpoints

### WS /ws/messaging
Real-time messaging WebSocket

**Connect:** `ws://localhost:8080/ws/messaging?token=<jwt_token>`

**Message Format (Client → Server):**
```json
{
  "type": "send_message",
  "conversation_id": "uuid",
  "message_text": "Hello!",
  "message_type": "text"
}
```

**Message Format (Server → Client):**
```json
{
  "type": "new_message",
  "conversation_id": "uuid",
  "message": { /* message object */ }
}
```

**Other Events:**
- `typing_indicator`: User is typing
- `message_read`: Message marked as read
- `user_online`: User came online
- `user_offline`: User went offline

---

## Error Response Format

All errors follow this structure:

```json
{
  "error": {
    "code": "INVALID_INPUT",
    "message": "Validation failed",
    "details": {
      "email": "Invalid email format",
      "password": "Password must be at least 8 characters"
    }
  },
  "timestamp": "2026-01-29T10:00:00Z"
}
```

**Common Error Codes:**
- `INVALID_INPUT`: Validation error (400)
- `UNAUTHORIZED`: Not authenticated (401)
- `FORBIDDEN`: Not authorized (403)
- `NOT_FOUND`: Resource not found (404)
- `CONFLICT`: Resource conflict (409)
- `RATE_LIMITED`: Too many requests (429)
- `SERVER_ERROR`: Internal error (500)

---

## Rate Limiting

- Authentication endpoints: 5 requests per minute
- General API: 100 requests per minute
- Search: 20 requests per minute
- Analytics: 10 requests per minute

Headers returned:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1643457600
```

---

## Pagination

List endpoints support cursor-based pagination:

**Request:**
```
GET /products?limit=20&offset=0
```

**Response Headers:**
```
X-Total-Count: 523
X-Page-Limit: 20
X-Page-Offset: 0
```

**Response Body:**
```json
{
  "items": [ /* array of items */ ],
  "total": 523,
  "limit": 20,
  "offset": 0,
  "has_more": true
}
```
