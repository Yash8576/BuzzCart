import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import '../models/models.dart';

class ApiService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  late final Dio _dio;
  String? _token;
  bool _isTokenLoaded = false;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Add interceptors
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Ensure token is loaded before making requests
        if (!_isTokenLoaded) {
          await _loadToken();
        }
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        debugPrint('API Error: ${error.message}');
        return handler.next(error);
      },
    ));
  }

  Future<void> _loadToken() async {
    if (_isTokenLoaded) return;
    
    try {
      _token = await _storage.read(key: 'buzz_token');
      if (_token != null) {
        _dio.options.headers['Authorization'] = 'Bearer $_token';
        debugPrint('Token loaded successfully');
      } else {
        debugPrint('No token found in storage');
      }
    } catch (e) {
      debugPrint('Error loading token: $e');
    } finally {
      _isTokenLoaded = true;
    }
  }

  // Public method to ensure token is loaded
  Future<void> ensureTokenLoaded() async {
    await _loadToken();
  }

  // Check if user has a token (is potentially logged in)
  Future<bool> hasToken() async {
    await _loadToken();
    return _token != null;
  }

  String? get currentToken => _token;

  Future<void> _saveToken(String token) async {
    _token = token;
    await _storage.write(key: 'buzz_token', value: token);
    _dio.options.headers['Authorization'] = 'Bearer $_token';
  }

  Future<void> _clearToken() async {
    _token = null;
    await _storage.delete(key: 'buzz_token');
    _dio.options.headers.remove('Authorization');
  }

  // Auth APIs
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final token = response.data['access_token'] as String;
      await _saveToken(token);

      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String name, {
    String accountType = 'CONSUMER',
    String privacyProfile = 'PUBLIC',
    String? phoneNumber,
  }) async {
    try {
      // Map account type to role and convert to lowercase for backend
      final accountTypeLower = accountType.toLowerCase();
      String role = accountType == 'SELLER' ? 'seller' : 'consumer';
      
      final data = {
        'email': email,
        'password': password,
        'name': name,
        'account_type': accountTypeLower,
        'role': role,
        'privacy_profile': privacyProfile.toLowerCase(),
      };
      
      // Add phone number if provided
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        data['phone_number'] = phoneNumber;
      }
      
      final response = await _dio.post('/auth/register', data: data);

      final token = response.data['access_token'] as String;
      await _saveToken(token);

      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel> getUser(String userId) async {
    try {
      final response = await _dio.get('/users/$userId');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // INSTAGRAM-STYLE FEED & POST APIs
  // ============================================================================

  /// Get followers feed (posts from people you follow)
  /// Uses cursor-based pagination for infinite scroll
  Future<FeedResponse> getFollowersFeed({
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
      };
      if (cursor != null) {
        queryParams['cursor'] = cursor;
      }

      final response = await _dio.get(
        '/feed/followers',
        queryParameters: queryParams,
      );

      return FeedResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Get discovery feed (ranked public posts)
  /// Uses pull model  with engagement-based ranking
  Future<FeedResponse> getDiscoveryFeed({
    String? cursor,
    int limit = 20,
    bool excludeFollowing = false,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
      };
      if (cursor != null) {
        queryParams['cursor'] = cursor;
      }
      if (excludeFollowing) {
        queryParams['exclude_following'] = 'true';
      }

      final response = await _dio.get(
        '/feed/discovery',
        queryParameters: queryParams,
      );

      return FeedResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Get posts from a specific user (for profile gallery)
  Future<FeedResponse> getUserPosts({
    required String userId,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
      };
      if (cursor != null) {
        queryParams['cursor'] = cursor;
      }

      final response = await _dio.get(
        '/feed/user/$userId',
        queryParameters: queryParams,
      );

      return FeedResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new post (requires mediaId from uploaded media)
  Future<Map<String, dynamic>> createPost({
    required String mediaId,
    String? caption,
    String visibility = 'followers',
    List<String>? taggedUsers,
    List<String>? hashtags,
  }) async {
    try {
      final data = <String, dynamic>{
        'media_id': mediaId,
      };
      if (caption != null && caption.isNotEmpty) {
        data['caption'] = caption;
      }
      data['visibility'] = visibility;
      if (taggedUsers != null && taggedUsers.isNotEmpty) {
        data['tagged_users'] = taggedUsers;
      }
      if (hashtags != null && hashtags.isNotEmpty) {
        data['hashtags'] = hashtags;
      }

      final response = await _dio.post('/posts', data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Like a post
  Future<void> likePost(String postId) async {
    try {
      await _dio.post('/posts/$postId/like');
    } catch (e) {
      rethrow;
    }
  }

  /// Unlike a post
  Future<void> unlikePost(String postId) async {
    try {
      await _dio.delete('/posts/$postId/like');
    } catch (e) {
      rethrow;
    }
  }

  /// Upload photo with option to create post automatically
  Future<Map<String, dynamic>> uploadPhoto({
    required File imageFile,
    String? caption,
    bool createPost = false,
    String visibility = 'followers',
  }) async {
    try {
      // Ensure token is loaded
      await ensureTokenLoaded();

      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
        if (caption != null && caption.isNotEmpty) 'caption': caption,
        'create_post': createPost.toString(),
        if (createPost) 'visibility': visibility,
      });

      final response = await _dio.post(
        '/upload/user-photo',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/auth/profile', data: data);
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await _clearToken();
  }

  // Feed API
  Future<List<FeedItem>> getFeed() async {
    try {
      final response = await _dio.get('/feed');
      return (response.data as List)
          .map((item) => FeedItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Products APIs
  Future<List<ProductModel>> getProducts({String? category}) async {
    try {
      final response = await _dio.get('/products', queryParameters: {
        if (category != null && category.isNotEmpty) 'category': category,
      });
      return (response.data as List)
          .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<ProductModel> getProduct(String id) async {
    try {
      final response = await _dio.get('/products/$id');
      return ProductModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  // Videos APIs
  Future<List<VideoModel>> getVideos() async {
    try {
      final response = await _dio.get('/videos');
      return (response.data as List)
          .map((item) => VideoModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<VideoModel> getVideo(String id) async {
    try {
      final response = await _dio.get('/videos/$id');
      return VideoModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createVideo({
    required String title,
    required String description,
    required String url,
    required String thumbnail,
    int? duration,
    List<String>? productIds,
  }) async {
    try {
      final response = await _dio.post('/videos', data: {
        'title': title,
        'description': description,
        'url': url,
        'thumbnail': thumbnail,
        if (duration != null) 'duration': duration,
        if (productIds != null && productIds.isNotEmpty) 'product_ids': productIds,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // Reels APIs
  Future<List<ReelModel>> getReels() async {
    try {
      final response = await _dio.get('/reels');
      return (response.data as List)
          .map((item) => ReelModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createReel({
    required String url,
    required String thumbnail,
    String? caption,
    List<String>? productIds,
  }) async {
    try {
      final response = await _dio.post('/reels', data: {
        'url': url,
        'thumbnail': thumbnail,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
        if (productIds != null && productIds.isNotEmpty) 'product_ids': productIds,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // Cart APIs
  Future<CartModel> getCart() async {
    try {
      final response = await _dio.get('/cart');
      return CartModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addToCart(String productId, {int quantity = 1}) async {
    try {
      await _dio.post('/cart/add', data: {
        'product_id': productId,
        'quantity': quantity,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCartQuantity(String productId, int quantity) async {
    try {
      await _dio.put('/cart/update', data: {
        'product_id': productId,
        'quantity': quantity,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeFromCart(String productId) async {
    try {
      await _dio.delete('/cart/remove/$productId');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> clearCart() async {
    try {
      await _dio.delete('/cart/clear');
    } catch (e) {
      rethrow;
    }
  }

  // Search API
  Future<Map<String, dynamic>> search(String query) async {
    try {
      final response = await _dio.get('/search', queryParameters: {'q': query});
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // Messages APIs
  Future<List<dynamic>> getConversations() async {
    try {
      final response = await _dio.get('/messages/conversations');
      return response.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getMessages(String conversationId) async {
    try {
      final response = await _dio.get('/messages/conversations/$conversationId');
      return response.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String content,
    String? productId,
  }) async {
    try {
      final response = await _dio.post('/messages', data: {
        'receiver_id': receiverId,
        'content': content,
        if (productId != null) 'product_id': productId,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // Product Creation API
  Future<ProductModel> createProduct({
    required String title,
    required String description,
    required double price,
    required String category,
    required List<String> images,
    List<String>? tags,
  }) async {
    try {
      final response = await _dio.post('/products', data: {
        'title': title,
        'description': description,
        'price': price,
        'category': category,
        'images': images,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
      });
      return ProductModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  // Upload APIs
  Future<Map<String, dynamic>> uploadImage(File file) async {
    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await _dio.post('/upload/image', data: formData);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadVideo(File file) async {
    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'video': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await _dio.post('/upload/video', data: formData);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadProductImage(File file) async {
    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await _dio.post('/upload/product-image', data: formData);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // Upload user photo with caption (saves to user_media table)
  Future<Map<String, dynamic>> uploadUserPhoto(File file, {String? caption}) async {
    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(file.path, filename: fileName),
        if (caption != null && caption.isNotEmpty) 'caption': caption,
      });

      final response = await _dio.post('/upload/user-photo', data: formData);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // Get user media for profile gallery
  Future<List<MediaItem>> getUserMedia(String userId, {String? type, int limit = 50}) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit.toString(),
        if (type != null) 'type': type,
      };
      
      final response = await _dio.get(
        '/users/$userId/media',
        queryParameters: queryParams,
      );
      return (response.data as List)
          .map((item) => MediaItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
