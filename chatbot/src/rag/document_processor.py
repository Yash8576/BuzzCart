from typing import List, Optional
import logging
import os
import uuid
from pathlib import Path

from fastapi import UploadFile
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.schema import Document
from langchain_community.document_loaders import (
    PyPDFLoader, TextLoader, UnstructuredMarkdownLoader,
    Docx2txtLoader, UnstructuredHTMLLoader
)

from ..core.config import settings
from .vector_store import VectorStoreManager
from ..api.schemas import DocumentUploadResponse

logger = logging.getLogger(__name__)

class DocumentProcessor:
    """Handles document processing and ingestion for RAG."""
    
    def __init__(self, vector_store: VectorStoreManager):
        self.vector_store = vector_store
        self.text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=settings.CHUNK_SIZE,
            chunk_overlap=settings.CHUNK_OVERLAP,
            length_function=len,
        )
        
        # Create documents directory if it doesn't exist
        os.makedirs(settings.DOCUMENTS_PATH, exist_ok=True)
    
    async def process_upload(
        self,
        file: UploadFile,
        user_id: Optional[str] = None
    ) -> DocumentUploadResponse:
        """Process an uploaded document."""
        try:
            # Validate file extension
            file_ext = Path(file.filename).suffix.lower()
            if file_ext not in settings.ALLOWED_EXTENSIONS:
                raise ValueError(
                    f"File type {file_ext} not allowed. "
                    f"Allowed types: {settings.ALLOWED_EXTENSIONS}"
                )
            
            # Generate unique ID and save file
            doc_id = str(uuid.uuid4())
            file_path = os.path.join(
                settings.DOCUMENTS_PATH,
                f"{doc_id}_{file.filename}"
            )
            
            # Save uploaded file
            with open(file_path, "wb") as f:
                content = await file.read()
                f.write(content)
            
            # Load and process document
            documents = await self._load_document(file_path, file_ext)
            
            # Add metadata
            for doc in documents:
                doc.metadata.update({
                    "document_id": doc_id,
                    "filename": file.filename,
                    "user_id": user_id,
                    "source": file_path
                })
            
            # Split into chunks
            chunks = self.text_splitter.split_documents(documents)
            
            # Add to vector store
            chunk_ids = [f"{doc_id}_{i}" for i in range(len(chunks))]
            await self.vector_store.add_documents(chunks, ids=chunk_ids)
            
            logger.info(
                f"Processed document {file.filename}: "
                f"{len(chunks)} chunks created"
            )
            
            return DocumentUploadResponse(
                document_id=doc_id,
                filename=file.filename,
                status="success",
                chunks_created=len(chunks),
                message=f"Document processed successfully with {len(chunks)} chunks"
            )
            
        except Exception as e:
            logger.error(f"Error processing document: {e}")
            raise
    
    async def _load_document(
        self,
        file_path: str,
        file_ext: str
    ) -> List[Document]:
        """Load document based on file type."""
        try:
            if file_ext == ".pdf":
                loader = PyPDFLoader(file_path)
            elif file_ext == ".txt":
                loader = TextLoader(file_path, encoding="utf-8")
            elif file_ext == ".md":
                loader = UnstructuredMarkdownLoader(file_path)
            elif file_ext == ".docx":
                loader = Docx2txtLoader(file_path)
            elif file_ext == ".html":
                loader = UnstructuredHTMLLoader(file_path)
            else:
                raise ValueError(f"Unsupported file type: {file_ext}")
            
            documents = loader.load()
            return documents
            
        except Exception as e:
            logger.error(f"Error loading document: {e}")
            raise
    
    async def list_documents(self) -> List[Dict]:
        """List all documents in the knowledge base."""
        try:
            documents = []
            for filename in os.listdir(settings.DOCUMENTS_PATH):
                file_path = os.path.join(settings.DOCUMENTS_PATH, filename)
                if os.path.isfile(file_path):
                    doc_id = filename.split("_")[0]
                    original_name = "_".join(filename.split("_")[1:])
                    documents.append({
                        "document_id": doc_id,
                        "filename": original_name,
                        "path": file_path,
                        "size": os.path.getsize(file_path)
                    })
            
            return documents
            
        except Exception as e:
            logger.error(f"Error listing documents: {e}")
            raise
    
    async def delete_document(self, document_id: str):
        """Delete a document from the knowledge base."""
        try:
            # Find and delete file
            for filename in os.listdir(settings.DOCUMENTS_PATH):
                if filename.startswith(document_id):
                    file_path = os.path.join(settings.DOCUMENTS_PATH, filename)
                    os.remove(file_path)
                    logger.info(f"Deleted file: {file_path}")
            
            # Delete from vector store (find all chunk IDs)
            # Note: This is a simplified approach
            # In production, you'd want to track chunk IDs in a database
            logger.warning(
                f"Vector store cleanup for document {document_id} "
                "may require manual intervention"
            )
            
        except Exception as e:
            logger.error(f"Error deleting document: {e}")
            raise
