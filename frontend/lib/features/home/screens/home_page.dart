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
import '../../products/widgets/product_card_social_preview.dart';

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
  static const double _productRailHeight = 308;
  static const double _listCacheExtent = 2200;

  List<_HomeSection> _sections = [];
  bool _isLoading = true;
  String? _error;
  final Map<int, ScrollController> _productRailControllers = {};
  final Set<int> _canScrollRailLeft = {};
  final Set<int> _canScrollRailRight = {};

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }

  @override
  void dispose() {
    for (final controller in _productRailControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ScrollController _getProductRailController(int sectionIndex) {
    return _productRailControllers.putIfAbsent(sectionIndex, () {
      final controller = ScrollController();
      controller.addListener(() => _updateRailScrollState(sectionIndex));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateRailScrollState(sectionIndex);
      });
      return controller;
    });
  }

  void _updateRailScrollState(int sectionIndex) {
    final controller = _productRailControllers[sectionIndex];
    if (controller == null || !controller.hasClients || !mounted) {
      return;
    }

    final canLeft = controller.offset > 2;
    final canRight =
        controller.offset < controller.position.maxScrollExtent - 2;
    final wasLeft = _canScrollRailLeft.contains(sectionIndex);
    final wasRight = _canScrollRailRight.contains(sectionIndex);

    if (canLeft == wasLeft && canRight == wasRight) {
      return;
    }

    setState(() {
      if (canLeft) {
        _canScrollRailLeft.add(sectionIndex);
      } else {
        _canScrollRailLeft.remove(sectionIndex);
      }

      if (canRight) {
        _canScrollRailRight.add(sectionIndex);
      } else {
        _canScrollRailRight.remove(sectionIndex);
      }
    });
  }

  Future<void> _scrollProductRail(int sectionIndex, bool forward) async {
    final controller = _productRailControllers[sectionIndex];
    if (controller == null || !controller.hasClients) {
      return;
    }

    const delta = _productRailCardWidth * 1.75;
    final target =
        forward ? controller.offset + delta : controller.offset - delta;
    final clampedTarget = target.clamp(
      controller.position.minScrollExtent,
      controller.position.maxScrollExtent,
    );

    await controller.animateTo(
      clampedTarget.toDouble(),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _pruneProductRailControllers(List<_HomeSection> sections) {
    final activeRailIndexes = <int>{};
    for (var index = 0; index < sections.length; index++) {
      if (sections[index].type == _HomeSectionType.productRail) {
        activeRailIndexes.add(index);
      }
    }

    final staleIndexes = _productRailControllers.keys
        .where((index) => !activeRailIndexes.contains(index))
        .toList();

    for (final index in staleIndexes) {
      _productRailControllers.remove(index)?.dispose();
      _canScrollRailLeft.remove(index);
      _canScrollRailRight.remove(index);
    }
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
        api
            .getDiscoveryFeed(limit: 30)
            .catchError((_) => FeedResponse(posts: [])),
        api.getVideos().catchError((_) => <VideoModel>[]),
        api.getReels().catchError((_) => <ReelModel>[]),
      ]);

      final products = (results[0] as List<ProductModel>)
          .where((product) => product.sellerId != currentUserId)
          .toList()
        ..sort(
          (a, b) => _parseDate(b.createdAt).compareTo(_parseDate(a.createdAt)),
        );

      final posts = (results[1] as FeedResponse)
          .posts
          .where((post) => post.userId != currentUserId)
          .toList()
        ..sort(
          (a, b) => _parseDate(b.createdAt).compareTo(_parseDate(a.createdAt)),
        );

      final publishedMediaUrls = posts
          .where(
              (post) => post.mediaType == 'video' || post.mediaType == 'reel')
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
      _pruneProductRailControllers(sections);

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

  List<List<ProductModel>> _chunkProducts(
      List<ProductModel> products, int chunkSize) {
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

      final selectedType =
          availableTypes[random.nextInt(availableTypes.length)];

      switch (selectedType) {
        case _HomeSectionType.productRail:
          sections
              .add(_HomeSection(type: selectedType, data: rails.removeAt(0)));
          break;
        case _HomeSectionType.post:
          sections.add(
              _HomeSection(type: selectedType, data: postQueue.removeAt(0)));
          break;
        case _HomeSectionType.reel:
          sections.add(
              _HomeSection(type: selectedType, data: reelQueue.removeAt(0)));
          break;
        case _HomeSectionType.video:
          sections.add(
              _HomeSection(type: selectedType, data: videoQueue.removeAt(0)));
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

  int _cartQuantityForProduct(String productId, List<CartItemModel> cartItems) {
    for (final item in cartItems) {
      if (item.product.id == productId) {
        return item.quantity;
      }
    }
    return 0;
  }

  int _remainingStockForProduct(
    ProductModel product,
    List<CartItemModel> cartItems,
  ) {
    if (product.stockQuantity <= 0) {
      return 0;
    }

    final inCart = _cartQuantityForProduct(product.id, cartItems);
    final remaining = product.stockQuantity - inCart;
    return remaining > 0 ? remaining : 0;
  }

  void _showCartToast(
    String message, {
    required Color backgroundColor,
  }) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleAddToCart(ProductModel product) async {
    final cartItems = context.read<CartProvider>().cart.items;
    final remainingStock = _remainingStockForProduct(product, cartItems);
    if (remainingStock <= 0) {
      _showCartToast(
        'Max stock already in cart',
        backgroundColor: AppColors.destructive,
      );
      return;
    }

    final added = await context
        .read<CartProvider>()
        .addToCart(product.id, maxQuantity: remainingStock);
    if (!mounted) return;
    if (added) {
      final cart = context.read<CartProvider>().cart;
      _showCartToast(
        'Added to cart. Total: \$${cart.total.toStringAsFixed(2)}',
        backgroundColor: AppColors.successGreen,
      );
      return;
    }

    _showCartToast(
      'Failed to add to cart',
      backgroundColor: AppColors.destructive,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = context.watch<CartProvider>().cart.items;

    if (_isLoading) {
      return _buildLoadingFeed();
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
            padding:
                EdgeInsets.symmetric(vertical: 16, horizontal: pagePadding),
            cacheExtent: _listCacheExtent,
            itemCount: _sections.length,
            itemBuilder: (context, index) {
              final section = _sections[index];
              switch (section.type) {
                case _HomeSectionType.productRail:
                  return _buildProductRail(
                    index,
                    section.data as List<ProductModel>,
                    constraints.maxWidth,
                    cartItems,
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

  Widget _buildLoadingFeed() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: LinearProgressIndicator(minHeight: 3),
        ),
        _buildLoadingCard(aspectRatio: 1),
        _buildLoadingCard(aspectRatio: 4 / 5),
        _buildLoadingCard(aspectRatio: 16 / 9),
      ],
    );
  }

  Widget _buildLoadingCard({required double aspectRatio}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderColor =
        isDark ? AppColors.darkMuted : AppColors.lightMuted;

    Widget block({
      required double height,
      double? width,
      EdgeInsetsGeometry margin = EdgeInsets.zero,
    }) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: placeholderColor,
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    return _buildSectionShell(
      maxWidth: _pageMaxWidth,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: placeholderColor,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      block(height: 12, width: 120),
                      block(
                        height: 10,
                        width: 84,
                        margin: const EdgeInsets.only(top: 6),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: aspectRatio,
              child: Container(color: placeholderColor),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  block(height: 12, width: double.infinity),
                  block(
                    height: 12,
                    width: 200,
                    margin: const EdgeInsets.only(top: 8),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionShell({
    required Widget child,
    required double maxWidth,
  }) {
    final constrainedWidth = math.min(maxWidth, _pageMaxWidth);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: constrainedWidth,
          child: child,
        ),
      ),
    );
  }

  Widget _buildProductRail(
    int sectionIndex,
    List<ProductModel> products,
    double viewportWidth,
    List<CartItemModel> cartItems,
  ) {
    final railWidth = math.min(
      _mediaCardMaxWidth,
      math.min(viewportWidth, _pageMaxWidth),
    );
    final controller = _getProductRailController(sectionIndex);
    final canScrollLeft = _canScrollRailLeft.contains(sectionIndex);
    final canScrollRight = _canScrollRailRight.contains(sectionIndex);

    return _buildSectionShell(
      maxWidth: viewportWidth,
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: railWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 2, bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Products',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                    _buildRailArrowButton(
                      icon: Icons.chevron_left_rounded,
                      isEnabled: canScrollLeft,
                      onPressed: () => _scrollProductRail(sectionIndex, false),
                    ),
                    const SizedBox(width: 6),
                    _buildRailArrowButton(
                      icon: Icons.chevron_right_rounded,
                      isEnabled: canScrollRight,
                      onPressed: () => _scrollProductRail(sectionIndex, true),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: _productRailHeight,
                child: ListView.separated(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  cacheExtent: _listCacheExtent,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return _buildProductTile(products[index], cartItems);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRailArrowButton({
    required IconData icon,
    required bool isEnabled,
    required VoidCallback onPressed,
  }) {
    final surfaceColor = Theme.of(context).cardColor;

    return Material(
      color: isEnabled ? surfaceColor : surfaceColor.withAlpha(140),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 22,
            color: isEnabled ? null : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildProductTile(
      ProductModel product, List<CartItemModel> cartItems) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remainingStock = _remainingStockForProduct(product, cartItems);
    final canAddToCart = remainingStock > 0;

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
                      color:
                          isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      child: product.images.isNotEmpty
                          ? _buildCachedImage(
                              product.images.first,
                              fit: BoxFit.cover,
                              errorWidget: const Icon(Icons.shopping_bag),
                            )
                          : const Icon(Icons.shopping_bag),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Material(
                        color:
                            canAddToCart ? Colors.white : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                        elevation: 2,
                        child: InkWell(
                          onTap: canAddToCart
                              ? () => _handleAddToCart(product)
                              : null,
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 20,
                              color: canAddToCart ? Colors.black : Colors.grey,
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
                      const SizedBox(height: 6),
                      Text(
                        product.brandName ?? product.sellerName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              height: 1.0,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      _buildProductPrice(product),
                      const SizedBox(height: 6),
                      ProductCardSocialPreview(
                        productId: product.id,
                        maxAvatars: 2,
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

  Widget _buildProductPrice(ProductModel product) {
    final compareAtPrice = product.compareAtPrice;
    final hasDiscount =
        compareAtPrice != null && compareAtPrice > product.price;

    final currentPriceText = '\$${product.price.toStringAsFixed(2)}';
    final currentPriceStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.electricBlue,
          height: 1.0,
        );

    if (!hasDiscount) {
      return Row(
        children: [
          Expanded(
            child: Text(
              currentPriceText,
              style: currentPriceStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final percentOff =
        (((compareAtPrice - product.price) / compareAtPrice) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                currentPriceText,
                style: currentPriceStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withAlpha(24),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$percentOff% OFF',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '\$${compareAtPrice.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                decoration: TextDecoration.lineThrough,
              ),
        ),
      ],
    );
  }

  Widget _buildPostCard(PostModel post, double viewportWidth) {
    return _buildMediaCard(
      maxWidth:
          post.mediaType == 'reel' ? _reelCardMaxWidth : _mediaCardMaxWidth,
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
          _buildCachedImage(
            imageUrl,
            fit: BoxFit.cover,
            errorWidget: Container(
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
        alignment: Alignment.center,
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatFeedTime(createdAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
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

  Widget _buildCachedImage(
    String imageUrl, {
    BoxFit fit = BoxFit.cover,
    Widget? errorWidget,
  }) {
    final resolvedUrl = UrlHelper.getPlatformUrl(imageUrl);

    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      cacheKey: resolvedUrl,
      fit: fit,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      errorWidget: (_, __, ___) => errorWidget ?? const SizedBox.shrink(),
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
