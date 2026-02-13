/// API configuration constants.
class ApiConfig {
  static const String baseUrl = 'https://5564-213-6-174-230.ngrok-free.app/api/v1';
  static const String wsUrl = 'wss://5564-213-6-174-230.ngrok-free.app/ws';
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
