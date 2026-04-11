class AppConstants {
  static const String appName = '短视频创作助手';

  // Google Play product IDs
  static const String productPro = 'creator_pro_monthly';
  static const String productProPlus = 'creator_pro_plus_monthly';

  // Daily limits (mirrors backend DAILY_LIMITS)
  static const Map<String, int> dailyLimits = {
    'free': 3,
    'pro': 30,
    'pro_plus': 90,
    'admin': 999999,
  };

  static const Map<String, String> tierNames = {
    'free': '免费版',
    'pro': 'Pro版',
    'pro_plus': 'Pro+版',
    'admin': '管理员',
  };

  // Secure storage keys
  static const String jwtKey = 'jwt_token';
  static const String deviceIdKey = 'device_id';
}
