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
  static const int _maxInactiveDays = 7;
  
  UserModel? _user;
  bool _isLoading = true;
  bool _isAuthenticated = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider({required ApiService apiService}) : _api = apiService {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Ensure token is loaded from storage first
      await _api.ensureTokenLoaded();
      
      // Check if token exists
      final hasToken = await _api.hasToken();
      if (!hasToken) {
        debugPrint('No token found - user needs to login');
        _isAuthenticated = false;
        _user = null;
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
          _isAuthenticated = false;
          _user = null;
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

  Future<void> register(String email, String password, String name) async {
    try {
      final response = await _api.register(email, password, name);
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
    _user = null;
    _isAuthenticated = false;
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
}
