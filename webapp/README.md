# Buzz Social Cart

A modern social commerce platform built with React (Vite) and FastAPI.

## Features

- 🛍️ Social Shopping with product feeds
- 📹 Videos and Reels
- 💬 Messaging and Chat
- 🤖 AI Chatbot Assistant
- 🛒 Shopping Cart
- 👤 User Profiles
- 🌓 Dark/Light Mode
- 🔐 JWT Authentication

## Prerequisites

- Node.js 18+ and npm
- Python 3.9+
- MongoDB (local or cloud)

## Setup

### 1. Install Dependencies

**Frontend:**
```bash
cd frontend
npm install
```

**Backend:**
```bash
cd backend
pip install -r requirements.txt
```

### 2. Configure Environment

**Backend (.env):**
```
MONGO_URL=mongodb://localhost:27017
DB_NAME=buzz_social_cart
CORS_ORIGINS=*
JWT_SECRET=your-secret-key-here
OPENAI_API_KEY=your-openai-key-here  # Optional, for chatbot
```

**Frontend (.env):**
```
VITE_BACKEND_URL=http://localhost:8000
```

### 3. Start MongoDB

Make sure MongoDB is running on your system:
```bash
# On Windows with MongoDB installed
mongod

# Or use MongoDB Atlas (cloud)
```

## Running the Application

### Start Backend (Terminal 1)
```bash
cd backend
uvicorn server:app --reload --port 8000
```

### Start Frontend (Terminal 2)
```bash
cd frontend
npm run dev
```

The app will be available at:
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API Docs: http://localhost:8000/docs

## Seed Demo Data

To populate the database with demo products, videos, and reels:

```bash
curl -X POST http://localhost:8000/api/seed
```

Or visit http://localhost:8000/docs and use the `/api/seed` endpoint.

## Default Demo User

After seeding:
- Email: demo@buzz.com
- Password: demo123

## Project Structure

```
webapp/
├── frontend/              # React + Vite frontend
│   ├── src/
│   │   ├── components/   # Reusable UI components
│   │   ├── contexts/     # React contexts (Auth, Theme, Cart)
│   │   ├── pages/        # Page components
│   │   └── lib/          # Utilities
│   └── package.json
├── backend/              # FastAPI backend
│   ├── server.py         # Main API server
│   ├── .env              # Environment variables
│   └── requirements.txt  # Python dependencies
└── README.md
```

## API Endpoints

- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `GET /api/auth/me` - Get current user
- `GET /api/products` - List products
- `GET /api/videos` - List videos
- `GET /api/reels` - List reels
- `GET /api/cart` - Get user's cart
- `POST /api/cart/add` - Add item to cart
- `GET /api/feed` - Get mixed content feed
- `GET /api/search` - Search across content
- `POST /api/v1/chat/message` - Chat with AI assistant

Full API documentation: http://localhost:8000/docs

## Tech Stack

### Frontend
- React 18
- Vite
- React Router
- Axios
- Tailwind CSS
- Lucide Icons
- Sonner (Toasts)

### Backend
- FastAPI
- Motor (MongoDB async driver)
- Pydantic
- JWT Authentication
- OpenAI (optional)

## Troubleshooting

### MongoDB Connection Issues
- Ensure MongoDB is running
- Check `MONGO_URL` in backend/.env
- Try using MongoDB Atlas for cloud hosting

### Port Already in Use
- Change ports in `vite.config.js` (frontend) or uvicorn command (backend)

### Module Not Found Errors
- Run `npm install` in frontend
- Run `pip install -r requirements.txt` in backend
- Ensure virtual environment is activated (if using one)

## License

MIT
