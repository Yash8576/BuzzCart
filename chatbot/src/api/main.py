from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging

from .routes import chat_router, documents_router, health_router
from ..core.config import settings
from ..rag.vector_store import VectorStoreManager

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Lifespan context manager for startup/shutdown
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Initializing RAG chatbot service...")
    try:
        vector_store = VectorStoreManager()
        await vector_store.initialize()
        app.state.vector_store = vector_store
        logger.info("Vector store initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize vector store: {e}")
    
    yield
    
    # Shutdown
    logger.info("Shutting down RAG chatbot service...")

# Create FastAPI app
app = FastAPI(
    title="Like2Share RAG Chatbot API",
    description="RAG-powered chatbot for Like2Share social media platform",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health_router, prefix="/api/v1")
app.include_router(chat_router, prefix="/api/v1/chat", tags=["chat"])
app.include_router(documents_router, prefix="/api/v1/documents", tags=["documents"])

@app.get("/")
async def root():
    return {
        "service": "Like2Share RAG Chatbot",
        "version": "1.0.0",
        "status": "running"
    }
