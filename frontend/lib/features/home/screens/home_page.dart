import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _pageMaxWidth = 760;
  static const double _mediaCardMaxWidth = 560;
  static const double _reelCardMaxWidth = 420;
  static const double _productRailCardWidth = 188;
  static const double _productRailHeight = 278;

  List<_HomeSection> _sections = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }

  Future<void> _fetchFeed() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final currentUserId = context.read<AuthProvider>().user?.id;
      final results = await Future.wait([
        api.getProducts().catchError((_) => <ProductModel>[]),
        api.getDiscoveryFeed(limit: 30).catchError((_) => FeedResponse(posts: [])),
        api.getVideos().catchError((_) => <VideoModel>[]),
        api.getReels().catchError((_) => <ReelModel>[]),
      ]);

      final products = (results[0] as List<ProductModel>)
          .where((product) => product.sellerId != currentUserId)
          .toList()
        ..sort(
          (a, b) => _parseDate(b.createdAt).compareTo(_parseDate(a.createdAt)),
        );

      final posts = (results[1] as FeedResponse).posts
          .where((post) => post.userId != currentUserId)
          .toList()
        ..sort(
          (a, b) => _parseDate(b.createdAt).compareTo(_parseDate(a.createdAt)),
        );

      final publishedMediaUrls = posts
          .where((post) => post.mediaType == 'video' || post.mediaType == 'reel')
          .map((post) => post.mediaUrl)
          .toSet();

      final videos = (results[2] as List<VideoModel>)
          .where(
            (video) =>
                video.creatorId != currentUserId &&
                !publishedMediaUrls.contains(video.url),
          )
          .toList()
        ..sort(
          (a, b) => _parseDate(b.createdAt).compareTo(_parseDate(a.createdAt)),
        );

      final reels = (results[3] as List<ReelModel>)
          .where(
            (reel) =>
                reel.creatorId != currentUserId &&
                !publishedMediaUrls.contains(reel.url),
          )
          .toList()
        ..sort(
          (a, b) => _parseDate(b.createdAt).compareTo(_parseDate(a.createdAt)),
        );

      final sections = _buildRandomizedSections(
        productRails: _chunkProducts(products, 8),
        posts: posts,
        reels: reels,
        videos: videos,
      );

      if (!mounted) return;
      setState(() {
        _sections = sections;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load feed';
        _isLoading = false;
      });
    }
  }

  List<List<ProductModel>> _chunkProducts(List<ProductModel> products, int chunkSize) {
    final chunks = <List<ProductModel>>[];
    for (var i = 0; i < products.length; i += chunkSize) {
      final end = math.min(i + chunkSize, products.length);
      chunks.add(products.sublist(i, end));
    }
    return chunks;
  }

  List<_HomeSection> _buildRandomizedSections({
    required List<List<ProductModel>> productRails,
    required List<PostModel> posts,
    required List<ReelModel> reels,
    required List<VideoModel> videos,
  }) {
    final rails = List<List<ProductModel>>.from(productRails);
    final postQueue = List<PostModel>.from(posts);
    final reelQueue = List<ReelModel>.from(reels);
    final videoQueue = List<VideoModel>.from(videos);
    final sections = <_HomeSection>[];
    final random = math.Random();

    while (rails.isNotEmpty ||
        postQueue.isNotEmpty ||
        reelQueue.isNotEmpty ||
        videoQueue.isNotEmpty) {
      final availableTypes = <_HomeSectionType>[
        if (rails.isNotEmpty) _HomeSectionType.productRail,
        if (postQueue.isNotEmpty) _HomeSectionType.post,
        if (reelQueue.isNotEmpty) _HomeSectionType.reel,
        if (videoQueue.isNotEmpty) _HomeSectionType.video,
      ];

      if (availableTypes.length > 1 && sections.isNotEmpty) {
        final trailingCount = _trailingTypeCount(sections, sections.last.type);
        if (trailingCount >= 2) {
          availableTypes.remove(sections.last.type);
        }
      }

      final selectedType = availableTypes[random.nextInt(availableTypes.length)];

      switch (selectedType) {
        case _HomeSectionType.productRail:
          sections.add(_HomeSection(type: selectedType, data: rails.removeAt(0)));
          break;
        case _HomeSectionType.post:
          sections.add(_HomeSection(type: selectedType, data: postQueue.removeAt(0)));
          break;
        case _HomeSectionType.reel:
          sections.add(_HomeSection(type: selectedType, data: reelQueue.removeAt(0)));
          break;
        case _HomeSectionType.video:
          sections.add(_HomeSection(type: selectedType, data: videoQueue.removeAt(0)));
          break;
      }
    }

    return sections;
  }

  int _trailingTypeCount(List<_HomeSection> sections, _HomeSectionType type) {
    var count = 0;
    for (var i = sections.length - 1; i >= 0; i--) {
      if (sections[i].type != type) {
        break;
      }
      count++;
    }
    return count;
  }

  DateTime _parseDate(String value) {
    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  String _formatFeedTime(String value) {
    final createdAt = _parseDate(value);
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      final seconds = math.max(1, difference.inSeconds);
      return '$seconds ${seconds == 1 ? 'second' : 'seconds'} ago';
    }
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    if (difference.inDays < 30) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    }
    if (difference.inDays < 365) {
      final months = difference.inDays ~/ 30;
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }

    const monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${monthNames[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }

  Future<void> _handleAddToCart(String productId) async {
    try {
      await context.read<CartProvider>().addToCart(productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to cart!'),
          backgroundColor: AppColors.successGreen,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add to cart'),
          backgroundColor: AppColors.destructive,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchFeed,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_sections.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchFeed,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Icon(Icons.dynamic_feed_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Center(child: Text('No recommended content yet')),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final pagePadding = isCompact ? 12.0 : 20.0;

        return RefreshIndicator(
          onRefresh: _fetchFeed,
          child: ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: pagePadding),
            itemCount: _sections.length,
            itemBuilder: (context, index) {
              final section = _sections[index];
              switch (section.type) {
                case _HomeSectionType.productRail:
                  return _buildProductRail(
                    section.data as List<ProductModel>,
                    constraints.maxWidth,
                  );
                case _HomeSectionType.post:
                  return _buildPostCard(
                    section.data as PostModel,
                    constraints.maxWidth,
                  );
                case _HomeSectionType.reel:
                  return _buildReelCard(
                    section.data as ReelModel,
                    constraints.maxWidth,
                  );
                case _HomeSectionType.video:
                  return _buildVideoCard(
                    section.data as VideoModel,
                    constraints.maxWidth,
                  );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionShell({
    required Widget child,
    required double maxWidth,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.min(maxWidth, _pageMaxWidth),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildProductRail(List<ProductModel> products, double viewportWidth) {
    return _buildSectionShell(
      maxWidth: viewportWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Products',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          SizedBox(
            height: _productRailHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _buildProductTile(products[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTile(ProductModel product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: _productRailCardWidth,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/shop/${product.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      child: product.images.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: UrlHelper.getPlatformUrl(product.images.first),
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(Icons.shopping_bag),
                            )
                          : const Icon(Icons.shopping_bag),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        elevation: 2,
                        child: InkWell(
                          onTap: () => _handleAddToCart(product.id),
                          borderRadius: BorderRadius.circular(999),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              size: 18,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.brandName ?? product.sellerName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              height: 1.0,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(PostModel post, double viewportWidth) {
    return _buildMediaCard(
      maxWidth: post.mediaType == 'reel' ? _reelCardMaxWidth : _mediaCardMaxWidth,
      viewportWidth: viewportWidth,
      onTap: null,
      media: _buildPostMedia(post),
      creatorName: post.authorName,
      creatorAvatar: post.authorAvatar,
      createdAt: post.createdAt,
      bodyText: post.caption,
    );
  }

  Widget _buildVideoCard(VideoModel video, double viewportWidth) {
    return _buildMediaCard(
      maxWidth: _mediaCardMaxWidth,
      viewportWidth: viewportWidth,
      onTap: () => context.go('/videos/${video.id}'),
      media: _buildFramedMedia(
        imageUrl: video.thumbnail,
        aspectRatio: 16 / 9,
        playIcon: true,
      ),
      creatorName: video.creatorName,
      creatorAvatar: video.creatorAvatar,
      createdAt: video.createdAt,
      bodyText: video.title,
    );
  }

  Widget _buildReelCard(ReelModel reel, double viewportWidth) {
    return _buildMediaCard(
      maxWidth: _reelCardMaxWidth,
      viewportWidth: viewportWidth,
      onTap: () => context.go('/reels?id=${reel.id}'),
      media: _buildFramedMedia(
        imageUrl: reel.thumbnail,
        aspectRatio: 9 / 14,
        playIcon: true,
      ),
      creatorName: reel.creatorName,
      creatorAvatar: reel.creatorAvatar,
      createdAt: reel.createdAt,
      bodyText: reel.caption,
    );
  }

  Widget _buildPostMedia(PostModel post) {
    final aspectRatio = switch (post.mediaType) {
      'reel' => 9 / 14,
      'video' => 16 / 9,
      _ => 4 / 5,
    };

    return _buildFramedMedia(
      imageUrl: post.thumbnailUrl ?? post.mediaUrl,
      aspectRatio: aspectRatio,
      playIcon: post.mediaType == 'video' || post.mediaType == 'reel',
    );
  }

  Widget _buildFramedMedia({
    required String imageUrl,
    required double aspectRatio,
    bool playIcon = false,
  }) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: UrlHelper.getPlatformUrl(imageUrl),
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image_outlined, size: 40),
            ),
          ),
          if (playIcon)
            Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(140),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaCard({
    required double maxWidth,
    required double viewportWidth,
    required Widget media,
    required String creatorName,
    required String createdAt,
    String? creatorAvatar,
    String? bodyText,
    VoidCallback? onTap,
  }) {
    return _buildSectionShell(
      maxWidth: viewportWidth,
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.min(maxWidth, viewportWidth),
          ),
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    child: Row(
                      children: [
                        _buildAvatar(creatorName, creatorAvatar),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                creatorName,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatFeedTime(createdAt),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  media,
                  if (bodyText != null && bodyText.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Text(
                        bodyText.trim(),
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, String? avatarUrl) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.electricBlue,
      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
          ? CachedNetworkImageProvider(UrlHelper.getPlatformUrl(avatarUrl))
          : null,
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}

enum _HomeSectionType {
  productRail,
  post,
  reel,
  video,
}

class _HomeSection {
  const _HomeSection({
    required this.type,
    required this.data,
  });

  final _HomeSectionType type;
  final Object data;
}
