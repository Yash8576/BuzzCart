import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/utils/url_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _gridSpacing = 16;
  static const double _minTileWidth = 180;
  static const double _maxTileWidth = 280;

  int _calculateGridColumns(double availableWidth) {
    if (availableWidth <= 0) return 1;

    var columns = ((availableWidth + _gridSpacing) / (_minTileWidth + _gridSpacing)).floor();
    if (columns < 1) columns = 1;

    while (columns > 1) {
      final tileWidth = (availableWidth - (columns - 1) * _gridSpacing) / columns;
      if (tileWidth <= _maxTileWidth) {
        break;
      }
      columns++;
    }

    return columns;
  }

  List<FeedItem> _feed = [];
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
        api.getVideos().catchError((_) => <VideoModel>[]),
        api.getReels().catchError((_) => <ReelModel>[]),
      ]);

      final products = (results[0] as List<ProductModel>)
          .where((product) => product.sellerId != currentUserId)
          .toList();
      final videos = (results[1] as List<VideoModel>)
          .where((video) => video.creatorId != currentUserId)
          .toList();
      final reels = (results[2] as List<ReelModel>)
          .where((reel) => reel.creatorId != currentUserId)
          .toList();

      final feed = <FeedItem>[
        ...products.map((product) => FeedItem(type: 'product', data: product)),
        ...videos.map((video) => FeedItem(type: 'video', data: video)),
        ...reels.map((reel) => FeedItem(type: 'reel', data: reel)),
      ]..sort((a, b) {
          final aDate = DateTime.tryParse(_createdAtFor(a)) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = DateTime.tryParse(_createdAtFor(b)) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });

      setState(() {
        _feed = feed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load feed';
        _isLoading = false;
      });
    }
  }

  String _createdAtFor(FeedItem item) {
    switch (item.type) {
      case 'product':
        return (item.data as ProductModel).createdAt;
      case 'video':
        return (item.data as VideoModel).createdAt;
      case 'reel':
        return (item.data as ReelModel).createdAt;
      default:
        return '';
    }
  }

  Future<void> _handleAddToCart(String productId) async {
    try {
      await context.read<CartProvider>().addToCart(productId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to cart!'),
            backgroundColor: AppColors.successGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add to cart'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
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

    if (_feed.isEmpty) {
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

    return RefreshIndicator(
      onRefresh: _fetchFeed,
      child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = _calculateGridColumns(constraints.maxWidth - 32);
        return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: _gridSpacing,
          mainAxisSpacing: _gridSpacing,
          childAspectRatio: 0.75,
        ),
        itemCount: _feed.length,
        itemBuilder: (context, index) {
          final item = _feed[index];
          switch (item.type) {
          case 'product':
            return _buildProductCard(item.data as ProductModel, index);
          case 'video':
            return _buildVideoCard(item.data as VideoModel, index);
          case 'reel':
            return _buildReelCard(item.data as ReelModel, index);
          default:
            return const SizedBox();
          }
        },
        );
      },
      ),
    );
  }

  Widget _buildProductCard(ProductModel product, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/shop/${product.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: isDark
                        ? AppColors.darkMuted
                        : AppColors.lightMuted,
                    child: product.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: UrlHelper.getPlatformUrl(product.images[0]),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: isDark
                                  ? AppColors.darkMuted
                                  : AppColors.lightMuted,
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          )
                        : const Icon(Icons.shopping_bag),
                  ),
                  // Add to cart button
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      elevation: 2,
                      child: InkWell(
                        onTap: () => _handleAddToCart(product.id),
                        borderRadius: BorderRadius.circular(100),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.shopping_bag,
                            size: 20,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Product info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if ((product.brandName ?? '').isNotEmpty ||
                      product.sellerName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.brandName ?? product.sellerName,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.visibility, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${product.views} views',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(VideoModel video, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/videos/${video.id}'),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              child: CachedNetworkImage(
                imageUrl: UrlHelper.getPlatformUrl(video.thumbnail),
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.error),
              ),
            ),
            // Play button overlay
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(230),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  size: 40,
                  color: Colors.black,
                ),
              ),
            ),
            // Bottom gradient and info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withAlpha(204),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.electricBlue,
                          child: Text(
                            video.creatorName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                video.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                video.creatorName,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(204),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReelCard(ReelModel reel, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/reels?id=${reel.id}'),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              child: CachedNetworkImage(
                imageUrl: UrlHelper.getPlatformUrl(reel.thumbnail),
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.error),
              ),
            ),
            // Reel badge
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(128),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, color: Colors.white, size: 14),
                    SizedBox(width: 2),
                    Text(
                      'Reel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withAlpha(179),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.electricBlue,
                          child: Text(
                            reel.creatorName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          reel.creatorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (reel.caption.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        reel.caption,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
