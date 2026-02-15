import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/url_helper.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  Map<String, List<dynamic>> _results = {
    'products': [],
    'videos': [],
    'reels': [],
    'users': [],
  };
  bool _loading = false;
  bool _searched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounce?.cancel();

    // If query is empty, clear results immediately
    if (query.trim().isEmpty) {
      _clearSearch();
      return;
    }

    // Set debounce timer for 500ms
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
    
    setState(() {}); // Update UI for clear button
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _searched = true;
    });

    try {
      final data = await _api.search(query);
      setState(() {
        _results = {
          'products': data['products'] ?? [],
          'videos': data['videos'] ?? [],
          'reels': data['reels'] ?? [],
          'users': data['users'] ?? [],
        };
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search failed')),
        );
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _results = {
        'products': [],
        'videos': [],
        'reels': [],
        'users': [],
      };
      _searched = false;
    });
  }

  int get _totalResults =>
      _results.values.fold(0, (sum, list) => sum + list.length);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products, videos, creators...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _performSearch(),
              onChanged: _onSearchChanged,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_searched
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Search for products, videos, and more',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : _totalResults == 0
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No results found',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          tabs: [
                            Tab(text: 'All ($_totalResults)'),
                            Tab(text: 'Products (${_results['products']!.length})'),
                            Tab(text: 'Videos (${_results['videos']!.length})'),
                            Tab(text: 'Reels (${_results['reels']!.length})'),
                            Tab(text: 'Users (${_results['users']!.length})'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildAllTab(),
                              _buildProductsTab(),
                              _buildVideosTab(),
                              _buildReelsTab(),
                              _buildUsersTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildAllTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_results['products']!.isNotEmpty)
          const Text(
            'Products',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        if (_results['products']!.isNotEmpty)
          const SizedBox(height: 12),
        if (_results['products']!.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _results['products']!.length.clamp(0, 4),
            itemBuilder: (context, index) {
              final product = _results['products']![index];
              return _ProductCard(product: product);
            },
          ),
        if (_results['products']!.isNotEmpty)
          const SizedBox(height: 24),
        if (_results['users']!.isNotEmpty)
          const Text(
            'Users',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        if (_results['users']!.isNotEmpty)
          const SizedBox(height: 12),
        if (_results['users']!.isNotEmpty)
          ...(_results['users']!.take(3).map((user) => _UserCard(user: user))),
        if (_results['users']!.isNotEmpty)
          const SizedBox(height: 24),
        if (_results['videos']!.isNotEmpty)
          const Text(
            'Videos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        if (_results['videos']!.isNotEmpty)
          const SizedBox(height: 12),
        if (_results['videos']!.isNotEmpty)
          ...(_results['videos']!.take(3).map((video) => _VideoCard(video: video))),
      ],
    );
  }

  Widget _buildProductsTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _results['products']!.length,
      itemBuilder: (context, index) {
        final product = _results['products']![index];
        return _ProductCard(product: product);
      },
    );
  }

  Widget _buildVideosTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results['videos']!.length,
      itemBuilder: (context, index) {
        final video = _results['videos']![index];
        return _VideoCard(video: video);
      },
    );
  }

  Widget _buildReelsTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 9 / 16,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _results['reels']!.length,
      itemBuilder: (context, index) {
        final reel = _results['reels']![index];
        return InkWell(
          onTap: () => context.go('/reels'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  UrlHelper.getPlatformUrl(reel['thumbnail']),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.videocam),
                  ),
                ),
              ),
              const Center(
                child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results['users']!.length,
      itemBuilder: (context, index) {
        final user = _results['users']![index];
        return _UserCard(user: user);
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.go('/profile/${user['id']}'),
        leading: CircleAvatar(
          backgroundImage:
              user['avatar'] != null && user['avatar'].toString().isNotEmpty
                  ? NetworkImage(UrlHelper.getPlatformUrl(user['avatar']))
                  : null,
          child: user['avatar'] == null || user['avatar'].toString().isEmpty
              ? Text((user['name'] ?? 'U')[0].toUpperCase())
              : null,
        ),
        title: Text(user['name'] ?? ''),
        subtitle: Text(
          user['bio'] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/shop/${product['id']}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Image.network(
                UrlHelper.getPlatformUrl(product['images']?[0]),
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
                    product['title'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${(product['price'] ?? 0).toStringAsFixed(2)}',
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
  }
}

class _VideoCard extends StatelessWidget {
  final Map<String, dynamic> video;

  const _VideoCard({required this.video});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/videos/${video['id']}'),
        child: Row(
          children: [
            Container(
              width: 120,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      UrlHelper.getPlatformUrl(video['thumbnail']),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.play_arrow),
                      ),
                    ),
                  ),
                  const Center(
                    child: Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 32),
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
                      video['title'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${video['views'] ?? 0} views',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
}
