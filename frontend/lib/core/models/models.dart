// Data models matching the backend API

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? avatar;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final String accountType; // 'SELLER' or 'CONSUMER'
  final String role; // 'consumer', 'seller', or 'admin'
  final String status; // 'active', 'inactive', or 'suspended'
  final bool isVerified;
  final String? phoneNumber;
  final String privacyProfile; // 'PUBLIC' or 'PRIVATE'
  final String createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatar,
    this.bio,
    this.followersCount = 0,
    this.followingCount = 0,
    this.accountType = 'CONSUMER',
    this.role = 'consumer',
    this.status = 'active',
    this.isVerified = false,
    this.phoneNumber,
    this.privacyProfile = 'PUBLIC',
    required this.createdAt,
  });
  
  bool get isSeller => accountType == 'SELLER' || role == 'seller';
  bool get isPrivate => privacyProfile == 'PRIVATE';
  bool get isActive => status == 'active';
  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      bio: json['bio'] as String?,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      accountType: json['account_type'] as String? ?? 'CONSUMER',
      role: json['role'] as String? ?? 'consumer',
      status: json['status'] as String? ?? 'active',
      isVerified: json['is_verified'] as bool? ?? false,
      phoneNumber: json['phone_number'] as String?,
      privacyProfile: json['privacy_profile'] as String? ?? 'PUBLIC',
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar': avatar,
      'bio': bio,
      'followers_count': followersCount,
      'following_count': followingCount,
      'account_type': accountType,
      'role': role,
      'status': status,
      'is_verified': isVerified,
      'phone_number': phoneNumber,
      'privacy_profile': privacyProfile,
      'created_at': createdAt,
    };
  }
}

class ProductModel {
  final String id;
  final String title;
  final String description;
  final double price;
  final List<String> images;
  final String category;
  final List<String> tags;
  final String sellerId;
  final String sellerName;
  final double rating;
  final int reviewsCount;
  final int views;
  final String createdAt;

  ProductModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.images,
    required this.category,
    required this.tags,
    required this.sellerId,
    required this.sellerName,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.views = 0,
    required this.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      images: List<String>.from(json['images'] as List? ?? []),
      category: json['category'] as String,
      tags: List<String>.from(json['tags'] as List? ?? []),
      sellerId: json['seller_id'] as String,
      sellerName: json['seller_name'] as String,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: json['reviews_count'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      createdAt: json['created_at'] as String,
    );
  }
}

class VideoModel {
  final String id;
  final String title;
  final String description;
  final String url;
  final String thumbnail;
  final int duration;
  final int views;
  final int likes;
  final String creatorId;
  final String creatorName;
  final String? creatorAvatar;
  final List<ProductModel> products;
  final String createdAt;

  VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.thumbnail,
    required this.duration,
    this.views = 0,
    this.likes = 0,
    required this.creatorId,
    required this.creatorName,
    this.creatorAvatar,
    this.products = const [],
    required this.createdAt,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      url: json['url'] as String,
      thumbnail: json['thumbnail'] as String,
      duration: json['duration'] as int,
      views: json['views'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      creatorId: json['creator_id'] as String,
      creatorName: json['creator_name'] as String,
      creatorAvatar: json['creator_avatar'] as String?,
      products: (json['products'] as List?)
              ?.map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] as String,
    );
  }
}

class ReelModel {
  final String id;
  final String url;
  final String thumbnail;
  final String caption;
  final int views;
  final int likes;
  final String creatorId;
  final String creatorName;
  final String? creatorAvatar;
  final List<ProductModel> products;
  final String createdAt;

  ReelModel({
    required this.id,
    required this.url,
    required this.thumbnail,
    required this.caption,
    this.views = 0,
    this.likes = 0,
    required this.creatorId,
    required this.creatorName,
    this.creatorAvatar,
    this.products = const [],
    required this.createdAt,
  });

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    return ReelModel(
      id: json['id'] as String,
      url: json['url'] as String,
      thumbnail: json['thumbnail'] as String,
      caption: json['caption'] as String? ?? '',
      views: json['views'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      creatorId: json['creator_id'] as String,
      creatorName: json['creator_name'] as String,
      creatorAvatar: json['creator_avatar'] as String?,
      products: (json['products'] as List?)
              ?.map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] as String,
    );
  }
}

class CartItemModel {
  final ProductModel product;
  final int quantity;

  CartItemModel({
    required this.product,
    required this.quantity,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      product: ProductModel.fromJson(json['product'] as Map<String, dynamic>),
      quantity: json['quantity'] as int,
    );
  }
}

