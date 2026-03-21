import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_colors.dart';
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
  final ApiService _api = ApiService();
  List<ProductModel> _products = [];
  ProductModel? _productDetail;
  bool _loading = true;
  String _category = '';
  int _currentImageIndex = 0;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _fetchProductDetail();
    } else {
      _fetchProducts();
    }
  }

  Future<void> _fetchProducts() async {
    try {
      setState(() => _loading = true);
      final data = await _api.getProducts();
      setState(() {
        _products = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchProductDetail() async {
    try {
      setState(() => _loading = true);
      final data = await _api.getProduct(widget.productId!);
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
    final images = product.images;

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
                if (images.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      children: [
                        PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (index) => setState(() => _currentImageIndex = index),
                          itemBuilder: (context, index) => Image.network(
                            UrlHelper.getPlatformUrl(images[index]),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image, size: 64),
                            ),
                          ),
                        ),
                        if (images.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                images.length,
                                (index) => Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentImageIndex == index
                                        ? Colors.white
                                        : Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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
                      const SizedBox(height: 16),
                      Text(
                        product.description,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
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
              items: const [
                DropdownMenuItem(value: '', child: Text('All Categories')),
                DropdownMenuItem(value: 'tech', child: Text('Tech')),
                DropdownMenuItem(value: 'fashion', child: Text('Fashion')),
                DropdownMenuItem(value: 'beauty', child: Text('Beauty')),
                DropdownMenuItem(value: 'home', child: Text('Home')),
                DropdownMenuItem(value: 'sports', child: Text('Sports')),
              ],
              onChanged: (value) => setState(() => _category = value ?? ''),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
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
            ),
    );
  }
}
