import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for communicating with the Like2Share RAG Chatbot
class ChatbotService {
  final String baseUrl;
  final String? apiKey;
  
  ChatbotService({
    required this.baseUrl,
    this.apiKey,
  });

  /// Send a message to the chatbot
  Future<ChatResponse> sendMessage({
    required String message,
    required String userId,
    String? conversationId,
    Map<String, dynamic>? context,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/chat/message'),
        headers: {
          'Content-Type': 'application/json',
          if (apiKey != null) 'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'message': message,
          'user_id': userId,
          if (conversationId != null) 'conversation_id': conversationId,
          if (context != null) 'context': context,
        }),
      );

      if (response.statusCode == 200) {
        return ChatResponse.fromJson(jsonDecode(response.body));
      } else {
        throw ChatbotException(
          'Failed to send message: ${response.statusCode}',
          response.body,
        );
      }
    } catch (e) {
      throw ChatbotException('Network error: $e');
    }
  }

  /// Get chat history for a user
  Future<List<ChatHistoryItem>> getChatHistory({
    required String userId,
    String? conversationId,
    int limit = 50,
  }) async {
    try {
      final queryParams = {
        if (conversationId != null) 'conversation_id': conversationId,
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/v1/chat/history/$userId')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          if (apiKey != null) 'Authorization': 'Bearer $apiKey',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => ChatHistoryItem.fromJson(item)).toList();
      } else {
        throw ChatbotException(
          'Failed to get history: ${response.statusCode}',
          response.body,
        );
      }
    } catch (e) {
      throw ChatbotException('Network error: $e');
    }
  }

  /// Clear a conversation
  Future<void> clearConversation(String conversationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/chat/history/$conversationId'),
        headers: {
          if (apiKey != null) 'Authorization': 'Bearer $apiKey',
        },
      );

      if (response.statusCode != 200) {
        throw ChatbotException(
          'Failed to clear conversation: ${response.statusCode}',
          response.body,
        );
      }
    } catch (e) {
      throw ChatbotException('Network error: $e');
    }
  }

  /// Upload a document to the knowledge base
  Future<DocumentUploadResponse> uploadDocument({
    required String filePath,
    String? userId,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/v1/documents/upload'),
      );

      if (apiKey != null) {
        request.headers['Authorization'] = 'Bearer $apiKey';
      }

      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      if (userId != null) {
        request.fields['user_id'] = userId;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return DocumentUploadResponse.fromJson(jsonDecode(response.body));
      } else {
        throw ChatbotException(
          'Failed to upload document: ${response.statusCode}',
          response.body,
        );
      }
    } catch (e) {
      throw ChatbotException('Network error: $e');
    }
  }

  /// Check chatbot health
  Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/health'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// Chat response model
class ChatResponse {
  final String message;
  final String conversationId;
  final List<SourceDocument>? sources;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  ChatResponse({
    required this.message,
    required this.conversationId,
    this.sources,
    this.metadata,
    required this.timestamp,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      message: json['message'],
      conversationId: json['conversation_id'],
      sources: json['sources'] != null
          ? (json['sources'] as List)
              .map((s) => SourceDocument.fromJson(s))
              .toList()
          : null,
      metadata: json['metadata'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Source document model
class SourceDocument {
  final String content;
  final Map<String, dynamic> metadata;
  final double relevanceScore;

  SourceDocument({
    required this.content,
    required this.metadata,
    required this.relevanceScore,
  });

  factory SourceDocument.fromJson(Map<String, dynamic> json) {
    return SourceDocument(
      content: json['content'],
      metadata: json['metadata'],
      relevanceScore: json['relevance_score'].toDouble(),
    );
  }
}

/// Chat history item model
class ChatHistoryItem {
  final String id;
  final String conversationId;
  final String userId;
  final String userMessage;
  final String botResponse;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ChatHistoryItem({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.userMessage,
    required this.botResponse,
    required this.timestamp,
    this.metadata,
  });

  factory ChatHistoryItem.fromJson(Map<String, dynamic> json) {
    return ChatHistoryItem(
      id: json['id'],
      conversationId: json['conversation_id'],
      userId: json['user_id'],
      userMessage: json['user_message'],
      botResponse: json['bot_response'],
      timestamp: DateTime.parse(json['timestamp']),
      metadata: json['metadata'],
    );
  }
}

/// Document upload response model
class DocumentUploadResponse {
  final String documentId;
  final String filename;
  final String status;
  final int chunksCreated;
  final String message;

  DocumentUploadResponse({
    required this.documentId,
    required this.filename,
    required this.status,
    required this.chunksCreated,
    required this.message,
  });

  factory DocumentUploadResponse.fromJson(Map<String, dynamic> json) {
    return DocumentUploadResponse(
      documentId: json['document_id'],
      filename: json['filename'],
      status: json['status'],
      chunksCreated: json['chunks_created'],
      message: json['message'],
    );
  }
}

/// Chatbot exception
class ChatbotException implements Exception {
  final String message;
  final String? details;

  ChatbotException(this.message, [this.details]);

  @override
  String toString() => details != null ? '$message: $details' : message;
}
