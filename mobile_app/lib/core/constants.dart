/// API configuration constants.
class ApiConfig {
  static const String baseUrl = 'http://localhost:8000/api/v1';
  static const String wsUrl = 'ws://localhost:8000/ws';
  static const Duration timeout = Duration(seconds: 30);
  static const int maxRetries = 3;
}

/// App-wide constants.
class AppConstants {
  // Lebanon center coordinates
  static const double defaultLat = 33.8938;
  static const double defaultLon = 35.5018;
  static const double defaultZoom = 8.0;

  // Query suggestions
  static const List<String> querySuggestions = [
    'Where is the nearest functional hospital?',
    'Show me all shelters within 5km',
    'Which facilities have oxygen supply?',
    'What is the status of hospitals in Beirut?',
    'Find available ambulances nearby',
    'How many hospitals are operational?',
    'Show medical facilities with trauma beds',
    'Map the distribution of shelters',
  ];

  static const List<String> querySuggestionsAr = [
    'أين أقرب مستشفى يعمل؟',
    'اعرض جميع الملاجئ ضمن 5 كم',
    'ما الحالة الراهنة للمستشفيات في بيروت؟',
    'ابحث عن سيارات إسعاف متاحة بالقرب مني',
  ];
}
