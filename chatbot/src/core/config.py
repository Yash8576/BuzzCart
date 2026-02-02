from pydantic_settings import BaseSettings
from typing import List
import os

class Settings(BaseSettings):
    # API Configuration
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    DEBUG: bool = False
    
    # OpenAI Configuration
    OPENAI_API_KEY: str
    OPENAI_MODEL: str = "gpt-4-turbo-preview"
    EMBEDDING_MODEL: str = "text-embedding-3-small"
    
    # Vector Database
    VECTOR_DB_TYPE: str = "chroma"
    CHROMA_PERSIST_DIR: str = "/app/data/embeddings"
    CHROMA_COLLECTION_NAME: str = "like2share_knowledge"
    
    # PostgreSQL
    DATABASE_URL: str
    CHAT_HISTORY_TABLE: str = "chat_messages"
    
    # RAG Configuration
    CHUNK_SIZE: int = 1000
    CHUNK_OVERLAP: int = 200
    TOP_K_RESULTS: int = 5
    TEMPERATURE: float = 0.7
    MAX_TOKENS: int = 500
    
    # Document Storage
    DOCUMENTS_PATH: str = "/app/data/documents"
    ALLOWED_EXTENSIONS: List[str] = [".pdf", ".txt", ".md", ".docx", ".html"]
    
    # Redis
    REDIS_URL: str = "redis://redis:6379/0"
    CACHE_TTL: int = 3600
    
    # Backend Integration
    BACKEND_API_URL: str = "http://backend:8080"
    BACKEND_API_KEY: str = ""
    
    # CORS
    CORS_ORIGINS: List[str] = ["*"]
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
