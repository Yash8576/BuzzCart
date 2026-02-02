from fastapi import Request
from ..rag.chat_engine import ChatEngine
from ..rag.document_processor import DocumentProcessor

async def get_chat_engine(request: Request) -> ChatEngine:
    """Dependency to get the chat engine instance."""
    return ChatEngine(request.app.state.vector_store)

async def get_document_processor(request: Request) -> DocumentProcessor:
    """Dependency to get the document processor instance."""
    return DocumentProcessor(request.app.state.vector_store)
