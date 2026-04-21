import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_refresh_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/utils/url_helper.dart';

class VideosPage extends StatefulWidget {
  final String? videoId;

  const VideosPage({super.key, this.videoId});

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  final ApiService _api = ApiService();
  List<dynamic> _videos = [];
  dynamic _videoDetail;
  bool _loading = true;
  AppRefreshProvider? _appRefreshProvider;
  int _lastContentVersion = 0;

  @override
  void initState() {
    super.initState();
    if (widget.videoId != null) {
      _fetchVideoDetail();
    } else {
      _fetchVideos();
    }
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
    super.dispose();
  }

  void _handleContentRefresh() {
    final provider = _appRefreshProvider;
    if (provider == null || provider.contentVersion == _lastContentVersion) {
      return;
    }

    _lastContentVersion = provider.contentVersion;

    if (!mounted || widget.videoId != null) {
      return;
    }
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    try {
      setState(() => _loading = true);
      final data = await _api.getVideos();
      setState(() {
        _videos = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchVideoDetail() async {
    try {
      setState(() => _loading = true);
      final data = await _api.getVideo(widget.videoId!);
      setState(() {
        _videoDetail = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        context.go('/videos');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoId != null) {
      return _buildVideoPlayer();
    }
    return _buildVideoList();
  }

  Widget _buildVideoPlayer() {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_videoDetail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Video not found')),
      );
    }

    final video = _videoDetail!;
    final products = video['products'] as List? ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.go('/videos'),
        ),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: Stack(
                children: [
                  Center(
                    child: Image.network(
                      UrlHelper.getPlatformUrl(video['thumbnail']),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.play_circle_outline,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: video['creator_avatar'] != null
                          ? NetworkImage(
                              UrlHelper.getPlatformUrl(video['creator_avatar']))
                          : null,
                      child: video['creator_avatar'] == null
                          ? Text(video['creator_name']?[0] ?? 'U')
                          : null,
                    ),
                    title: Text(
                      video['title'] ?? '',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(video['creator_name'] ?? ''),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.visibility, size: 14),
                            const SizedBox(width: 4),
                            Text('${video['views'] ?? 0} views'),
                            const SizedBox(width: 16),
                            const Icon(Icons.favorite, size: 14),
                            const SizedBox(width: 4),
                            Text('${video['likes'] ?? 0} likes'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (video['description'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(video['description'],
                          style: const TextStyle(height: 1.5)),
                    ),
                  if (products.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'Featured Products',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index];
                              return InkWell(
                                onTap: () =>
                                    context.go('/shop/${product['id']}'),
                                child: Container(
                                  width: 150,
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            UrlHelper.getPlatformUrl(
                                                product['images']?[0]),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.image),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        product['title'] ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        '\$${(product['price'] ?? 0).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            final added = await context
                                                .read<CartProvider>()
                                                .addToCart(
                                                  product['id'],
                                                  maxQuantity:
                                                      product['stock_quantity']
                                                          as int?,
                                                );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    added
                                                        ? 'Added to cart!'
                                                        : 'Failed to add',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.shopping_bag,
                                              size: 16),
                                          label: const Text('Add'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
    );
  }

  Widget _buildVideoList() {
    return Scaffold(
      appBar: AppBar(title: const Text('Videos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchVideos,
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 16 / 12,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _videos.length,
                itemBuilder: (context, index) {
                  final video = _videos[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.go('/videos/${video['id']}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  UrlHelper.getPlatformUrl(video['thumbnail']),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.black,
                                    child: const Icon(
                                      Icons.play_circle_outline,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const Center(
                                  child: Icon(
                                    Icons.play_circle_fill,
                                    size: 48,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  video['title'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.visibility, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${video['views'] ?? 0}',
                                      style: const TextStyle(fontSize: 12),
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
              ),
            ),
    );
  }
}
