import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _picker = ImagePicker();
  late TabController _tabController;
  List<MediaItem> _photos = [];
  List<MediaItem> _videos = [];
  List<MediaItem> _reels = [];
  List<ProductModel> _products = [];
  bool _loading = true;
  bool _isAvatarUpdating = false;
  bool _isRelationshipUpdating = false;
  int _avatarVersion = 0;
  String? _localAvatarPreviewPath;
  Uint8List? _localAvatarPreviewBytes;
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
        final profileJson = userModel.toJson();
        profileJson['privacy_profile'] = userModel.privacyProfile.toLowerCase();
        profileJson['visibility_mode'] = userModel.visibilityMode.toLowerCase();
        profileJson['visibility_preferences'] = userModel.visibilityPreferences;
        _profileUser = profileJson;
        debugPrint('Fetched profile user: ${_profileUser?['name']}');
      } catch (e) {
        debugPrint('Error fetching user profile: $e');
        setState(() => _loading = false);
        return;
      }
    } else {
      final profileJson = currentUser.toJson();
      profileJson['privacy_profile'] = currentUser.privacyProfile.toLowerCase();
      profileJson['visibility_mode'] = currentUser.visibilityMode.toLowerCase();
      profileJson['visibility_preferences'] = currentUser.visibilityPreferences;
      _profileUser = profileJson;
    }

    final canViewPhotos = isOwnProfile || _isBucketVisible('photos', isOwnProfile: false);
    final canViewVideos = isOwnProfile || _isBucketVisible('videos', isOwnProfile: false);
    final canViewReels = isOwnProfile || _isBucketVisible('reels', isOwnProfile: false);
    final canViewPurchases = isOwnProfile || _isBucketVisible('purchases', isOwnProfile: false);
    
    // Fetch each type independently to prevent one failure from blocking others
    final photos = canViewPhotos
        ? await _api.getUserMedia(targetUserId, type: 'photo').catchError((e) {
            debugPrint('Error fetching photos: $e');
            return <MediaItem>[];
          })
        : <MediaItem>[];
    
    final videos = canViewVideos
        ? await _api.getUserMedia(targetUserId, type: 'video').catchError((e) {
            debugPrint('Error fetching videos: $e');
            return <MediaItem>[];
          })
        : <MediaItem>[];
    
    final reels = canViewReels
        ? await _api.getUserMedia(targetUserId, type: 'reel').catchError((e) {
            debugPrint('Error fetching reels: $e');
            return <MediaItem>[];
          })
        : <MediaItem>[];
    
    final products = canViewPurchases
        ? await _api.getSellerProducts(targetUserId).catchError((e) {
            debugPrint('Error fetching products: $e');
            return <ProductModel>[];
          })
        : <ProductModel>[];
    
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

  Future<void> _handleFollowAction() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = context.read<AuthProvider>().user;
    final targetUserId = widget.userId;
    if (currentUser == null || targetUserId == null || _isRelationshipUpdating) {
      return;
    }

    final isFollowing = _profileUser?['is_following'] == true;
    if (isFollowing) {
      final shouldUnfollow = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unfollow user?'),
          content: const Text('Do you want to unfollow this user?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Unfollow'),
            ),
          ],
        ),
      );
      if (shouldUnfollow != true) {
        return;
      }
    }

    setState(() => _isRelationshipUpdating = true);
    try {
      if (isFollowing) {
        await _api.unfollowUser(targetUserId);
      } else {
        await _api.followUser(targetUserId);
      }
      await authProvider.refreshUser();
      await _fetchUserContent();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFollowing ? 'Failed to unfollow user' : 'Failed to follow user',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRelationshipUpdating = false);
      }
    }
  }

  Future<void> _showSocialUsers({
    required String title,
    required bool followers,
  }) async {
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) {
      return;
    }

    final targetUserId = widget.userId ?? currentUser.id;

    try {
      final users = followers
          ? await _api.getFollowers(targetUserId)
          : await _api.getFollowing(targetUserId);

      if (!mounted) {
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: users.isEmpty
                        ? const Center(
                            child: Text('No users in this list yet'),
                          )
                        : ListView.separated(
                            itemCount: users.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final user = users[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage:
                                      (user.avatar ?? '').isNotEmpty
                                          ? NetworkImage(
                                              UrlHelper.getPlatformUrl(
                                                user.avatar,
                                              ),
                                            )
                                          : null,
                                  child: (user.avatar ?? '').isEmpty
                                      ? Text(
                                          user.name.isEmpty
                                              ? '?'
                                              : user.name[0].toUpperCase(),
                                        )
                                      : null,
                                ),
                                title: Text(user.name),
                                subtitle: user.bio.isNotEmpty
                                    ? Text(
                                        user.bio,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                trailing: user.isConnection
                                    ? const Icon(
                                        Icons.people_alt_outlined,
                                        size: 18,
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  context.push('/profile/${user.id}');
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      final message = e.response?.statusCode == 403
          ? 'This list is private'
          : 'Failed to load $title';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load $title')),
      );
    }
  }

  void _openMessages() {
    final displayUser = _profileUser;
    if (displayUser == null) {
      return;
    }
    context.push(
      '/messages',
      extra: MessagesRouteIntent(
        participant: MessageParticipantModel(
          id: displayUser['id'] as String,
          name: (displayUser['name'] ?? 'Unknown').toString(),
          avatar: displayUser['avatar'] as String?,
        ),
      ),
    );
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

  Future<void> _showAvatarEditOptions() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.user;
    final isOwnProfile = widget.userId == null || widget.userId == currentUser?.id;
    if (!isOwnProfile || currentUser == null || _isAvatarUpdating) {
      return;
    }

    final hasAvatar = (_localAvatarPreviewPath != null &&
            _previewPathExists(_localAvatarPreviewPath)) ||
        _hasLocalPreviewBytes() ||
        (authProvider.pendingAvatarPreviewPath != null &&
            _previewPathExists(authProvider.pendingAvatarPreviewPath)) ||
        (currentUser.avatar ?? '').trim().isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                  child: Icon(
                    Icons.edit,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Edit Profile Photo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from library'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadAvatar();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Browse files (cloud apps)'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromCloudAndUploadAvatar();
                  },
                ),
                ListTile(
                  enabled: hasAvatar,
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete current photo'),
                  onTap: hasAvatar
                      ? () {
                          Navigator.pop(context);
                          _deleteCurrentAvatar();
                        }
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final pickedImage = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedImage == null || !mounted) {
        return;
      }
      await _cropAndUploadAvatar(pickedImage);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to update profile photo: $e')),
        );
      }
    }
  }

  Future<void> _pickFromCloudAndUploadAvatar() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
        withData: true,
      );

      if (result == null || result.files.isEmpty || !mounted) {
        return;
      }

      final selected = result.files.first;
      XFile sourceFile;

      if (selected.path != null && selected.path!.isNotEmpty) {
        sourceFile = XFile(selected.path!);
      } else if (selected.bytes != null) {
        if (kIsWeb) {
          sourceFile = XFile.fromData(
            selected.bytes!,
            name: selected.name,
            mimeType: 'image/${_safeImageExtension(selected.name)}',
          );
        } else {
          final tempDir = Directory.systemTemp;
          final extension = _safeImageExtension(selected.name);
          final tempPath =
              '${tempDir.path}${Platform.pathSeparator}cloud_avatar_${DateTime.now().microsecondsSinceEpoch}.$extension';
          final tempFile = File(tempPath);
          await tempFile.writeAsBytes(selected.bytes!, flush: true);
          sourceFile = XFile(tempFile.path);
        }
      } else {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Unable to open selected cloud photo')),
          );
        }
        return;
      }

      if (!mounted) return;
      await _cropAndUploadAvatar(sourceFile);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Cloud picker failed: $e')),
        );
      }
    }
  }

  Future<void> _cropAndUploadAvatar(XFile sourceImage) async {
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final primaryColor = Theme.of(context).primaryColor;

    try {
      final localImagePath = await _ensureLocalImagePath(sourceImage);
      if (!mounted) {
        return;
      }

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: localImagePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Avatar',
            toolbarColor: primaryColor,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            hideBottomControls: true,
            showCropGrid: false,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: 'Crop Avatar',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            cropStyle: CropStyle.circle,
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 600, height: 600),
          ),
        ],
      );

      if (croppedFile == null || !mounted) {
        return;
      }

      setState(() {
        _isAvatarUpdating = true;
        _localAvatarPreviewPath = croppedFile.path;
        _localAvatarPreviewBytes = null;
      });
      final uploadBytes = await croppedFile.readAsBytes();
      if (kIsWeb) {
        setState(() {
          _localAvatarPreviewBytes = uploadBytes;
          _localAvatarPreviewPath = null;
        });
        await authProvider.setPendingAvatarPreviewPath(null);
      } else {
        await authProvider.setPendingAvatarPreviewPath(croppedFile.path);
      }
      final uploadResult = await _api.uploadImage(
        XFile.fromData(
          uploadBytes,
          name: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
          mimeType: 'image/jpeg',
        ),
        folder: 'avatars',
      );
      debugPrint('[ProfileAvatar] uploadImage response: $uploadResult');

      final avatarUrl = uploadResult['url']?.toString();
      if (avatarUrl == null || avatarUrl.trim().isEmpty) {
        throw Exception('Image upload succeeded but no URL was returned');
      }

      await authProvider.updateProfile({'avatar': avatarUrl});
      await authProvider.setPendingAvatarPreviewPath(null);
      setState(() {
        _avatarVersion = DateTime.now().millisecondsSinceEpoch;
        _localAvatarPreviewBytes = null;
      });

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Profile photo updated successfully')),
        );
      }
    } catch (e) {
      debugPrint('[ProfileAvatar] Upload failed: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to update profile photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAvatarUpdating = false);
      }
    }
  }

  Future<void> _deleteCurrentAvatar() async {
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      setState(() => _isAvatarUpdating = true);
      await _api.deleteAvatar();
      authProvider.updateAvatarUrl(null);
      setState(() {
        _avatarVersion = DateTime.now().millisecondsSinceEpoch;
        _localAvatarPreviewPath = null;
        _localAvatarPreviewBytes = null;
      });

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Profile photo removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to delete profile photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAvatarUpdating = false);
      }
    }
  }

  Future<String> _ensureLocalImagePath(XFile file) async {
    final originalPath = file.path;
    if (originalPath.isNotEmpty && (kIsWeb || File(originalPath).existsSync())) {
      return originalPath;
    }

    if (kIsWeb) {
      throw Exception('Web image source is missing a usable path');
    }

    final bytes = await file.readAsBytes();
    final tempDir = Directory.systemTemp;
    final extension = _safeImageExtension(file.name);
    final tempPath = '${tempDir.path}${Platform.pathSeparator}avatar_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);
    return tempFile.path;
  }

  String _safeImageExtension(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.gif')) return 'gif';
    return 'jpg';
  }

  Map<String, bool> _profileVisibilityPreferences() {
    final rawPreferences = _profileUser?['visibility_preferences'];
    final preferences = <String, bool>{
      'photos': true,
      'videos': true,
      'reels': true,
      'purchases': true,
    };

    if (rawPreferences is Map) {
      for (final entry in rawPreferences.entries) {
        preferences[entry.key.toString().toLowerCase()] = entry.value == true;
      }
    }

    return preferences;
  }

  String _profileVisibilityMode() {
    return (_profileUser?['visibility_mode']?.toString() ?? 'public').toLowerCase();
  }

  bool _isBucketVisible(String bucket, {required bool isOwnProfile}) {
    if (isOwnProfile) return true;

    final visibilityMode = _profileVisibilityMode();
    if (visibilityMode == 'private') return false;
    if (visibilityMode != 'custom') return true;

    final preferences = _profileVisibilityPreferences();
    return preferences[bucket.toLowerCase()] ?? true;
  }

  Widget _buildHiddenSectionMessage(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.user;

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
    final isSellerProfile = isOwnProfile
        ? currentUser.isSeller
        : (displayUser?['account_type']?.toString().toLowerCase() == 'seller' ||
            displayUser?['role']?.toString().toLowerCase() == 'seller');
    final productsTabLabel = isSellerProfile ? 'Products' : 'Purchases';
    final avatarRaw = (isOwnProfile ? currentUser.avatar : displayUser?['avatar'])?.toString();
    final avatarUrl = avatarRaw != null && avatarRaw.trim().isNotEmpty ? avatarRaw : null;
    final avatarBaseUrl = avatarUrl == null ? null : UrlHelper.getPlatformUrl(avatarUrl);
    final avatarDisplayUrl = avatarBaseUrl == null
        ? null
        : '$avatarBaseUrl${avatarBaseUrl.contains('?') ? '&' : '?'}v=$_avatarVersion';
    final providerPreviewPath = authProvider.pendingAvatarPreviewPath;
    final hasLocalPreview =
        _localAvatarPreviewPath != null && _previewPathExists(_localAvatarPreviewPath);
    final hasProviderPreview =
        providerPreviewPath != null && _previewPathExists(providerPreviewPath);
    ImageProvider? avatarImageProvider;
    if (_hasLocalPreviewBytes()) {
      avatarImageProvider = MemoryImage(_localAvatarPreviewBytes!);
    } else if (hasLocalPreview) {
      avatarImageProvider = FileImage(File(_localAvatarPreviewPath!));
    } else if (hasProviderPreview) {
      avatarImageProvider = FileImage(File(providerPreviewPath));
    } else if (avatarDisplayUrl != null) {
      avatarImageProvider = NetworkImage(avatarDisplayUrl);
    }
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final postsCount = _photos.length + _videos.length + _reels.length;
    final isFollowing = displayUser?['is_following'] == true;
    final isConnection = displayUser?['is_connection'] == true;
    
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
          if (isDesktop)
            SliverAppBar(
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              title: Text(
                isOwnProfile ? 'Profile' : (displayUser?['name'] ?? 'Profile'),
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
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, isDesktop ? 12 : 2, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onLongPress: isOwnProfile ? _showAvatarEditOptions : null,
                        child: SizedBox(
                          width: 84,
                          height: 84,
                          child: Stack(
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: _buildAvatarImage(
                                    imageProvider: avatarImageProvider,
                                    fallbackText: (isOwnProfile
                                                ? currentUser.name
                                                : displayUser?['name'] ?? '')
                                            .toString()
                                            .isNotEmpty
                                        ? (isOwnProfile
                                                ? currentUser.name
                                                : displayUser?['name'])
                                            .toString()[0]
                                            .toUpperCase()
                                        : 'U',
                                  ),
                                ),
                              ),
                              if (isOwnProfile)
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Material(
                                    color: Colors.grey.shade200,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      onTap: _showAvatarEditOptions,
                                      customBorder: const CircleBorder(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(5),
                                        child: Icon(
                                          Icons.edit,
                                          size: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (_isAvatarUpdating)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 84,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(6, 8, 0, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isOwnProfile
                                      ? currentUser.name
                                      : (displayUser?['name'] ?? ''),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _StatItem(
                                        label: 'Posts',
                                        count: postsCount,
                                      ),
                                    ),
                                    Expanded(
                                      child: _StatItem(
                                        label: 'Followers',
                                        count: isOwnProfile
                                            ? currentUser.followersCount
                                            : (displayUser?['followers_count'] ?? 0),
                                        onTap: () => _showSocialUsers(
                                          title: 'Followers',
                                          followers: true,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _StatItem(
                                        label: 'Following',
                                        count: isOwnProfile
                                            ? currentUser.followingCount
                                            : (displayUser?['following_count'] ?? 0),
                                        onTap: () => _showSocialUsers(
                                          title: 'Following',
                                          followers: false,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if ((isOwnProfile ? currentUser.bio : displayUser?['bio']) !=
                          null &&
                      (isOwnProfile ? currentUser.bio : displayUser?['bio'])
                          .toString()
                          .isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      (isOwnProfile ? currentUser.bio : displayUser?['bio'])
                          .toString(),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (isOwnProfile) ...[
                        Expanded(
                          child: _buildProfileActionButton(
                            onPressed: _showEditProfileDialog,
                            label: 'Edit Profile',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildProfileActionButton(
                            onPressed: () {},
                            label: 'Share',
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _isRelationshipUpdating ? null : _handleFollowAction,
                            icon: _isRelationshipUpdating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    isFollowing
                                        ? Icons.check_circle_outline
                                        : Icons.person_add,
                                  ),
                            label: Text(isFollowing ? 'Following' : 'Follow'),
                          ),
                        ),
                        if (isConnection) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openMessages,
                              icon: const Icon(Icons.message),
                              label: const Text('Message'),
                            ),
                          ),
                        ],
                      ],
                    ],
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
                tabs: [
                  const Tab(text: 'Photos'),
                  const Tab(text: 'Videos'),
                  const Tab(text: 'Reels'),
                  Tab(text: productsTabLabel),
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

  Widget _buildAvatarImage({
    required ImageProvider? imageProvider,
    required String fallbackText,
  }) {
    if (imageProvider == null) {
      return Container(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        alignment: Alignment.center,
        child: Text(
          fallbackText,
          style: const TextStyle(fontSize: 28),
        ),
      );
    }

    return Image(
      image: imageProvider,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
          alignment: Alignment.center,
          child: Text(
            fallbackText,
            style: const TextStyle(fontSize: 28),
          ),
        );
      },
    );
  }

  bool _previewPathExists(String? path) {
    if (path == null || path.isEmpty || kIsWeb) {
      return false;
    }
    return File(path).existsSync();
  }

  bool _hasLocalPreviewBytes() {
    return _localAvatarPreviewBytes != null && _localAvatarPreviewBytes!.isNotEmpty;
  }

  Widget _buildPhotosGrid() {
    debugPrint('Building photos grid - Loading: $_loading, Photos: ${_photos.length}');
    
    final currentUser = context.read<AuthProvider>().user;
    final isOwnProfile = widget.userId == null || widget.userId == currentUser?.id;
    final isPrivate = _profileUser?['privacy_profile'] == 'private';
    final bucketVisible = _isBucketVisible('photos', isOwnProfile: isOwnProfile);
    
    if (_loading) return const Center(child: CircularProgressIndicator());
    
    // Show private account message if not own profile and account is private and no content
    if (!isOwnProfile && isPrivate && _photos.isEmpty) {
      return _buildHiddenSectionMessage(
        'This Account is Private',
        'Follow this account to see their photos',
      );
    }

    if (!isOwnProfile && !bucketVisible) {
      return _buildHiddenSectionMessage(
        'Photos are Private',
        'This user chose to hide their photos',
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
    final bucketVisible = _isBucketVisible('videos', isOwnProfile: isOwnProfile);
    
    if (_loading) return const Center(child: CircularProgressIndicator());
    
    // Show private account message if not own profile and account is private and no content
    if (!isOwnProfile && isPrivate && _videos.isEmpty) {
      return _buildHiddenSectionMessage(
        'This Account is Private',
        'Follow this account to see their videos',
      );
    }

    if (!isOwnProfile && !bucketVisible) {
      return _buildHiddenSectionMessage(
        'Videos are Private',
        'This user chose to hide their videos',
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
    final bucketVisible = _isBucketVisible('reels', isOwnProfile: isOwnProfile);
    
    if (_loading) return const Center(child: CircularProgressIndicator());
    
    // Show private account message if not own profile and account is private and no content
    if (!isOwnProfile && isPrivate && _reels.isEmpty) {
      return _buildHiddenSectionMessage(
        'This Account is Private',
        'Follow this account to see their reels',
      );
    }

    if (!isOwnProfile && !bucketVisible) {
      return _buildHiddenSectionMessage(
        'Reels are Private',
        'This user chose to hide their reels',
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
    final currentUser = context.read<AuthProvider>().user;
    final isOwnProfile = widget.userId == null || widget.userId == currentUser?.id;
    final isPrivate = _profileUser?['privacy_profile'] == 'private';
    final bucketVisible = _isBucketVisible('purchases', isOwnProfile: isOwnProfile);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!isOwnProfile && isPrivate && _products.isEmpty) {
      return _buildHiddenSectionMessage(
        'This Account is Private',
        'Follow this account to see their purchases',
      );
    }
    if (!isOwnProfile && !bucketVisible) {
      return _buildHiddenSectionMessage(
        'Purchases are Private',
        'This user chose to hide their purchases',
      );
    }
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

  Widget _buildProfileActionButton({
    required VoidCallback onPressed,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 30,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback? onTap;

  const _StatItem({
    required this.label,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return child;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
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
