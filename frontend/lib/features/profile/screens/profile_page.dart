import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/models.dart';
import '../../../core/utils/url_helper.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;
  
  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  List<MediaItem> _photos = [];
  List<MediaItem> _videos = [];
  List<MediaItem> _reels = [];
  List<ProductModel> _products = [];
  bool _loading = true;
  Map<String, dynamic>? _profileUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Changed from 3 to 4
    _fetchUserContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserContent() async {
    debugPrint('Fetching user content...');
    setState(() => _loading = true);
    
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) {
      debugPrint('No user found');
      setState(() => _loading = false);
      return;
    }
    
    // Determine which user profile to fetch
    final targetUserId = widget.userId ?? currentUser.id;
    final isOwnProfile = targetUserId == currentUser.id;
    
    debugPrint('Fetching content for user: $targetUserId (own profile: $isOwnProfile)');
    
    // If viewing another user's profile, fetch their user info
    if (!isOwnProfile && widget.userId != null) {
      try {
        final userModel = await _api.getUser(widget.userId!);
        _profileUser = {
          'id': userModel.id,
          'name': userModel.name,
          'avatar': userModel.avatar,
          'bio': userModel.bio,
          'privacy_profile': userModel.privacyProfile.toLowerCase(),
          'followers_count': userModel.followersCount,
          'following_count': userModel.followingCount,
        };
        debugPrint('Fetched profile user: ${_profileUser?['name']}');
      } catch (e) {
        debugPrint('Error fetching user profile: $e');
        setState(() => _loading = false);
        return;
      }
    }
    
    // Fetch each type independently to prevent one failure from blocking others
    final photos = await _api.getUserMedia(targetUserId, type: 'photo').catchError((e) {
      debugPrint('Error fetching photos: $e');
      return <MediaItem>[];
    });
    
    final videos = await _api.getUserMedia(targetUserId, type: 'video').catchError((e) {
      debugPrint('Error fetching videos: $e');
      return <MediaItem>[];
    });
    
    final reels = await _api.getUserMedia(targetUserId, type: 'reel').catchError((e) {
      debugPrint('Error fetching reels: $e');
      return <MediaItem>[];
    });
    
    final products = await _api.getSellerProducts(targetUserId).catchError((e) {
      debugPrint('Error fetching products: $e');
      return <ProductModel>[];
    });
    
    debugPrint('Fetch complete - Photos: ${photos.length}, Videos: ${videos.length}, Reels: ${reels.length}, Products: ${products.length}');
    
    setState(() {
      _photos = photos;
      _videos = videos;
      _reels = reels;
      _products = products;
      _loading = false;
    });
    
    debugPrint('State updated - Photos count: ${_photos.length}');
  }

  Future<void> _showEditProfileDialog() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final nameController = TextEditingController(text: user.name);
    final bioController = TextEditingController(text: user.bio ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bioController,
              decoration: const InputDecoration(labelText: 'Bio'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Update profile logic would go here
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile updated!')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(
          child: Text('Please log in to view your profile'),
        ),
      );
    }

    // Use profile user if viewing someone else's profile, otherwise use logged-in user
    final displayUser = _profileUser;
    final isOwnProfile = widget.userId == null || widget.userId == currentUser.id;
    
    // If loading and no profile user data yet
    if (_loading && displayUser == null && !isOwnProfile) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.electricBlue.withAlpha(77),
                      AppColors.neonPurple.withAlpha(77),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              if (isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => context.go('/settings'),
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -50),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    child: CircleAvatar(
                      radius: 46,
                      backgroundImage: (isOwnProfile ? currentUser.avatar : displayUser?['avatar']) != null
                          ? NetworkImage(UrlHelper.getPlatformUrl(isOwnProfile ? currentUser.avatar : displayUser?['avatar']))
                          : null,
                      child: (isOwnProfile ? currentUser.avatar : displayUser?['avatar']) == null
                          ? Text(
                              (isOwnProfile ? currentUser.name : displayUser?['name'] ?? '').toString().isNotEmpty 
                                  ? (isOwnProfile ? currentUser.name : displayUser?['name']).toString()[0].toUpperCase() 
                                  : 'U',
                              style: const TextStyle(fontSize: 32),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isOwnProfile ? currentUser.name : (displayUser?['name'] ?? ''),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if ((isOwnProfile ? currentUser.bio : displayUser?['bio']) != null && 
                      (isOwnProfile ? currentUser.bio : displayUser?['bio']).toString().isNotEmpty)
                    const SizedBox(height: 8),
                  if ((isOwnProfile ? currentUser.bio : displayUser?['bio']) != null && 
                      (isOwnProfile ? currentUser.bio : displayUser?['bio']).toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        (isOwnProfile ? currentUser.bio : displayUser?['bio']).toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatItem(label: 'Posts', count: _videos.length + _reels.length),
                        _StatItem(
                          label: 'Followers', 
                          count: isOwnProfile 
                              ? currentUser.followersCount 
                              : (displayUser?['followers_count'] ?? 0)
                        ),
                        _StatItem(
                          label: 'Following', 
                          count: isOwnProfile 
                              ? currentUser.followingCount 
                              : (displayUser?['following_count'] ?? 0)
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        if (isOwnProfile) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _showEditProfileDialog,
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit Profile'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.share),
                              label: const Text('Share'),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Implement follow functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Follow functionality coming soon!')),
                                );
                              },
                              icon: const Icon(Icons.person_add),
                              label: const Text('Follow'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.message),
                              label: const Text('Message'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.photo_library), text: 'Photos'),
                  Tab(icon: Icon(Icons.video_library), text: 'Videos'),
                  Tab(icon: Icon(Icons.movie), text: 'Reels'),
                  Tab(icon: Icon(Icons.shopping_bag), text: 'Products'),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPhotosGrid(),
                _buildVideosGrid(),
                _buildReelsGrid(),
                _buildProductsGrid(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosGrid() {
    debugPrint('Building photos grid - Loading: $_loading, Photos: ${_photos.length}');
    
    final currentUser = context.read<AuthProvider>().user;
    final isOwnProfile = widget.userId == null || widget.userId == currentUser?.id;
    final isPrivate = _profileUser?['privacy_profile'] == 'private';
    
    if (_loading) return const Center(child: CircularProgressIndicator());
    
    // Show private account message if not own profile and account is private and no content
    if (!isOwnProfile && isPrivate && _photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'This Account is Private',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow this account to see their photos',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    if (_photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No photos yet'),
            if (isOwnProfile) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchUserContent,
                child: const Text('Refresh'),
              ),
            ],
          ],
        ),
      );
    }
    debugPrint('Rendering ${_photos.length} photos');
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        debugPrint('Building photo $index: ${photo.mediaUrl}');
        return InkWell(
          onTap: () {
            // Show full screen photo
            showDialog(
              context: context,
              builder: (context) => Dialog(
                backgroundColor: Colors.transparent,
                child: Stack(
                  children: [
                    Center(
                      child: Image.network(
                        UrlHelper.getPlatformUrl(photo.mediaUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Error loading fullscreen image: $error');
                          return const Center(
                            child: Icon(Icons.broken_image, size: 64, color: Colors.white),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 40,
                      right: 20,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: Image.network(
            UrlHelper.getPlatformUrl(photo.mediaUrl),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading thumbnail image: $error');
              return Container(
                color: Colors.grey[300],
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.grey, size: 32),
                    SizedBox(height: 4),
                    Text('Error', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                debugPrint('Thumbnail loaded: ${photo.mediaUrl}');
                return child;
              }
              return Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildVideosGrid() {
    final currentUser = context.read<AuthProvider>().user;
    final isOwnProfile = widget.userId == null || widget.userId == currentUser?.id;
    final isPrivate = _profileUser?['privacy_profile'] == 'private';
    
    if (_loading) return const Center(child: CircularProgressIndicator());
    
    // Show private account message if not own profile and account is private and no content
    if (!isOwnProfile && isPrivate && _videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'This Account is Private',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow this account to see their videos',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    if (_videos.isEmpty) {
      return const Center(child: Text('No videos yet'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 16 / 12,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        return InkWell(
          onTap: () => context.go('/videos/${video.id}'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                UrlHelper.getPlatformUrl(video.thumbnailUrl ?? video.mediaUrl),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.video_library, size: 48),
                  );
                },
              ),
              const Center(
                child: Icon(Icons.play_circle_fill,
                    color: Colors.white, size: 48),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReelsGrid() {
    final currentUser = context.read<AuthProvider>().user;
    final isOwnProfile = widget.userId == null || widget.userId == currentUser?.id;
    final isPrivate = _profileUser?['privacy_profile'] == 'private';
    
    if (_loading) return const Center(child: CircularProgressIndicator());
    
    // Show private account message if not own profile and account is private and no content
    if (!isOwnProfile && isPrivate && _reels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'This Account is Private',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow this account to see their reels',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    if (_reels.isEmpty) {
      return const Center(child: Text('No reels yet'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 9 / 16,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _reels.length,
      itemBuilder: (context, index) {
        final reel = _reels[index];
        return InkWell(
          onTap: () => context.go('/reels'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                UrlHelper.getPlatformUrl(reel.thumbnailUrl ?? reel.mediaUrl),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.video_camera_back, size: 36),
                  );
                },
              ),
              const Center(
                child: Icon(Icons.play_circle_fill,
                    color: Colors.white, size: 36),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductsGrid() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_products.isEmpty) {
      return const Center(child: Text('No products yet'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return InkWell(
          onTap: () => context.go('/shop/${product.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Image.network(
                  UrlHelper.getPlatformUrl(product.images.isNotEmpty ? product.images[0] : ''),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.shopping_bag, size: 48),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int count;

  const _StatItem({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