class CartModel {
  final List<CartItemModel> items;
  final double subtotal;
  final double total;
  final int itemCount;

  CartModel({
    required this.items,
    required this.subtotal,
    required this.total,
    required this.itemCount,
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    return CartModel(
      items: (json['items'] as List)
          .map((item) => CartItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      itemCount: json['item_count'] as int,
    );
  }

  factory CartModel.empty() {
    return CartModel(
      items: [],
      subtotal: 0,
      total: 0,
      itemCount: 0,
    );
  }
}

class FeedItem {
  final String type; // 'product', 'video', 'reel'
  final dynamic data; // ProductModel, VideoModel, or ReelModel

  FeedItem({
    required this.type,
    required this.data,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final data = json['data'] as Map<String, dynamic>;

    dynamic parsedData;
    switch (type) {
      case 'product':
        parsedData = ProductModel.fromJson(data);
        break;
      case 'video':
        parsedData = VideoModel.fromJson(data);
        break;
      case 'reel':
        parsedData = ReelModel.fromJson(data);
        break;
      default:
        throw Exception('Unknown feed item type: $type');
    }

    return FeedItem(
      type: type,
      data: parsedData,
    );
  }
}

// ============================================================================
// INSTAGRAM-STYLE POST MODELS
// ============================================================================

class PostModel {
  final String id;
  final String userId;
  final String mediaId;
  final String caption;
  final String mediaType; // 'photo', 'video', 'reel'
  final String mediaUrl;
  final String? thumbnailUrl;
  final bool isPrivate;
  final String visibility; // 'followers', 'public', 'close_friends'
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int viewCount;
  final String createdAt;
  final String updatedAt;
  
  // Author info (populated from join)
  final String authorName;
  final String? authorAvatar;
  final bool authorVerified;
  
  // User interaction state
  final bool isLiked;
  final bool isFollowing;

  PostModel({
    required this.id,
    required this.userId,
    required this.mediaId,
    required this.caption,
    required this.mediaType,
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.isPrivate,
    required this.visibility,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.viewCount = 0,
    required this.createdAt,
    required this.updatedAt,
    required this.authorName,
    this.authorAvatar,
    this.authorVerified = false,
    this.isLiked = false,
    this.isFollowing = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mediaId: json['media_id'] as String,
      caption: json['caption'] as String? ?? '',
      mediaType: json['media_type'] as String,
      mediaUrl: json['media_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      isPrivate: json['is_private'] as bool? ?? false,
      visibility: json['visibility'] as String? ?? 'followers',
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      shareCount: json['share_count'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      authorName: json['author_name'] as String,
      authorAvatar: json['author_avatar'] as String?,
      authorVerified: json['author_verified'] as bool? ?? false,
      isLiked: json['is_liked'] as bool? ?? false,
      isFollowing: json['is_following'] as bool? ?? false,
    );
  }

  bool get isPhoto => mediaType == 'photo';
  bool get isVideo => mediaType == 'video' || mediaType == 'reel';

  PostModel copyWith({
    bool? isLiked,
    int? likeCount,
    int? commentCount,
    bool? isFollowing,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      mediaId: mediaId,
      caption: caption,
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      isPrivate: isPrivate,
      visibility: visibility,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount,
      viewCount: viewCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorVerified: authorVerified,
      isLiked: isLiked ?? this.isLiked,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

class FeedResponse {
  final List<PostModel> posts;
  final String? nextCursor;
  final bool hasMore;

  FeedResponse({
    required this.posts,
    this.nextCursor,
    this.hasMore = false,
  });

  factory FeedResponse.fromJson(Map<String, dynamic> json) {
    return FeedResponse(
      posts: (json['posts'] as List?)
              ?.map((p) => PostModel.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

class MediaItem {
  final String id;
  final String mediaType;
  final String mediaUrl;
  final String? thumbnailUrl;
  final String? caption;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final String createdAt;

  MediaItem({
    required this.id,
    required this.mediaType,
    required this.mediaUrl,
    this.thumbnailUrl,
    this.caption,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      mediaType: json['media_type'] as String,
      mediaUrl: json['media_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      caption: json['caption'] as String?,
      viewCount: json['view_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'media_type': mediaType,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
      'caption': caption,
      'view_count': viewCount,
      'like_count': likeCount,
      'comment_count': commentCount,
      'created_at': createdAt,
    };
  }
}
