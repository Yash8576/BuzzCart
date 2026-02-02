# RAG Chatbot Integration Guide

This guide explains how to integrate the RAG-powered chatbot into your Like2Share application.

## Quick Start

### 1. Start the Chatbot Service

**Using Docker Compose (Recommended):**
```bash
cd docker
docker-compose up chatbot redis
```

**Using Python directly:**
```bash
cd chatbot
cp .env.example .env
# Edit .env with your configuration
pip install -r requirements.txt
uvicorn src.api.main:app --reload
```

### 2. Configure Environment Variables

Create a `.env` file in the `chatbot` directory:
```bash
# Required
OPENAI_API_KEY=sk-your-openai-api-key
DATABASE_URL=postgresql://user:password@localhost:5432/like2share_db

# Optional (defaults provided)
REDIS_URL=redis://localhost:6379/0
BACKEND_API_URL=http://localhost:8080
```

### 3. Test the Chatbot

```bash
# Health check
curl http://localhost:8000/api/v1/health

# Send a test message
curl -X POST http://localhost:8000/api/v1/chat/message \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello, what can you help me with?",
    "user_id": "test-user"
  }'
```

## Adding Knowledge to the Chatbot

### Upload Documents

You can upload documents to populate the chatbot's knowledge base:

```bash
curl -X POST http://localhost:8000/api/v1/documents/upload \
  -F "file=@docs/user-guide.pdf" \
  -F "user_id=admin"
```

Supported formats:
- PDF (.pdf)
- Text (.txt)
- Markdown (.md)
- Word (.docx)
- HTML (.html)

### Recommended Documents to Upload

1. **Platform Documentation**
   - User guide
   - Feature descriptions
   - FAQ

2. **Policy Documents**
   - Terms of service
   - Community guidelines
   - Privacy policy

3. **Help Articles**
   - Troubleshooting guides
   - How-to tutorials
   - Best practices

## Frontend Integration

### 1. Add the Chatbot Service

The chatbot service is already created at:
`frontend/lib/shared/services/chatbot_service.dart`

### 2. Configure the Service

In your app initialization:

```dart
import 'package:your_app/shared/services/chatbot_service.dart';

final chatbotService = ChatbotService(
  baseUrl: 'http://localhost:8000', // Or your production URL
  apiKey: null, // Optional: Add if you implement API key authentication
);
```

### 3. Use the Chatbot Widget

```dart
import 'package:your_app/shared/widgets/chatbot_widget.dart';
import 'package:your_app/shared/services/chatbot_service.dart';

class HomePage extends StatelessWidget {
  final ChatbotService chatbotService;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: YourContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => Container(
              height: MediaQuery.of(context).size.height * 0.8,
              child: ChatbotWidget(
                userId: userId,
                chatbotService: chatbotService,
              ),
            ),
          );
        },
        child: Icon(Icons.chat),
      ),
    );
  }
}
```

### 4. Full-Screen Chat Page

```dart
import 'package:flutter/material.dart';
import 'package:your_app/shared/widgets/chatbot_widget.dart';

class ChatPage extends StatelessWidget {
  final String userId;
  final ChatbotService chatbotService;

  const ChatPage({
    required this.userId,
    required this.chatbotService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Help & Support')),
      body: ChatbotWidget(
        userId: userId,
        chatbotService: chatbotService,
      ),
    );
  }
}
```

## Backend Integration

### 1. Add Chatbot Context Endpoint (Optional)

You can create an endpoint in your Go backend to provide user context:

```go
// backend/internal/handlers/chatbot.go
package handlers

type ChatbotContext struct {
    UserID        string   `json:"user_id"`
    Username      string   `json:"username"`
    MemberSince   string   `json:"member_since"`
    PostCount     int      `json:"post_count"`
    FollowerCount int      `json:"follower_count"`
    Preferences   []string `json:"preferences"`
}

func GetChatbotContext(c *gin.Context) {
    userID := c.Param("userId")
    
    // Fetch user data from database
    context := ChatbotContext{
        UserID:        userID,
        Username:      "john_doe",
        MemberSince:   "2024-01-15",
        PostCount:     42,
        FollowerCount: 150,
        Preferences:   []string{"tech", "sports"},
    }
    
    c.JSON(200, context)
}
```

