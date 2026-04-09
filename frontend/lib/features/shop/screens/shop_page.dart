import 'dart:math' as math;

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
import '../../products/widgets/product_reviews_sheet.dart';

class ShopPage extends StatefulWidget {
  final String? productId;
  final bool allowOwnProductPreview;

  const ShopPage({
    super.key,
    this.productId,
    this.allowOwnProductPreview = false,
  });

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
        _allProducts =
            data.where((product) => product.sellerId != currentUserId).toList();
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
      if (!widget.allowOwnProductPreview && data.sellerId == currentUserId) {
        if (!mounted) {
          return;
        }
        context.go('/profile');
        return;
      }
      setState(() {
        _productDetail = data;
        _quantity = data.stockQuantity > 0 ? 1 : 0;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  int _cartQuantityForProduct(List<CartItemModel> items, String productId) {
    for (final item in items) {
      if (item.product.id == productId) {
        return item.quantity;
      }
    }
    return 0;
  }

  int _remainingStockForProduct(ProductModel product, int inCartQuantity) {
    if (product.stockQuantity <= 0) {
      return 0;
    }
    final remaining = product.stockQuantity - inCartQuantity;
    return remaining > 0 ? remaining : 0;
  }

  Future<void> _handleAddToCart(
      ProductModel product, int remainingStock) async {
    final quantityToAdd = math.min(_quantity, remainingStock);
    if (quantityToAdd < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Max stock already in cart')),
        );
      }
      return;
    }

    final added = await context.read<CartProvider>().addToCart(
          widget.productId!,
          quantity: quantityToAdd,
          maxQuantity: remainingStock,
        );
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Added $quantityToAdd item(s) to cart!'
              : 'Failed to add to cart',
        ),
      ),
    );
  }

  bool _isLowStock(ProductModel product) =>
      product.stockQuantity > 0 && product.stockQuantity < 10;

  int _selectedQuantityFor(int remainingStock) {
    if (remainingStock <= 0) {
      return 0;
    }
    return math.min(_quantity, remainingStock);
  }

  Widget _buildQuantitySelector(ProductModel product, int remainingStock) {
    final selectedQuantity = _selectedQuantityFor(remainingStock);
    final canDecrease = selectedQuantity > 1;
    final canIncrease =
        selectedQuantity > 0 && selectedQuantity < remainingStock;
    final showMax = remainingStock == 0 || selectedQuantity >= remainingStock;

    Widget buildStepButton({
      required IconData icon,
      required VoidCallback? onTap,
    }) {
      final theme = Theme.of(context);
      final isEnabled = onTap != null;

      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isEnabled
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : theme.colorScheme.onSurface.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isEnabled
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            'Qty',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          buildStepButton(
            icon: Icons.remove,
            onTap: canDecrease
                ? () => setState(() => _quantity = selectedQuantity - 1)
                : null,
          ),
          Text(
            '$selectedQuantity',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (canIncrease)
            buildStepButton(
              icon: Icons.add,
              onTap: () => setState(() => _quantity = selectedQuantity + 1),
            )
          else
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  showMax ? (product.stockQuantity > 0 ? 'Max' : 'Out') : 'Out',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _applyCategoryFilter() {
    if (_category.isEmpty) {
      _products = List<ProductModel>.from(_allProducts);
      return;
    }
    _products = _allProducts
        .where((product) =>
            product.category.toLowerCase() == _category.toLowerCase())
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

  Future<void> _openReviewsSheet(ProductModel product) async {
    final didChange = await showProductReviewsSheet(
      context: context,
      product: product,
      onReviewChanged: widget.productId != null ? _fetchProductDetail : null,
    );
    if (didChange == true && mounted && widget.productId != null) {
      await _fetchProductDetail();
    }
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
    final isOwnPreviewMode = widget.allowOwnProductPreview;
    final cartItems = context.watch<CartProvider>().cart.items;
    final inCartQuantity = _cartQuantityForProduct(cartItems, product.id);
    final remainingStock = _remainingStockForProduct(product, inCartQuantity);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/shop'),
        ),
        actions: [
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
                      final activeMediaIndex =
                          _currentImageIndex % mediaQueue.length;

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
                                    onPageChanged: (index) => setState(
                                        () => _currentImageIndex = index),
                                    itemBuilder: (context, index) {
                                      final media =
                                          mediaQueue[index % mediaQueue.length];
                                      final mediaType =
                                          (media['type'] as String?) ?? 'image';
                                      final mediaUrl =
                                          (media['url'] as String?) ?? '';
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
                                                    colors: [
                                                      Colors.black87,
                                                      Colors.black54
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.play_circle_fill,
                                                      size: 76,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      media['name']
                                                              as String? ??
                                                          'Product video',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    if (mediaUrl
                                                        .isNotEmpty) ...[
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
                                          child:
                                              const Icon(Icons.image, size: 64),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        mediaQueue.length,
                                        (index) => Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 4),
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
                                        onPressed: () =>
                                            _mediaPageController.previousPage(
                                          duration:
                                              const Duration(milliseconds: 250),
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
                                        onPressed: () =>
                                            _mediaPageController.nextPage(
                                          duration:
                                              const Duration(milliseconds: 250),
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
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
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
                      const SizedBox(height: 10),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 14,
                        runSpacing: 10,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 18,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                product.reviewsCount > 0
                                    ? '${product.rating.toStringAsFixed(1)} (${product.reviewsCount})'
                                    : 'No reviews yet',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => _openReviewsSheet(product),
                            borderRadius: BorderRadius.circular(999),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${product.reviewsCount}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                          if (product.stockQuantity <= 0)
                            const Chip(label: Text('Out of stock'))
                          else if (_isLowStock(product))
                            const Chip(label: Text('Low stock')),
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
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
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
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
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
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
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
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (product.specificationPdfUrl != null)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.picture_as_pdf,
                                color: Colors.red),
                            title: const Text('Open specification PDF'),
                            onTap: () =>
                                _openExternalUrl(product.specificationPdfUrl!),
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
                      if (isOwnPreviewMode)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Preview mode: cart actions are disabled for your own listing.',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isOwnPreviewMode)
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
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildQuantitySelector(product, remainingStock),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 7,
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: remainingStock > 0
                              ? () => _handleAddToCart(product, remainingStock)
                              : null,
                          icon: const Icon(Icons.shopping_cart),
                          label: Text(
                            remainingStock > 0 ? 'Add to Cart' : 'Out of stock',
                          ),
                        ),
                      ),
                    ),
                  ],
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
                const DropdownMenuItem(
                    value: '', child: Text('All Categories')),
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
                final columns =
                    _calculateGridColumns(constraints.maxWidth - 24);
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: 0.72,
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
                                  product.images.isNotEmpty
                                      ? product.images.first
                                      : '',
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '\$${product.price.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.electricBlue,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 14,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${product.rating.toStringAsFixed(1)} (${product.reviewsCount})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                        ),
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
