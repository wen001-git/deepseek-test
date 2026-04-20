class ApiConstants {
  static const String _defaultBaseUrl = 'https://video-creation-0fjy.onrender.com';
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );
  static String get baseUrl => _configuredBaseUrl.endsWith('/')
      ? _configuredBaseUrl.substring(0, _configuredBaseUrl.length - 1)
      : _configuredBaseUrl;
  // Local dev (Android emulator): use --dart-define=API_BASE_URL=http://10.0.2.2:5000

  // Mobile auth endpoints
  static const String login = '/api/mobile/login';
  static const String me = '/api/mobile/me';
  static const String logout = '/api/mobile/logout';
  static const String verifySubscription = '/api/mobile/verify-subscription';

  // AI feature endpoints
  static const String script = '/api/script';
  static const String shotTable = '/api/shot-table';
  static const String positioning = '/api/positioning';
  static const String viralTopics = '/api/topics/viral';
  static const String monetizeTopics = '/api/topics/monetize';
  static const String rewrite = '/api/rewrite';
  static const String breakdown = '/api/breakdown';
  static const String imitate = '/api/imitate';
  static const String searchViral = '/api/search-viral';
  static const String breakdownSharetext = '/api/breakdown-sharetext';
  static const String fetchUrl = '/api/fetch-url';
  static const String director = '/api/director';
  static const String contentPlan = '/api/content-plan';
  static const String hotTrends = '/api/hot-trends';
}
