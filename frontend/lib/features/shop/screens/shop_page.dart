import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/utils/url_helper.dart';

class ShopPage extends StatefulWidget {
  final String? productId;

  const ShopPage({super.key, this.productId});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  static const double _gridSpacing = 12;
  static const double _minTileWidth = 170;
  static const double _maxTileWidth = 260;
  static const double _detailImageMaxSize = 420;
  static const double _detailImageMinSize = 240;
  static const int _infiniteCarouselSeed = 1000;

  final PageController _mediaPageController = PageController(
    initialPage: _infiniteCarouselSeed,
  );

  int _calculateGridColumns(double availableWidth) {
    if (availableWidth <= 0) return 1;

    var columns =
        ((availableWidth + _gridSpacing) / (_minTileWidth + _gridSpacing))
            .floor();
    if (columns < 1) columns = 1;

    while (columns > 1) {
      final tileWidth =
          (availableWidth - (columns - 1) * _gridSpacing) / columns;
      if (tileWidth <= _maxTileWidth) {
        break;
      }
      columns++;
    }

    return columns;
  }

  late final ApiService _api;
  List<ProductModel> _allProducts = [];
  List<ProductModel> _products = [];
  ProductModel? _productDetail;
  bool _loading = true;
  String _category = '';
  int _currentImageIndex = 0;
  int _quantity = 1;

  @override
  void dispose() {
    _mediaPageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    if (widget.productId != null) {
      _fetchProductDetail();
    } else {
      _fetchProducts();
    }
  }