### 2. Configure CORS (if needed)

Ensure your backend allows requests from the chatbot service:

```go
// backend/cmd/main.go
router.Use(cors.New(cors.Config{
    AllowOrigins: []string{
        "http://localhost:8000",  // Chatbot service
        "http://localhost:80",    // Frontend
    },
    AllowMethods: []string{"GET", "POST", "PUT", "DELETE"},
    AllowHeaders: []string{"Origin", "Content-Type", "Authorization"},
}))
```

## Deployment

### Kubernetes

The chatbot is configured for Kubernetes deployment:

```bash
# Apply configurations
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/redis/deployment.yaml
kubectl apply -f k8s/chatbot/deployment.yaml
kubectl apply -f k8s/chatbot/service.yaml
kubectl apply -f k8s/chatbot/hpa.yaml
```

Update secrets:
```bash
# Edit k8s/secrets.yaml and replace:
# - CHANGE_ME_IN_PRODUCTION with your database password
# - Your OpenAI API key
# - Backend API key

kubectl apply -f k8s/secrets.yaml
```

### Production Checklist

- [ ] Update `OPENAI_API_KEY` in secrets
- [ ] Set strong `DATABASE_URL` password
- [ ] Configure `BACKEND_API_KEY` for secure communication
- [ ] Set `DEBUG=false` in production
- [ ] Configure appropriate resource limits
- [ ] Set up monitoring and logging
- [ ] Configure persistent volumes for documents and embeddings
- [ ] Set up regular backups of vector database
- [ ] Implement rate limiting
- [ ] Add authentication/authorization

## Customization

### Custom Prompts

Edit prompts in `chatbot/config/prompts.yaml`:

```yaml
custom_prompt: |
  You are a specialized assistant for...
  {context}
  {question}
```

Then update the chat engine to use your custom prompt.

### Different LLM Models

Change the model in `.env`:
```bash
# Use GPT-3.5 for cost savings
OPENAI_MODEL=gpt-3.5-turbo

# Use GPT-4 for better quality
OPENAI_MODEL=gpt-4-turbo-preview
```

### Vector Database Options

Switch to Pinecone or Qdrant:
```bash
VECTOR_DB_TYPE=pinecone
PINECONE_API_KEY=your-key
PINECONE_ENVIRONMENT=your-env
PINECONE_INDEX=like2share
```

### Tuning RAG Parameters

Adjust in `.env`:
```bash
CHUNK_SIZE=1000          # Smaller = more precise, larger = more context
CHUNK_OVERLAP=200        # Overlap between chunks
TOP_K_RESULTS=5          # Number of documents to retrieve
TEMPERATURE=0.7          # 0 = deterministic, 1 = creative
MAX_TOKENS=500           # Response length limit
```

## Monitoring

### Health Checks

```bash
# Service health
curl http://localhost:8000/api/v1/health

# Check vector store
curl http://localhost:8000/api/v1/documents/list
```

### Logs

```bash
# Docker
docker logs like2share_chatbot

# Kubernetes
kubectl logs -f deployment/chatbot -n like2share
```

## Troubleshooting

### Common Issues

**"Vector store not initialized"**
- Ensure ChromaDB directory is writable
- Check OpenAI API key is valid

**"Database connection failed"**
- Verify PostgreSQL is running
- Check DATABASE_URL format

**"Out of memory"**
- Reduce CHUNK_SIZE and TOP_K_RESULTS
- Use smaller embedding model

**"Rate limit exceeded"**
- Implement caching
- Use Redis for response caching
- Consider using a different LLM provider

## Support

For issues or questions:
1. Check the logs
2. Review the [chatbot/README.md](../chatbot/README.md)
3. Contact the development team
