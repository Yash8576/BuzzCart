import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_refresh_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/utils/url_helper.dart';

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final ApiService _api = ApiService();
  final PageController _pageController = PageController();
  List<dynamic> _reels = [];
  bool _loading = true;
  int _currentIndex = 0;
  AppRefreshProvider? _appRefreshProvider;
  int _lastContentVersion = 0;

  @override
  void initState() {
    super.initState();
    _fetchReels();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AppRefreshProvider>();
    if (!identical(_appRefreshProvider, provider)) {
      _appRefreshProvider?.removeListener(_handleContentRefresh);
      _appRefreshProvider = provider;
      _lastContentVersion = provider.contentVersion;
      provider.addListener(_handleContentRefresh);
    }
  }

  @override
  void dispose() {
    _appRefreshProvider?.removeListener(_handleContentRefresh);
    _pageController.dispose();
    super.dispose();
  }

  void _handleContentRefresh() {
    final provider = _appRefreshProvider;
    if (provider == null || provider.contentVersion == _lastContentVersion) {
      return;
    }

    _lastContentVersion = provider.contentVersion;

    if (!mounted) {
      return;
    }
    _fetchReels();
  }

  Future<void> _fetchReels() async {
    try {
      setState(() => _loading = true);
      final data = await _api.getReels();
      setState(() {
        _reels = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleAddToCart(String productId) async {
    final added = await context.read<CartProvider>().addToCart(productId);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added ? 'Added to cart!' : 'Failed to add to cart'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: _fetchReels,
        child: PageView.builder(
          controller: _pageController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: PageScrollPhysics(),
          ),
          scrollDirection: Axis.vertical,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemCount: _reels.length,
          itemBuilder: (context, index) {
            final reel = _reels[index];
            final isActive = index == _currentIndex;
            return _ReelCard(
              reel: reel,
              isActive: isActive,
              onAddToCart: _handleAddToCart,
            );
          },
        ),
      ),
    );
  }
}

class _ReelCard extends StatefulWidget {
  final Map<String, dynamic> reel;
  final bool isActive;
  final Function(String) onAddToCart;

  const _ReelCard({
    required this.reel,
    required this.isActive,
    required this.onAddToCart,
  });

  @override
  State<_ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<_ReelCard> {
  bool _muted = true;
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final products = widget.reel['products'] as List? ?? [];

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video placeholder
        Image.network(
          UrlHelper.getPlatformUrl(widget.reel['thumbnail']),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Icons.play_circle_outline,
                  size: 80, color: Colors.white),
            ),
          ),
        ),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withAlpha(179),
              ],
            ),
          ),
        ),

        // Right side actions
        Positioned(
          right: 12,
          bottom: 100,
          child: Column(
            children: [
              _ActionButton(
                icon: _liked ? Icons.favorite : Icons.favorite_outline,
                color: _liked ? Colors.red : Colors.white,
                count: (widget.reel['likes'] ?? 0) + (_liked ? 1 : 0),
                onTap: () => setState(() => _liked = !_liked),
              ),
              const SizedBox(height: 16),
              _ActionButton(
                icon: Icons.comment,
                color: Colors.white,
                count: widget.reel['comments'] ?? 0,
                onTap: () {},
              ),
              const SizedBox(height: 16),
              _ActionButton(
                icon: Icons.share,
                color: Colors.white,
                onTap: () {},
              ),
              const SizedBox(height: 16),
              _ActionButton(
                icon: _muted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                onTap: () => setState(() => _muted = !_muted),
              ),
            ],
          ),
        ),

        // Bottom info
        Positioned(
          left: 16,
          right: 80,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: widget.reel['creator_avatar'] != null
                        ? NetworkImage(UrlHelper.getPlatformUrl(
                            widget.reel['creator_avatar']))
                        : null,
                    child: widget.reel['creator_avatar'] == null
                        ? Text(widget.reel['creator_name']?[0] ?? 'U')
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.reel['creator_name'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.reel['caption'] ?? '',
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (products.isNotEmpty) ..._buildProductTags(products),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildProductTags(List<dynamic> products) {
    return [
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: products.map<Widget>((product) {
            return InkWell(
              onTap: () => context.push('/shop/${product['id']}'),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        UrlHelper.getPlatformUrl(product['images']?[0]),
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 32,
                          height: 32,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, size: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$${(product['price'] ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ];
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int? count;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        if (count != null && count! > 0) const SizedBox(height: 4),
        if (count != null && count! > 0)
          Text(
            count! > 999 ? '${(count! / 1000).toStringAsFixed(1)}K' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
