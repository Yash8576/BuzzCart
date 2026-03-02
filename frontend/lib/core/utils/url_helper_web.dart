// Web-specific URL helper

class UrlHelperPlatform {
  /// On web, keep localhost as-is
  static String convertUrl(String url) {
    return url;
  }
}
