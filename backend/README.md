# Buzz Social Cart - Go Backend

This is the Go backend for the Buzz Social Cart application, converted from Python/FastAPI to Go/Gin.

## Prerequisites

- Go 1.21 or higher
- MongoDB (running locally or remotely)

## Installation

### Install Go

Download and install Go from [https://go.dev/dl/](https://go.dev/dl/)

For Windows, download the MSI installer and run it.

After installation, verify by running:
```bash
go version
```

### Setup

1. Navigate to the backend directory:
```bash
cd backend
```

2. Create a `.env` file (copy from `.env.example`):
```bash
copy .env.example .env
```

3. Update the `.env` file with your configuration:
- MONGO_URL: Your MongoDB connection string
- DB_NAME: Database name (default: buzzcart_dev)
- JWT_SECRET: Secret key for JWT tokens
- PORT: Server port (default: 8000)

4. Download dependencies:
```bash
go mod download
```

## Running the Server

### Development Mode

```bash
go run cmd/server/main.go
```

### Production Build

```bash
go build -o buzzcart.exe cmd/server/main.go
./buzzcart.exe
```

## API Endpoints

### Authentication
- POST `/api/auth/register` - Register new user
- POST `/api/auth/login` - Login user
- GET `/api/auth/me` - Get current user (requires auth)
- PUT `/api/auth/profile` - Update user profile (requires auth)

### Users
- GET `/api/users/:user_id` - Get user by ID

### Products
- POST `/api/products` - Create product (requires auth)
- GET `/api/products` - List products
- GET `/api/products/:product_id` - Get product
- PUT `/api/products/:product_id` - Update product (requires auth)
- DELETE `/api/products/:product_id` - Delete product (requires auth)
- GET `/api/products/seller/:seller_id` - Get seller's products

### Videos
- POST `/api/videos` - Create video (requires auth)
- GET `/api/videos` - List videos
- GET `/api/videos/:video_id` - Get video
- POST `/api/videos/:video_id/like` - Like video (requires auth)

### Reels
- POST `/api/reels` - Create reel (requires auth)
- GET `/api/reels` - List reels
- GET `/api/reels/:reel_id` - Get reel
- POST `/api/reels/:reel_id/like` - Like reel (requires auth)

### Cart
- GET `/api/cart` - Get user's cart (requires auth)
- POST `/api/cart/add` - Add item to cart (requires auth)
- POST `/api/cart/remove` - Remove item from cart (requires auth)
- POST `/api/cart/update` - Update cart item (requires auth)
- DELETE `/api/cart/clear` - Clear cart (requires auth)

### Social
- POST `/api/follow/:user_id` - Follow user (requires auth)
- POST `/api/unfollow/:user_id` - Unfollow user (requires auth)

### Feed & Discovery
- GET `/api/feed` - Get feed
- GET `/api/discover` - Get discovery page
- GET `/api/search?q=query` - Search products, videos, reels, users

### Messages
- POST `/api/messages` - Send message (requires auth)
- GET `/api/messages/conversations` - Get conversations (requires auth)
- GET `/api/messages/conversations/:conversation_id` - Get messages (requires auth)

## Project Structure

```
backend/
├── cmd/
│   └── server/
│       └── main.go          # Application entry point
├── internal/
│   ├── config/
│   │   └── config.go        # Configuration management
│   ├── database/
│   │   └── database.go      # MongoDB connection
│   ├── handlers/
│   │   ├── auth.go          # Auth handlers
│   │   ├── products.go      # Product handlers
│   │   ├── videos.go        # Video handlers
│   │   ├── reels.go         # Reel handlers
│   │   ├── cart.go          # Cart handlers
│   │   ├── messages.go      # Message handlers
│   │   ├── follow.go        # Follow/unfollow handlers
│   │   └── feed.go          # Feed and search handlers
│   ├── middleware/
│   │   └── middleware.go    # Auth and CORS middleware
│   ├── models/
│   │   └── models.go        # Data models
│   └── utils/
│       └── auth.go          # Auth utilities (JWT, bcrypt)
├── .env.example
├── go.mod
├── go.sum
├── Dockerfile
└── README.md
```

## Environment Variables

- `MONGO_URL`: MongoDB connection URL (default: mongodb://localhost:27017)
- `DB_NAME`: Database name (default: buzzcart_dev)
- `JWT_SECRET`: Secret key for JWT tokens (default: buzz-social-cart-secret-key-2024)
- `PORT`: Server port (default: 8000)
- `GIN_MODE`: Gin mode (debug/release)
- `OPENAI_API_KEY`: OpenAI API key (optional)

## Docker Support

Build and run with Docker:

```bash
docker build -t buzzcart-backend .
docker run -p 8000:8000 --env-file .env buzzcart-backend
```

## Migration from Python Backend

The Go backend is a complete rewrite of the Python/FastAPI backend with feature parity:

✅ All API endpoints implemented
✅ JWT authentication
✅ MongoDB integration
✅ CORS support
✅ Same data models
✅ Compatible with existing database

To switch from Python to Go:
1. Stop the Python backend
2. Install Go and dependencies
3. Run the Go backend
4. No database migration needed - uses same MongoDB database

## Development

The server uses Gin web framework with:
- JWT authentication middleware
- MongoDB for data storage
- bcrypt for password hashing
- CORS middleware for cross-origin requests

## License

MIT
