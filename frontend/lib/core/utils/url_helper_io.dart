// Native platform (iOS, Android, Desktop) URL helper
import 'dart:io' show Platform;

class UrlHelperPlatform {
  /// For Android emulator, replace localhost with 10.0.2.2
  /// For other platforms, keep as-is
  static String convertUrl(String url) {
    if (Platform.isAndroid) {
      return url.replaceAll('localhost', '10.0.2.2');
    }
    return url;
  }
}