  Future<void> _fetchProducts() async {
    try {
      setState(() => _loading = true);
      final currentUserId = context.read<AuthProvider>().user?.id;
      final data = await _api.getProducts();
      setState(() {
        _allProducts = data
            .where((product) => product.sellerId != currentUserId)
            .toList();
        _applyCategoryFilter();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchProductDetail() async {
    try {
      setState(() => _loading = true);
      final currentUserId = context.read<AuthProvider>().user?.id;
      final data = await _api.getProduct(widget.productId!);
      if (data.sellerId == currentUserId) {
        if (!mounted) {
          return;
        }
        setState(() {
          _productDetail = null;
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your own products are managed from your profile warehouse'),
            ),
          );
          context.go('/profile');
        });
        return;
      }
      setState(() {
        _productDetail = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleAddToCart() async {
    try {
      await context.read<CartProvider>().addToCart(widget.productId!, quantity: _quantity);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $_quantity item(s) to cart!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add to cart')),
        );
      }
    }
  }

  void _applyCategoryFilter() {
    if (_category.isEmpty) {
      _products = List<ProductModel>.from(_allProducts);
      return;
    }
    _products = _allProducts
        .where((product) => product.category.toLowerCase() == _category.toLowerCase())
        .toList();
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    final resolvedUrl = UrlHelper.getPlatformUrl(rawUrl);
    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<String> get _availableCategories {
    final categories = _allProducts
        .map((product) => product.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return categories;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.productId != null) {
      return _buildProductDetail();
    }
    return _buildProductGrid();
  }

  Widget _buildProductDetail() {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_productDetail == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/shop'),
          ),
        ),
        body: const Center(child: Text('Product not found')),
      );
    }

    final product = _productDetail!;
    final mediaQueue = _buildMediaQueue(product);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/shop'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.favorite_outline), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              context.push(
                '/messages',
                extra: MessagesRouteIntent(
                  draft: MessageComposerDraft.product(product),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                if (mediaQueue.isNotEmpty)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      final squareSize = availableWidth.clamp(
                        _detailImageMinSize,
                        _detailImageMaxSize,
                      );
                      final activeMediaIndex = _currentImageIndex % mediaQueue.length;

                      return Center(
                        child: SizedBox(
                          width: squareSize,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: PageView.builder(
                                    controller: _mediaPageController,
                                    onPageChanged: (index) => setState(() => _currentImageIndex = index),
                                    itemBuilder: (context, index) {
                                      final media = mediaQueue[index % mediaQueue.length];
                                      final mediaType = (media['type'] as String?) ?? 'image';
                                      final mediaUrl = (media['url'] as String?) ?? '';
                                      if (mediaType == 'video') {
                                        return Container(
                                          color: Colors.black,
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Container(
                                                decoration: const BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [Colors.black87, Colors.black54],
                                                  ),
                                                ),
                                              ),
                                              Center(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.play_circle_fill,
                                                      size: 76,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      media['name'] as String? ?? 'Product video',
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (mediaUrl.isNotEmpty) ...[
                                                      const SizedBox(height: 8),
                                                      const Text(
                                                        'Swipe or use arrows to continue',
                                                        style: TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      return Image.network(
                                        UrlHelper.getPlatformUrl(mediaUrl),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.image, size: 64),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (mediaQueue.length > 1)
                                  Positioned(
                                    bottom: 16,
                                    left: 0,
                                    right: 0,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(
                                        mediaQueue.length,
                                        (index) => Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: activeMediaIndex == index
                                                ? Colors.white
                                                : Colors.white54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (mediaQueue.length > 1)
                                  Positioned(
                                    left: 8,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: _CarouselArrowButton(
                                        icon: Icons.chevron_left,
                                        onPressed: () => _mediaPageController.previousPage(
                                          duration: const Duration(milliseconds: 250),
                                          curve: Curves.easeOut,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (mediaQueue.length > 1)
                                  Positioned(
                                    right: 8,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: _CarouselArrowButton(
                                        icon: Icons.chevron_right,
                                        onPressed: () => _mediaPageController.nextPage(
                                          duration: const Duration(milliseconds: 250),
                                          curve: Curves.easeOut,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.electricBlue,
                        ),
                      ),
                      if ((product.brandName ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          product.brandName!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (product.category.isNotEmpty)
                            Chip(label: Text(product.category)),
                          if (product.condition.isNotEmpty)
                            Chip(label: Text(product.condition.toUpperCase())),
                          Chip(label: Text('Stock: ${product.stockQuantity}')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        product.description,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                      if (product.bulletPoints.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Key features',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...product.bulletPoints.map(
                          (point) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• '),
                                Expanded(child: Text(point)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (product.highlightedSpecifications.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Specifications',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...product.highlightedSpecifications.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 140,
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Expanded(child: Text(entry.value)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (product.specificationPdfUrl != null ||
                          product.mediaVideos.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Supporting Media',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (product.specificationPdfUrl != null)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                            title: const Text('Open specification PDF'),
                            onTap: () => _openExternalUrl(product.specificationPdfUrl!),
                          ),
                        ...product.mediaVideos.map(
                          (videoUrl) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.play_circle_outline),
                            title: const Text('Open product video'),
                            onTap: () => _openExternalUrl(videoUrl),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text('Quantity:', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                          ),
                          Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setState(() => _quantity++),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(26),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _handleAddToCart,
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Add to Cart'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildMediaQueue(ProductModel product) {
    if (product.mediaQueue.isNotEmpty) {
      return product.mediaQueue;
    }

    final fallbackQueue = <Map<String, dynamic>>[
      ...product.images.map(
        (url) => <String, dynamic>{
          'type': 'image',
          'url': url,
          'name': 'Product photo',
        },
      ),
      ...product.mediaVideos.map(
        (url) => <String, dynamic>{
          'type': 'video',
          'url': url,
          'name': 'Product video',
        },
      ),
    ];

    return fallbackQueue;
  }

  Widget _buildProductGrid() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Filter by Category',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('All Categories')),
                ..._availableCategories.map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _category = value ?? '';
                  _applyCategoryFilter();
                });
              },
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = _calculateGridColumns(constraints.maxWidth - 24);
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: _gridSpacing,
                    mainAxisSpacing: _gridSpacing,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.go('/shop/${product.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Image.network(
                                UrlHelper.getPlatformUrl(
                                  product.images.isNotEmpty ? product.images.first : '',
                                ),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    product.brandName ?? product.sellerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${product.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.electricBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _CarouselArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CarouselArrowButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(120),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}
