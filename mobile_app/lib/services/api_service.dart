import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../core/constants.dart';
import '../models/query_result.dart';
import '../models/facility.dart';

/// API service for communicating with the backend.
class ApiService {
  late final Dio _dio;
  String? _authToken;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.timeout,
      receiveTimeout: ApiConfig.timeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        print('API Error: ${error.message}');
        return handler.next(error);
      },
    ));

    // Load saved token
    final settings = Hive.box('settings');
    _authToken = settings.get('auth_token');
  }

  void setAuthToken(String? token) {
    _authToken = token;
    final settings = Hive.box('settings');
    if (token != null) {
      settings.put('auth_token', token);
    } else {
      settings.delete('auth_token');
    }
  }

  // --- Auth ---

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = response.data;
    setAuthToken(data['access_token']);
    return data;
  }

  Future<Map<String, dynamic>> register(
      String email, String password, String fullName) async {
    final response = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'full_name': fullName,
    });
    final data = response.data;
    setAuthToken(data['access_token']);
    return data;
  }

  void logout() {
    setAuthToken(null);
  }

  // --- Natural Language Query ---

  Future<QueryResult> submitQuery({
    required String query,
    double? latitude,
    double? longitude,
    String language = 'en',
    int maxResults = 10,
  }) async {
    final response = await _dio.post('/query', data: {
      'query': query,
      'latitude': latitude,
      'longitude': longitude,
      'language': language,
      'max_results': maxResults,
    });

    final result = QueryResult.fromJson(response.data);

    // Cache the result
    try {
      final cache = Hive.box('query_cache');
      cache.put(query.hashCode.toString(), response.data);
    } catch (_) {}

    return result;
  }

  /// Get cached query result for offline use
  QueryResult? getCachedQuery(String query) {
    try {
      final cache = Hive.box('query_cache');
      final data = cache.get(query.hashCode.toString());
      if (data != null) {
        return QueryResult.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
    return null;
  }

  // --- Facilities ---

  Future<List<Facility>> getFacilities({
    String? facilityType,
    String? status,
    String? district,
    bool? hasPower,
    bool? hasOxygen,
    double? latitude,
    double? longitude,
    double? radiusKm,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{};
    if (facilityType != null) params['facility_type'] = facilityType;
    if (status != null) params['status'] = status;
    if (district != null) params['district'] = district;
    if (hasPower != null) params['has_power'] = hasPower;
    if (hasOxygen != null) params['has_oxygen'] = hasOxygen;
    if (latitude != null) params['latitude'] = latitude;
    if (longitude != null) params['longitude'] = longitude;
    if (radiusKm != null) params['radius_km'] = radiusKm;
    params['limit'] = limit;

    final response =
        await _dio.get('/facilities', queryParameters: params);
    final list = response.data as List;
    return list.map((e) => Facility.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getFacilityStats() async {
    final response = await _dio.get('/facilities/stats/summary');
    return response.data;
  }

  // --- Resources ---

  Future<List<Map<String, dynamic>>> getResources({
    String? resourceType,
    String? status,
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) async {
    final params = <String, dynamic>{};
    if (resourceType != null) params['resource_type'] = resourceType;
    if (status != null) params['status'] = status;
    if (latitude != null) params['latitude'] = latitude;
    if (longitude != null) params['longitude'] = longitude;
    if (radiusKm != null) params['radius_km'] = radiusKm;

    final response =
        await _dio.get('/resources', queryParameters: params);
    return List<Map<String, dynamic>>.from(response.data);
  }

  // --- Route ---

  Future<Map<String, dynamic>> calculateRoute({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    bool avoidIncidents = true,
  }) async {
    final response = await _dio.post('/route', data: {
      'origin_lat': originLat,
      'origin_lon': originLon,
      'destination_lat': destLat,
      'destination_lon': destLon,
      'avoid_incidents': avoidIncidents,
    });
    return response.data;
  }

  // --- System Status ---

  Future<Map<String, dynamic>> getSystemStatus() async {
    final response = await _dio.get('/status');
    return response.data;
  }
}
