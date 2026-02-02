from typing import List, Dict, Any, Optional
import logging
from langchain_community.vectorstores import Chroma
from langchain_openai import OpenAIEmbeddings
from langchain.schema import Document

from ..core.config import settings

logger = logging.getLogger(__name__)

class VectorStoreManager:
    """Manages vector store operations for RAG."""
    
    def __init__(self):
        self.embeddings = None
        self.vector_store = None
        self.collection_name = settings.CHROMA_COLLECTION_NAME
        
    async def initialize(self):
        """Initialize the vector store and embeddings."""
        try:
            # Initialize embeddings
            self.embeddings = OpenAIEmbeddings(
                model=settings.EMBEDDING_MODEL,
                openai_api_key=settings.OPENAI_API_KEY
            )
            
            # Initialize Chroma vector store
            self.vector_store = Chroma(
                collection_name=self.collection_name,
                embedding_function=self.embeddings,
                persist_directory=settings.CHROMA_PERSIST_DIR
            )
            
            logger.info(f"Vector store initialized: {self.collection_name}")
            
        except Exception as e:
            logger.error(f"Failed to initialize vector store: {e}")
            raise
    
    async def add_documents(
        self, 
        documents: List[Document],
        ids: Optional[List[str]] = None
    ) -> List[str]:
        """Add documents to the vector store."""
        try:
            if not self.vector_store:
                raise ValueError("Vector store not initialized")
            
            doc_ids = self.vector_store.add_documents(
                documents=documents,
                ids=ids
            )
            
            logger.info(f"Added {len(documents)} documents to vector store")
            return doc_ids
            
        except Exception as e:
            logger.error(f"Error adding documents: {e}")
            raise
    
    async def similarity_search(
        self,
        query: str,
        k: int = None,
        filter: Optional[Dict[str, Any]] = None
    ) -> List[Document]:
        """Perform similarity search."""
        try:
            if not self.vector_store:
                raise ValueError("Vector store not initialized")
            
            k = k or settings.TOP_K_RESULTS
            
            results = self.vector_store.similarity_search(
                query=query,
                k=k,
                filter=filter
            )
            
            logger.info(f"Found {len(results)} similar documents for query")
            return results
            
        except Exception as e:
            logger.error(f"Error in similarity search: {e}")
            raise
    
    async def similarity_search_with_score(
        self,
        query: str,
        k: int = None,
        filter: Optional[Dict[str, Any]] = None
    ) -> List[tuple[Document, float]]:
        """Perform similarity search with relevance scores."""
        try:
            if not self.vector_store:
                raise ValueError("Vector store not initialized")
            
            k = k or settings.TOP_K_RESULTS
            
            results = self.vector_store.similarity_search_with_score(
                query=query,
                k=k,
                filter=filter
            )
            
            return results
            
        except Exception as e:
            logger.error(f"Error in similarity search with score: {e}")
            raise
    
    async def delete_documents(self, ids: List[str]) -> bool:
        """Delete documents by IDs."""
        try:
            if not self.vector_store:
                raise ValueError("Vector store not initialized")
            
            self.vector_store.delete(ids=ids)
            logger.info(f"Deleted {len(ids)} documents from vector store")
            return True
            
        except Exception as e:
            logger.error(f"Error deleting documents: {e}")
            raise
    
    def get_retriever(self, k: int = None):
        """Get a retriever interface for the vector store."""
        if not self.vector_store:
            raise ValueError("Vector store not initialized")
        
        k = k or settings.TOP_K_RESULTS
        return self.vector_store.as_retriever(search_kwargs={"k": k})
