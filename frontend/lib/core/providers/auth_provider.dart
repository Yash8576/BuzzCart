import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  static const String _lastActivityKey = 'last_activity';
  static const String _pendingAvatarPreviewPathKey =
      'pending_avatar_preview_path';
  static const int _maxInactiveDays = 7;
  
  UserModel? _user;
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _pendingAvatarPreviewPath;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get isSeller => _user?.isSeller ?? false;
  String? get pendingAvatarPreviewPath => _pendingAvatarPreviewPath;

  AuthProvider({required ApiService apiService}) : _api = apiService {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Ensure token is loaded from storage first
      await _api.ensureTokenLoaded();
      _pendingAvatarPreviewPath =
          await _storage.read(key: _pendingAvatarPreviewPathKey);
      
      // Check if token exists
      final hasToken = await _api.hasToken();
      if (!hasToken) {
        debugPrint('No token found - user needs to login');
        _isAuthenticated = false;
        _user = null;
        _pendingAvatarPreviewPath = null;
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      // Check if user has been inactive for more than 7 days
      final lastActivity = await _storage.read(key: _lastActivityKey);
      if (lastActivity != null) {
        final lastDate = DateTime.parse(lastActivity);
        final daysSinceActivity = DateTime.now().difference(lastDate).inDays;
        
        if (daysSinceActivity > _maxInactiveDays) {
          // Auto-logout due to inactivity
          debugPrint('Auto-logout due to inactivity ($daysSinceActivity days)');
          await _api.logout();
          await _storage.delete(key: _lastActivityKey);
          await _storage.delete(key: _pendingAvatarPreviewPathKey);
          _isAuthenticated = false;
          _user = null;
          _pendingAvatarPreviewPath = null;
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      // Try to get user profile with existing token
      debugPrint('Attempting to fetch user profile with stored token');
      _user = await _api.getMe().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Request timeout'),
      );
      if ((_user?.avatar ?? '').trim().isNotEmpty) {
        _pendingAvatarPreviewPath = null;
        await _storage.delete(key: _pendingAvatarPreviewPathKey);
      }
      _isAuthenticated = true;
      await _updateLastActivity();
      debugPrint('User authenticated successfully: ${_user?.email}');
    } catch (e) {
      debugPrint('Auth init error: $e');
      // Clear invalid token
      await _api.logout();
      _isAuthenticated = false;
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _updateLastActivity() async {
    await _storage.write(
      key: _lastActivityKey,
      value: DateTime.now().toIso8601String(),
    );
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _api.login(email, password);
      _user = UserModel.fromJson(response['user'] as Map<String, dynamic>);
      _isAuthenticated = true;
      await _updateLastActivity();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> register(
    String email,
    String password,
    String name, {
    String accountType = 'CONSUMER',
    String privacyProfile = 'PUBLIC',
    String? phoneNumber,
  }) async {
    try {
      final response = await _api.register(
        email,
        password,
        name,
        accountType: accountType,
        privacyProfile: privacyProfile,
        phoneNumber: phoneNumber,
      );
      _user = UserModel.fromJson(response['user'] as Map<String, dynamic>);
      _isAuthenticated = true;
      await _updateLastActivity();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    await _storage.delete(key: _lastActivityKey);
    await _storage.delete(key: _pendingAvatarPreviewPathKey);
    _user = null;
    _isAuthenticated = false;
    _pendingAvatarPreviewPath = null;
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      _user = await _api.updateProfile(data);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refreshUser({bool preserveAvatarIfMissing = false}) async {
    try {
      final previousUser = _user;
      final fetchedUser = await _api.getMe();

      final shouldPreserveAvatar = preserveAvatarIfMissing &&
          previousUser != null &&
          (previousUser.avatar ?? '').trim().isNotEmpty &&
          (fetchedUser.avatar ?? '').trim().isEmpty;

      _user = shouldPreserveAvatar
          ? fetchedUser.copyWith(avatar: previousUser.avatar)
          : fetchedUser;
      if ((_user?.avatar ?? '').trim().isNotEmpty) {
        _pendingAvatarPreviewPath = null;
        await _storage.delete(key: _pendingAvatarPreviewPathKey);
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void updateAvatarUrl(String? avatarUrl) {
    if (_user == null) return;
    _user = _user!.copyWith(
      avatar: avatarUrl,
      clearAvatar: avatarUrl == null || avatarUrl.trim().isEmpty,
    );
    if (avatarUrl == null || avatarUrl.trim().isEmpty) {
      _pendingAvatarPreviewPath = null;
      _storage.delete(key: _pendingAvatarPreviewPathKey);
    }
    notifyListeners();
  }

  Future<void> setPendingAvatarPreviewPath(String? path) async {
    _pendingAvatarPreviewPath = path;
    if (path == null || path.trim().isEmpty) {
      await _storage.delete(key: _pendingAvatarPreviewPathKey);
    } else {
      await _storage.write(key: _pendingAvatarPreviewPathKey, value: path);
    }
    notifyListeners();
  }
}
