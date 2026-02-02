from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime

class ChatRequest(BaseModel):
    message: str = Field(..., description="User's message to the chatbot")
    user_id: str = Field(..., description="Unique user identifier")
    conversation_id: Optional[str] = Field(None, description="Conversation ID for context")
    context: Optional[Dict[str, Any]] = Field(None, description="Additional context")

class SourceDocument(BaseModel):
    content: str
    metadata: Dict[str, Any]
    relevance_score: float

class ChatResponse(BaseModel):
    message: str = Field(..., description="Chatbot's response")
    conversation_id: str
    sources: Optional[List[SourceDocument]] = Field(None, description="Source documents used")
    metadata: Optional[Dict[str, Any]] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class ChatHistory(BaseModel):
    id: str
    conversation_id: str
    user_id: str
    user_message: str
    bot_response: str
    timestamp: datetime
    metadata: Optional[Dict[str, Any]] = None

class DocumentUploadResponse(BaseModel):
    document_id: str
    filename: str
    status: str
    chunks_created: int
    message: str

class HealthResponse(BaseModel):
    status: str
    service: str
    version: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
