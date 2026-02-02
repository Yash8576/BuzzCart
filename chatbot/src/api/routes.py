from fastapi import APIRouter, HTTPException, UploadFile, File, Depends
from typing import List, Optional
import logging

from .schemas import (
    ChatRequest, ChatResponse, DocumentUploadResponse,
    HealthResponse, ChatHistory
)
from ..rag.chat_engine import ChatEngine
from ..rag.document_processor import DocumentProcessor
from ..core.dependencies import get_chat_engine, get_document_processor

logger = logging.getLogger(__name__)

# Health check router
health_router = APIRouter()

@health_router.get("/health", response_model=HealthResponse)
async def health_check():
    return HealthResponse(
        status="healthy",
        service="chatbot",
        version="1.0.0"
    )

# Chat router
chat_router = APIRouter()

@chat_router.post("/message", response_model=ChatResponse)
async def send_message(
    request: ChatRequest,
    chat_engine: ChatEngine = Depends(get_chat_engine)
):
    """Send a message to the chatbot and get a RAG-powered response."""
    try:
        response = await chat_engine.generate_response(
            query=request.message,
            user_id=request.user_id,
            conversation_id=request.conversation_id,
            context=request.context
        )
        return response
    except Exception as e:
        logger.error(f"Error generating chat response: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@chat_router.get("/history/{user_id}", response_model=List[ChatHistory])
async def get_chat_history(
    user_id: str,
    conversation_id: Optional[str] = None,
    limit: int = 50,
    chat_engine: ChatEngine = Depends(get_chat_engine)
):
    """Retrieve chat history for a user."""
    try:
        history = await chat_engine.get_history(
            user_id=user_id,
            conversation_id=conversation_id,
            limit=limit
        )
        return history
    except Exception as e:
        logger.error(f"Error retrieving chat history: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@chat_router.delete("/history/{conversation_id}")
async def clear_conversation(
    conversation_id: str,
    chat_engine: ChatEngine = Depends(get_chat_engine)
):
    """Clear a specific conversation history."""
    try:
        await chat_engine.clear_history(conversation_id)
        return {"message": "Conversation cleared successfully"}
    except Exception as e:
        logger.error(f"Error clearing conversation: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Documents router
documents_router = APIRouter()

@documents_router.post("/upload", response_model=DocumentUploadResponse)
async def upload_document(
    file: UploadFile = File(...),
    user_id: Optional[str] = None,
    doc_processor: DocumentProcessor = Depends(get_document_processor)
):
    """Upload and process a document for the knowledge base."""
    try:
        result = await doc_processor.process_upload(file, user_id)
        return result
    except Exception as e:
        logger.error(f"Error uploading document: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@documents_router.get("/list")
async def list_documents(
    doc_processor: DocumentProcessor = Depends(get_document_processor)
):
    """List all documents in the knowledge base."""
    try:
        documents = await doc_processor.list_documents()
        return {"documents": documents}
    except Exception as e:
        logger.error(f"Error listing documents: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@documents_router.delete("/{document_id}")
async def delete_document(
    document_id: str,
    doc_processor: DocumentProcessor = Depends(get_document_processor)
):
    """Delete a document from the knowledge base."""
    try:
        await doc_processor.delete_document(document_id)
        return {"message": "Document deleted successfully"}
    except Exception as e:
        logger.error(f"Error deleting document: {e}")
        raise HTTPException(status_code=500, detail=str(e))
