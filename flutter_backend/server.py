from fastapi import FastAPI, APIRouter, HTTPException, Depends, status, Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
from pathlib import Path
from pydantic import BaseModel, Field, ConfigDict, EmailStr
from typing import List, Optional, Any
import uuid
from datetime import datetime, timezone, timedelta
import jwt
import bcrypt
from openai import AsyncOpenAI

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# MongoDB connection
mongo_url = os.environ.get('MONGO_URL', 'mongodb://localhost:27017')
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ.get('DB_NAME', 'buzzcart_dev')]

# JWT Configuration
JWT_SECRET = os.environ.get('JWT_SECRET', 'buzz-social-cart-secret-key-2024')
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION_HOURS = 24 * 7  # 7 days

# LLM Configuration
OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY', '')
openai_client = AsyncOpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None

# Create the main app
app = FastAPI(title="Buzz Social Cart API")

# Create routers
api_router = APIRouter(prefix="/api")
chat_router = APIRouter(prefix="/api/v1")

security = HTTPBearer(auto_error=False)

# ==================== MODELS ====================

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    name: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str
    email: str
    name: str
    avatar: Optional[str] = None
    bio: Optional[str] = None
    followers_count: int = 0
    following_count: int = 0
    created_at: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse

class ProfileUpdate(BaseModel):
    name: Optional[str] = None
    bio: Optional[str] = None
    avatar: Optional[str] = None

class ProductCreate(BaseModel):
    title: str
    description: str
    price: float
    images: List[str] = []
    category: str = "general"
    tags: List[str] = []

class ProductResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str
    title: str
    description: str
    price: float
    images: List[str]
    category: str
    tags: List[str]
    seller_id: str
    seller_name: str
    rating: float = 0.0
    reviews_count: int = 0
    views: int = 0
    created_at: str

class VideoCreate(BaseModel):
    title: str
    description: str
    url: str
    thumbnail: str
    duration: int = 0
    product_ids: List[str] = []

class VideoResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str
    title: str
    description: str
    url: str
    thumbnail: str
    duration: int
    views: int = 0
    likes: int = 0
    creator_id: str
    creator_name: str
    creator_avatar: Optional[str] = None
    products: List[dict] = []
    created_at: str

class ReelCreate(BaseModel):
    url: str
    thumbnail: str
    caption: str = ""
    product_ids: List[str] = []

class ReelResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str
    url: str
    thumbnail: str
    caption: str
    views: int = 0
    likes: int = 0
    creator_id: str
    creator_name: str
    creator_avatar: Optional[str] = None
    products: List[dict] = []
    created_at: str

class CartItemAdd(BaseModel):
    product_id: str
    quantity: int = 1

class CartResponse(BaseModel):
    items: List[dict]
    subtotal: float
    total: float
    item_count: int

class MessageCreate(BaseModel):
    receiver_id: str
    content: str
    product_id: Optional[str] = None

class ConversationResponse(BaseModel):
    id: str
    participants: List[dict]
    last_message: Optional[dict] = None
    updated_at: str

class ChatMessageRequest(BaseModel):
    message: str
    user_id: str
    conversation_id: Optional[str] = None
    context: Optional[str] = None

class ChatMessageResponse(BaseModel):
    message: str
    conversation_id: str
    sources: Optional[List[dict]] = None
    metadata: Optional[dict] = None
    timestamp: str

class SearchResponse(BaseModel):
    products: List[dict] = []
    videos: List[dict] = []
    reels: List[dict] = []
    users: List[dict] = []

# ==================== AUTH HELPERS ====================

def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

