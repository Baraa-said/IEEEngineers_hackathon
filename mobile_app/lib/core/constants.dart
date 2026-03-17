/// API configuration constants.
class ApiConfig {
  static const String baseUrl = 'http://172.19.3.183:8000/api/v1';
  static const String wsUrl = 'ws://172.19.3.183:8000/ws';
  static const Duration timeout = Duration(seconds: 60);
  static const int maxRetries = 3;
}

/// App-wide constants.
class AppConstants {
  // West Bank center coordinates
  static const double defaultLat = 31.9522;
  static const double defaultLon = 35.2332;
  static const double defaultZoom = 9.0;
}
