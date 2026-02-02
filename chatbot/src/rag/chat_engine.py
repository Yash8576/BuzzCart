from typing import List, Optional, Dict, Any
import logging
from datetime import datetime
import uuid

from langchain_openai import ChatOpenAI
from langchain.chains import ConversationalRetrievalChain
from langchain.memory import ConversationBufferMemory
from langchain.prompts import PromptTemplate

from ..core.config import settings
from .vector_store import VectorStoreManager
from ..api.schemas import ChatResponse, SourceDocument, ChatHistory
from ..db.chat_history import ChatHistoryManager

logger = logging.getLogger(__name__)

class ChatEngine:
    """RAG-powered chat engine for the Like2Share platform."""
    
    def __init__(self, vector_store: VectorStoreManager):
        self.vector_store = vector_store
        self.llm = ChatOpenAI(
            model=settings.OPENAI_MODEL,
            temperature=settings.TEMPERATURE,
            max_tokens=settings.MAX_TOKENS,
            openai_api_key=settings.OPENAI_API_KEY
        )
        self.history_manager = ChatHistoryManager()
        
        # Define the prompt template
        self.prompt_template = """You are a helpful AI assistant for Like2Share, a social media platform. 
Use the following pieces of context to answer the user's question. If you don't know the answer, 
just say that you don't know, don't try to make up an answer.

Context: {context}

Chat History: {chat_history}

Question: {question}

Provide a helpful, friendly, and accurate response:"""
        
        self.PROMPT = PromptTemplate(
            template=self.prompt_template,
            input_variables=["context", "chat_history", "question"]
        )
    
    async def generate_response(
        self,
        query: str,
        user_id: str,
        conversation_id: Optional[str] = None,
        context: Optional[Dict[str, Any]] = None
    ) -> ChatResponse:
        """Generate a RAG-powered response to the user's query."""
        try:
            # Generate conversation ID if not provided
            if not conversation_id:
                conversation_id = str(uuid.uuid4())
            
            # Retrieve relevant documents
            relevant_docs = await self.vector_store.similarity_search_with_score(
                query=query,
                k=settings.TOP_K_RESULTS
            )
            
            # Get chat history
            history = await self.history_manager.get_conversation_history(
                conversation_id,
                limit=5
            )
            
            # Prepare memory
            memory = ConversationBufferMemory(
                memory_key="chat_history",
                return_messages=True,
                output_key="answer"
            )
            
            # Add history to memory
            for msg in history:
                memory.chat_memory.add_user_message(msg["user_message"])
                memory.chat_memory.add_ai_message(msg["bot_response"])
            
            # Create retrieval chain
            qa_chain = ConversationalRetrievalChain.from_llm(
                llm=self.llm,
                retriever=self.vector_store.get_retriever(),
                memory=memory,
                combine_docs_chain_kwargs={"prompt": self.PROMPT},
                return_source_documents=True,
                verbose=settings.DEBUG
            )
            
            # Generate response
            result = qa_chain({"question": query})
            
            # Format source documents
            sources = [
                SourceDocument(
                    content=doc.page_content,
                    metadata=doc.metadata,
                    relevance_score=score
                )
                for doc, score in relevant_docs
            ]
            
            # Save to history
            await self.history_manager.save_message(
                conversation_id=conversation_id,
                user_id=user_id,
                user_message=query,
                bot_response=result["answer"],
                metadata={
                    "sources_count": len(sources),
                    "context": context
                }
            )
            
            return ChatResponse(
                message=result["answer"],
                conversation_id=conversation_id,
                sources=sources,
                metadata={"model": settings.OPENAI_MODEL}
            )
            
        except Exception as e:
            logger.error(f"Error generating response: {e}")
            raise
    
    async def get_history(
        self,
        user_id: str,
        conversation_id: Optional[str] = None,
        limit: int = 50
    ) -> List[ChatHistory]:
        """Retrieve chat history."""
        try:
            if conversation_id:
                messages = await self.history_manager.get_conversation_history(
                    conversation_id, limit
                )
            else:
                messages = await self.history_manager.get_user_history(
                    user_id, limit
                )
            
            return [
                ChatHistory(
                    id=msg["id"],
                    conversation_id=msg["conversation_id"],
                    user_id=msg["user_id"],
                    user_message=msg["user_message"],
                    bot_response=msg["bot_response"],
                    timestamp=msg["timestamp"],
                    metadata=msg.get("metadata")
                )
                for msg in messages
            ]
            
        except Exception as e:
            logger.error(f"Error retrieving history: {e}")
            raise
    
    async def clear_history(self, conversation_id: str):
        """Clear conversation history."""
        try:
            await self.history_manager.delete_conversation(conversation_id)
            logger.info(f"Cleared conversation: {conversation_id}")
        except Exception as e:
            logger.error(f"Error clearing history: {e}")
            raise