def create_token(user_id: str) -> str:
    payload = {
        "sub": user_id,
        "exp": datetime.now(timezone.utc) + timedelta(hours=JWT_EXPIRATION_HOURS),
        "iat": datetime.now(timezone.utc)
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if not credentials:
        raise HTTPException(status_code=401, detail="Not authenticated")
    try:
        payload = jwt.decode(credentials.credentials, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid token")
        user = await db.users.find_one({"id": user_id}, {"_id": 0, "password": 0})
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        return user
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

async def get_optional_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if not credentials:
        return None
    try:
        payload = jwt.decode(credentials.credentials, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = payload.get("sub")
        if user_id:
            return await db.users.find_one({"id": user_id}, {"_id": 0, "password": 0})
    except:
        pass
    return None

# ==================== AUTH ROUTES ====================

@api_router.post("/auth/register", response_model=TokenResponse)
async def register(user_data: UserCreate):
    existing = await db.users.find_one({"email": user_data.email})
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    user_id = str(uuid.uuid4())
    user_doc = {
        "id": user_id,
        "email": user_data.email,
        "password": hash_password(user_data.password),
        "name": user_data.name,
        "avatar": None,
        "bio": "",
        "followers_count": 0,
        "following_count": 0,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.users.insert_one(user_doc)
    
    token = create_token(user_id)
    user_response = {k: v for k, v in user_doc.items() if k != "password"}
    return TokenResponse(access_token=token, user=UserResponse(**user_response))

@api_router.post("/auth/login", response_model=TokenResponse)
async def login(credentials: UserLogin):
    user = await db.users.find_one({"email": credentials.email})
    if not user or not verify_password(credentials.password, user["password"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    token = create_token(user["id"])
    user_response = {k: v for k, v in user.items() if k not in ["password", "_id"]}
    return TokenResponse(access_token=token, user=UserResponse(**user_response))

@api_router.get("/auth/me", response_model=UserResponse)
async def get_me(current_user: dict = Depends(get_current_user)):
    return UserResponse(**current_user)

@api_router.put("/auth/profile", response_model=UserResponse)
async def update_profile(update: ProfileUpdate, current_user: dict = Depends(get_current_user)):
    update_data = {k: v for k, v in update.model_dump().items() if v is not None}
    if update_data:
        await db.users.update_one({"id": current_user["id"]}, {"$set": update_data})
    updated_user = await db.users.find_one({"id": current_user["id"]}, {"_id": 0, "password": 0})
    return UserResponse(**updated_user)

@api_router.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: str):
    user = await db.users.find_one({"id": user_id}, {"_id": 0, "password": 0})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return UserResponse(**user)

# ==================== PRODUCTS ROUTES ====================

@api_router.post("/products", response_model=ProductResponse)
async def create_product(product: ProductCreate, current_user: dict = Depends(get_current_user)):
    product_id = str(uuid.uuid4())
    product_doc = {
        "id": product_id,
        **product.model_dump(),
        "seller_id": current_user["id"],
        "seller_name": current_user["name"],
        "rating": 0.0,
        "reviews_count": 0,
        "views": 0,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.products.insert_one(product_doc)
    return ProductResponse(**{k: v for k, v in product_doc.items() if k != "_id"})

@api_router.get("/products", response_model=List[ProductResponse])
async def get_products(
    category: Optional[str] = None,
    search: Optional[str] = None,
    sort: str = "newest",
    limit: int = Query(default=20, le=100),
    offset: int = 0
):
    query = {}
    if category:
        query["category"] = category
    if search:
        query["$or"] = [
            {"title": {"$regex": search, "$options": "i"}},
            {"description": {"$regex": search, "$options": "i"}}
        ]
    
    sort_field = {"newest": ("created_at", -1), "price_low": ("price", 1), "price_high": ("price", -1), "popular": ("views", -1)}
    sort_key, sort_dir = sort_field.get(sort, ("created_at", -1))
    
    products = await db.products.find(query, {"_id": 0}).sort(sort_key, sort_dir).skip(offset).limit(limit).to_list(limit)
    return [ProductResponse(**p) for p in products]

@api_router.get("/products/{product_id}", response_model=ProductResponse)
async def get_product(product_id: str):
    product = await db.products.find_one({"id": product_id}, {"_id": 0})
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    await db.products.update_one({"id": product_id}, {"$inc": {"views": 1}})
    return ProductResponse(**product)

@api_router.put("/products/{product_id}", response_model=ProductResponse)
async def update_product(product_id: str, update: ProductCreate, current_user: dict = Depends(get_current_user)):
    product = await db.products.find_one({"id": product_id})
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if product["seller_id"] != current_user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    await db.products.update_one({"id": product_id}, {"$set": update.model_dump()})
    updated = await db.products.find_one({"id": product_id}, {"_id": 0})
    return ProductResponse(**updated)

@api_router.delete("/products/{product_id}")
async def delete_product(product_id: str, current_user: dict = Depends(get_current_user)):
    product = await db.products.find_one({"id": product_id})
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if product["seller_id"] != current_user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    await db.products.delete_one({"id": product_id})
    return {"message": "Product deleted"}

@api_router.get("/products/seller/{seller_id}", response_model=List[ProductResponse])
async def get_seller_products(seller_id: str, limit: int = 20):
    products = await db.products.find({"seller_id": seller_id}, {"_id": 0}).limit(limit).to_list(limit)
    return [ProductResponse(**p) for p in products]

# ==================== VIDEOS ROUTES ====================

@api_router.post("/videos", response_model=VideoResponse)
async def create_video(video: VideoCreate, current_user: dict = Depends(get_current_user)):
    video_id = str(uuid.uuid4())
    products = []
    if video.product_ids:
        products = await db.products.find({"id": {"$in": video.product_ids}}, {"_id": 0, "id": 1, "title": 1, "price": 1, "images": 1}).to_list(100)
    
    video_doc = {
        "id": video_id,
        **video.model_dump(),
        "views": 0,
        "likes": 0,
        "creator_id": current_user["id"],
        "creator_name": current_user["name"],
        "creator_avatar": current_user.get("avatar"),
        "products": products,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.videos.insert_one(video_doc)
    return VideoResponse(**{k: v for k, v in video_doc.items() if k not in ["_id", "product_ids"]})

@api_router.get("/videos", response_model=List[VideoResponse])
async def get_videos(limit: int = Query(default=20, le=100), offset: int = 0):
    videos = await db.videos.find({}, {"_id": 0}).sort("created_at", -1).skip(offset).limit(limit).to_list(limit)
    return [VideoResponse(**v) for v in videos]

@api_router.get("/videos/{video_id}", response_model=VideoResponse)
async def get_video(video_id: str):
    video = await db.videos.find_one({"id": video_id}, {"_id": 0})
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    await db.videos.update_one({"id": video_id}, {"$inc": {"views": 1}})
    return VideoResponse(**video)

@api_router.post("/videos/{video_id}/like")
async def like_video(video_id: str, current_user: dict = Depends(get_current_user)):
    video = await db.videos.find_one({"id": video_id})
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    await db.videos.update_one({"id": video_id}, {"$inc": {"likes": 1}})
    return {"message": "Liked"}

# ==================== REELS ROUTES ====================

@api_router.post("/reels", response_model=ReelResponse)
async def create_reel(reel: ReelCreate, current_user: dict = Depends(get_current_user)):
    reel_id = str(uuid.uuid4())
    products = []
    if reel.product_ids:
        products = await db.products.find({"id": {"$in": reel.product_ids}}, {"_id": 0, "id": 1, "title": 1, "price": 1, "images": 1}).to_list(100)
    
    reel_doc = {
        "id": reel_id,
        **reel.model_dump(),
        "views": 0,
        "likes": 0,
        "creator_id": current_user["id"],
        "creator_name": current_user["name"],
        "creator_avatar": current_user.get("avatar"),
        "products": products,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.reels.insert_one(reel_doc)
    return ReelResponse(**{k: v for k, v in reel_doc.items() if k not in ["_id", "product_ids"]})

@api_router.get("/reels", response_model=List[ReelResponse])
async def get_reels(limit: int = Query(default=20, le=100), offset: int = 0):
    reels = await db.reels.find({}, {"_id": 0}).sort("created_at", -1).skip(offset).limit(limit).to_list(limit)
    return [ReelResponse(**r) for r in reels]

@api_router.get("/reels/{reel_id}", response_model=ReelResponse)
async def get_reel(reel_id: str):
    reel = await db.reels.find_one({"id": reel_id}, {"_id": 0})
    if not reel:
        raise HTTPException(status_code=404, detail="Reel not found")
    await db.reels.update_one({"id": reel_id}, {"$inc": {"views": 1}})
    return ReelResponse(**reel)

@api_router.post("/reels/{reel_id}/like")
async def like_reel(reel_id: str, current_user: dict = Depends(get_current_user)):
    reel = await db.reels.find_one({"id": reel_id})
    if not reel:
        raise HTTPException(status_code=404, detail="Reel not found")
    await db.reels.update_one({"id": reel_id}, {"$inc": {"likes": 1}})
    return {"message": "Liked"}

# ==================== CART ROUTES ====================

@api_router.get("/cart", response_model=CartResponse)
async def get_cart(current_user: dict = Depends(get_current_user)):
    cart = await db.carts.find_one({"user_id": current_user["id"]}, {"_id": 0})
    if not cart:
        return CartResponse(items=[], subtotal=0, total=0, item_count=0)
    
    items = []
    subtotal = 0
    for item in cart.get("items", []):
        product = await db.products.find_one({"id": item["product_id"]}, {"_id": 0})
        if product:
            item_total = product["price"] * item["quantity"]
            items.append({
                "product": product,
                "quantity": item["quantity"],
                "item_total": item_total
            })
            subtotal += item_total
    
    return CartResponse(items=items, subtotal=subtotal, total=subtotal, item_count=len(items))

@api_router.post("/cart/add")
async def add_to_cart(item: CartItemAdd, current_user: dict = Depends(get_current_user)):
    product = await db.products.find_one({"id": item.product_id})
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    
    cart = await db.carts.find_one({"user_id": current_user["id"]})
    if not cart:
        await db.carts.insert_one({
            "user_id": current_user["id"],
            "items": [{"product_id": item.product_id, "quantity": item.quantity}],
            "updated_at": datetime.now(timezone.utc).isoformat()
        })
    else:
        existing_item = next((i for i in cart["items"] if i["product_id"] == item.product_id), None)
        if existing_item:
            await db.carts.update_one(
                {"user_id": current_user["id"], "items.product_id": item.product_id},
                {"$inc": {"items.$.quantity": item.quantity}, "$set": {"updated_at": datetime.now(timezone.utc).isoformat()}}
            )
        else:
            await db.carts.update_one(
                {"user_id": current_user["id"]},
                {"$push": {"items": {"product_id": item.product_id, "quantity": item.quantity}}, "$set": {"updated_at": datetime.now(timezone.utc).isoformat()}}
            )
    return {"message": "Added to cart"}

@api_router.put("/cart/update")
async def update_cart_item(item: CartItemAdd, current_user: dict = Depends(get_current_user)):
    if item.quantity <= 0:
        await db.carts.update_one(
            {"user_id": current_user["id"]},
            {"$pull": {"items": {"product_id": item.product_id}}}
        )
    else:
        await db.carts.update_one(
            {"user_id": current_user["id"], "items.product_id": item.product_id},
            {"$set": {"items.$.quantity": item.quantity, "updated_at": datetime.now(timezone.utc).isoformat()}}
        )
    return {"message": "Cart updated"}

@api_router.delete("/cart/remove/{product_id}")
async def remove_from_cart(product_id: str, current_user: dict = Depends(get_current_user)):
    await db.carts.update_one(
        {"user_id": current_user["id"]},
        {"$pull": {"items": {"product_id": product_id}}}
    )
    return {"message": "Removed from cart"}

@api_router.delete("/cart/clear")
async def clear_cart(current_user: dict = Depends(get_current_user)):
    await db.carts.delete_one({"user_id": current_user["id"]})
    return {"message": "Cart cleared"}

# ==================== MESSAGES ROUTES ====================

@api_router.get("/conversations", response_model=List[ConversationResponse])
async def get_conversations(current_user: dict = Depends(get_current_user)):
    conversations = await db.conversations.find(
        {"participant_ids": current_user["id"]}, {"_id": 0}
    ).sort("updated_at", -1).to_list(50)
    
    result = []
    for conv in conversations:
        participants = await db.users.find(
            {"id": {"$in": conv["participant_ids"]}}, {"_id": 0, "password": 0, "id": 1, "name": 1, "avatar": 1}
        ).to_list(10)
        last_message = await db.messages.find_one(
            {"conversation_id": conv["id"]}, {"_id": 0}, sort=[("created_at", -1)]
        )
        result.append(ConversationResponse(
            id=conv["id"],
            participants=participants,
            last_message=last_message,
            updated_at=conv["updated_at"]
        ))
    return result

@api_router.get("/conversations/{conversation_id}/messages")
async def get_messages(conversation_id: str, current_user: dict = Depends(get_current_user), limit: int = 50):
    messages = await db.messages.find(
        {"conversation_id": conversation_id}, {"_id": 0}
    ).sort("created_at", 1).limit(limit).to_list(limit)
    return messages

@api_router.post("/messages")
async def send_message(msg: MessageCreate, current_user: dict = Depends(get_current_user)):
    receiver = await db.users.find_one({"id": msg.receiver_id})
    if not receiver:
        raise HTTPException(status_code=404, detail="Receiver not found")
    
    participant_ids = sorted([current_user["id"], msg.receiver_id])
    conv = await db.conversations.find_one({"participant_ids": participant_ids})
    
    if not conv:
        conv_id = str(uuid.uuid4())
        await db.conversations.insert_one({
            "id": conv_id,
            "participant_ids": participant_ids,
            "updated_at": datetime.now(timezone.utc).isoformat()
        })
    else:
        conv_id = conv["id"]
    
    message_doc = {
        "id": str(uuid.uuid4()),
        "conversation_id": conv_id,
        "sender_id": current_user["id"],
        "sender_name": current_user["name"],
        "receiver_id": msg.receiver_id,
        "content": msg.content,
        "product_id": msg.product_id,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.messages.insert_one(message_doc)
    await db.conversations.update_one({"id": conv_id}, {"$set": {"updated_at": datetime.now(timezone.utc).isoformat()}})
    
    return {k: v for k, v in message_doc.items() if k != "_id"}

# ==================== SEARCH ROUTES ====================

@api_router.get("/search", response_model=SearchResponse)
async def search(q: str = Query(..., min_length=1), limit: int = 10):
    search_query = {"$regex": q, "$options": "i"}
    
    products = await db.products.find(
        {"$or": [{"title": search_query}, {"description": search_query}]}, {"_id": 0}
    ).limit(limit).to_list(limit)
    
    videos = await db.videos.find(
        {"$or": [{"title": search_query}, {"description": search_query}]}, {"_id": 0}
    ).limit(limit).to_list(limit)
    
    reels = await db.reels.find({"caption": search_query}, {"_id": 0}).limit(limit).to_list(limit)
    
    users = await db.users.find(
        {"name": search_query}, {"_id": 0, "password": 0}
    ).limit(limit).to_list(limit)
    
    # Log search for analytics
    await db.analytics.insert_one({
        "type": "search",
        "query": q,
        "timestamp": datetime.now(timezone.utc).isoformat()
    })
    
    return SearchResponse(products=products, videos=videos, reels=reels, users=users)

# ==================== FEED ROUTES ====================

@api_router.get("/feed")
async def get_feed(limit: int = 20, offset: int = 0):
    products = await db.products.find({}, {"_id": 0}).sort("created_at", -1).limit(limit // 3).to_list(limit // 3)
    videos = await db.videos.find({}, {"_id": 0}).sort("created_at", -1).limit(limit // 3).to_list(limit // 3)
    reels = await db.reels.find({}, {"_id": 0}).sort("created_at", -1).limit(limit // 3).to_list(limit // 3)
    
    feed = []
    for p in products:
        feed.append({"type": "product", "data": p})
    for v in videos:
        feed.append({"type": "video", "data": v})
    for r in reels:
        feed.append({"type": "reel", "data": r})
    
    # Simple shuffle for mixed feed
    import random
    random.shuffle(feed)
    return feed

# ==================== CHATBOT ROUTES ====================

@chat_router.post("/chat/message", response_model=ChatMessageResponse)
async def chat_message(request: ChatMessageRequest):
    conversation_id = request.conversation_id or str(uuid.uuid4())
    
    # Store user message
    await db.chat_history.insert_one({
        "id": str(uuid.uuid4()),
        "conversation_id": conversation_id,
        "user_id": request.user_id,
        "role": "user",
        "content": request.message,
        "timestamp": datetime.now(timezone.utc).isoformat()
    })
    
    # Get chat history for context
    history = await db.chat_history.find(
        {"conversation_id": conversation_id}, {"_id": 0}
    ).sort("timestamp", 1).limit(10).to_list(10)
    
    # Generate AI response
    try:
        if OPENAI_API_KEY:
            from openai import OpenAI
            openai_client = OpenAI(api_key=OPENAI_API_KEY)
            
            # Build context from history
            messages = [{"role": "system", "content": """You are Buzz Assistant, a helpful AI for Buzz Social Cart - a social commerce platform. 
You help users with:
- Finding products and recommendations
- Answering questions about orders and shopping
- Providing information about videos and reels
- General customer support
Be friendly, concise, and helpful."""}]
            
            if history:
                recent_messages = history[-5:]
                for msg in recent_messages:
                    messages.append({"role": msg["role"], "content": msg["content"]})
            
            messages.append({"role": "user", "content": request.message})
            
            response = openai_client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=messages
            )
            response_text = response.choices[0].message.content
        else:
            # Fallback response when OpenAI is not configured
            response_text = "Hello! I'm Buzz Assistant. I'm here to help you with shopping and browsing our platform. How can I assist you today?"
        
    except Exception as e:
        logging.error(f"Chat error: {e}")
        response_text = "I'm sorry, I'm having trouble connecting right now. Please try again in a moment."
    
    # Store assistant response
    await db.chat_history.insert_one({
        "id": str(uuid.uuid4()),
        "conversation_id": conversation_id,
        "user_id": request.user_id,
        "role": "assistant",
        "content": response_text,
        "timestamp": datetime.now(timezone.utc).isoformat()
    })
    
    return ChatMessageResponse(
        message=response_text,
        conversation_id=conversation_id,
        timestamp=datetime.now(timezone.utc).isoformat()
    )

@chat_router.get("/chat/history/{user_id}")
async def get_chat_history(user_id: str, conversation_id: Optional[str] = None, limit: int = 50):
    query = {"user_id": user_id}
    if conversation_id:
        query["conversation_id"] = conversation_id
    
    history = await db.chat_history.find(query, {"_id": 0}).sort("timestamp", -1).limit(limit).to_list(limit)
    return history

@chat_router.delete("/chat/history/{conversation_id}")
async def delete_chat_history(conversation_id: str):
    await db.chat_history.delete_many({"conversation_id": conversation_id})
    return {"message": "Conversation deleted"}

@chat_router.get("/health")
async def health_check():
    return {"status": "healthy", "service": "buzz-social-cart-chatbot"}

# ==================== ANALYTICS ROUTES ====================

@api_router.post("/analytics/event")
async def log_event(event_type: str, event_data: dict = {}, current_user: dict = Depends(get_optional_user)):
    await db.analytics.insert_one({
        "type": event_type,
        "data": event_data,
        "user_id": current_user["id"] if current_user else None,
        "timestamp": datetime.now(timezone.utc).isoformat()
    })
    return {"message": "Event logged"}

# ==================== SEED DATA ====================

@api_router.post("/seed")
async def seed_data():
    """Seed initial demo data"""
    # Check if already seeded
    existing = await db.products.count_documents({})
    if existing > 0:
        return {"message": "Data already seeded"}
    
    # Create demo user
    demo_user_id = str(uuid.uuid4())
    demo_user = {
        "id": demo_user_id,
        "email": "demo@buzz.com",
        "password": hash_password("demo123"),
        "name": "Buzz Demo",
        "avatar": "https://images.unsplash.com/photo-1715114064376-c0a0e9610d6b?crop=entropy&cs=srgb&fm=jpg&q=85&w=200",
        "bio": "Official Buzz Social Cart Demo Account",
        "followers_count": 1250,
        "following_count": 48,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.users.insert_one(demo_user)
    
    # Demo products
    products = [
        {"title": "Wireless Pro Headphones", "description": "Premium noise-canceling wireless headphones with 40-hour battery life", "price": 299.99, "images": ["https://images.unsplash.com/photo-1662350688742-0d52a8e71fea?crop=entropy&cs=srgb&fm=jpg&q=85"], "category": "tech"},
        {"title": "Smart Watch Elite", "description": "Advanced fitness tracking with AMOLED display", "price": 449.99, "images": ["https://images.unsplash.com/photo-1662350689234-4068dadadc44?crop=entropy&cs=srgb&fm=jpg&q=85"], "category": "tech"},
        {"title": "Minimalist Backpack", "description": "Water-resistant urban backpack with laptop compartment", "price": 89.99, "images": ["https://images.unsplash.com/photo-1662350688650-c172ba90270a?crop=entropy&cs=srgb&fm=jpg&q=85"], "category": "fashion"},
        {"title": "Designer Sneakers", "description": "Limited edition streetwear sneakers", "price": 179.99, "images": ["https://images.unsplash.com/photo-1768647417374-5a31c61dc5d0?crop=entropy&cs=srgb&fm=jpg&q=85"], "category": "fashion"},
        {"title": "Vintage Denim Jacket", "description": "Classic oversized denim jacket with custom patches", "price": 129.99, "images": ["https://images.unsplash.com/photo-1761575074217-f6049a1cb0df?crop=entropy&cs=srgb&fm=jpg&q=85"], "category": "fashion"},
        {"title": "Organic Skincare Set", "description": "Complete morning and evening skincare routine", "price": 79.99, "images": ["https://images.unsplash.com/photo-1621084403627-96ff85a6db07?crop=entropy&cs=srgb&fm=jpg&q=85"], "category": "beauty"},
    ]
    
    product_ids = []
    for p in products:
        pid = str(uuid.uuid4())
        product_ids.append(pid)
        await db.products.insert_one({
            "id": pid,
            **p,
            "tags": [p["category"]],
            "seller_id": demo_user_id,
            "seller_name": demo_user["name"],
            "rating": 4.5,
            "reviews_count": 128,
            "views": 1500,
            "created_at": datetime.now(timezone.utc).isoformat()
        })
    
    # Demo videos
    videos = [
        {"title": "Unboxing the Wireless Pro Headphones", "description": "First impressions and sound quality test", "url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4", "thumbnail": "https://images.unsplash.com/photo-1645747103867-0669a7eff310?crop=entropy&cs=srgb&fm=jpg&q=85", "duration": 245},
        {"title": "Smart Watch Elite Review", "description": "Complete feature walkthrough and fitness tracking demo", "url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4", "thumbnail": "https://images.unsplash.com/photo-1763259502867-3602fc66f665?crop=entropy&cs=srgb&fm=jpg&q=85", "duration": 380},
    ]
    
    for v in videos:
        await db.videos.insert_one({
            "id": str(uuid.uuid4()),
            **v,
            "views": 5200,
            "likes": 342,
            "creator_id": demo_user_id,
            "creator_name": demo_user["name"],
            "creator_avatar": demo_user["avatar"],
            "products": [{"id": product_ids[0], "title": products[0]["title"], "price": products[0]["price"], "images": products[0]["images"]}],
            "created_at": datetime.now(timezone.utc).isoformat()
        })
    
    # Demo reels
    reels = [
        {"url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4", "thumbnail": "https://images.unsplash.com/photo-1768647417374-5a31c61dc5d0?crop=entropy&cs=srgb&fm=jpg&q=85", "caption": "New kicks just dropped! #sneakers #fashion"},
        {"url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4", "thumbnail": "https://images.unsplash.com/photo-1761575074217-f6049a1cb0df?crop=entropy&cs=srgb&fm=jpg&q=85", "caption": "Denim season is here #vintage #style"},
        {"url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4", "thumbnail": "https://images.unsplash.com/photo-1621084403627-96ff85a6db07?crop=entropy&cs=srgb&fm=jpg&q=85", "caption": "Morning skincare routine #selfcare #beauty"},
    ]
    
    for i, r in enumerate(reels):
        await db.reels.insert_one({
            "id": str(uuid.uuid4()),
            **r,
            "views": 12000 + i * 1000,
            "likes": 890 + i * 100,
            "creator_id": demo_user_id,
            "creator_name": demo_user["name"],
            "creator_avatar": demo_user["avatar"],
            "products": [{"id": product_ids[i + 3], "title": products[i + 3]["title"], "price": products[i + 3]["price"], "images": products[i + 3]["images"]}],
            "created_at": datetime.now(timezone.utc).isoformat()
        })
    
    return {"message": "Demo data seeded successfully"}

# Include routers
app.include_router(api_router)
app.include_router(chat_router)

app.add_middleware(
    CORSMiddleware,
    allow_credentials=os.environ.get('CORS_ALLOW_CREDENTIALS', 'true').lower() == 'true',
    allow_origins=os.environ.get(
        'CORS_ORIGINS',
        'http://localhost:5173,http://localhost:3000,http://localhost:8080,http://localhost:8000',
    ).split(','),
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@api_router.get("/")
async def root():
    return {"message": "Buzz Social Cart API", "version": "1.0.0"}

@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server:app", host="0.0.0.0", port=8000, reload=True)
