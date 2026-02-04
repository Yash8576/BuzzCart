// Core application configuration
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // Get the appropriate base URL based on platform
  static String get _baseHost {
    if (kIsWeb) {
      // Web: Use localhost
      return 'localhost';
    } else if (Platform.isAndroid) {
      // Android emulator: 10.0.2.2 maps to host machine's localhost
      return '10.0.2.2';
    } else {
      // iOS simulator, macOS, Windows, Linux: Use localhost
      return 'localhost';
    }
  }

  static const String _port = '8000';

  // API Configuration - Cross-platform compatible URLs
  static String get apiBaseUrl => 'http://$_baseHost:$_port/api';

  static String get chatbotBaseUrl => 'http://$_baseHost:$_port/api/v1';

  static String get wsBaseUrl => 'ws://$_baseHost:$_port/ws';

  // Storage Configuration
  static String get storageBaseUrl => 'http://$_baseHost:$_port/storage';

  // App Configuration
  static const String appName = 'Buzz Social Cart';
  static const String appVersion = '1.0.0';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 5);

  // Cache
  static const Duration cacheExpiry = Duration(hours: 1);
  static const int maxCacheSize = 100 * 1024 * 1024; // 100 MB

  // Media
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxVideoSizeBytes = 100 * 1024 * 1024; // 100 MB
  static const Duration maxReelDuration = Duration(seconds: 60);
  static const Duration maxVideoDuration = Duration(minutes: 10);

  // Authentication
  static const String jwtTokenKey = 'jwt_token';
  static const String refreshTokenKey = 'refresh_token';
  static const Duration sessionTimeout = Duration(hours: 24);

  // Features
  static const bool enableAnalytics = true;
  static const bool enableChatbot = true;
  static const bool enablePushNotifications = true;

  // Environment
  static bool get isProduction =>
      const bool.fromEnvironment('PRODUCTION', defaultValue: false);
  static bool get isDevelopment => !isProduction;
}
