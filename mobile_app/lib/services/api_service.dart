import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:hive/hive.dart';
import '../core/constants.dart';
import '../models/query_result.dart';
import '../models/facility.dart';
import 'offline_queue_service.dart';
import 'connectivity_service.dart';

/// API service for communicating with the backend.
class ApiService {
  late final Dio _dio;
  String? _authToken;
  ConnectivityService? _connectivity;

  /// Attach the connectivity service so we can check online/offline.
  void attachConnectivity(ConnectivityService cs) => _connectivity = cs;

  /// Whether we believe we are online right now.
  bool get _isOnline => _connectivity?.isOnline ?? true;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.timeout,
      receiveTimeout: ApiConfig.timeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    ));

    // Accept all certificates (ngrok free tier uses certs that iOS rejects)
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    };

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        print('API Error: ${error.message}');
        // If 401, clear stale token and retry without auth
        if (error.response?.statusCode == 401 && _authToken != null) {
          print('Token expired — clearing and retrying');
          setAuthToken(null);
          final opts = error.requestOptions;
          opts.headers.remove('Authorization');
          _dio.fetch(opts).then(
            (r) => handler.resolve(r),
            onError: (e) => handler.next(e is DioException ? e : error),
          );
          return;
        }
        return handler.next(error);
      },
    ));

    // Load saved token safely
    try {
      if (Hive.isBoxOpen('settings')) {
        final settings = Hive.box('settings');
        _authToken = settings.get('auth_token');
      }
    } catch (e) {
      print('Failed to load auth token from Hive: $e');
    }
  }

  void setAuthToken(String? token) {
    _authToken = token;
    try {
      if (Hive.isBoxOpen('settings')) {
        final settings = Hive.box('settings');
        if (token != null) {
          settings.put('auth_token', token);
        } else {
          settings.delete('auth_token');
        }
      }
    } catch (e) {
      print('Failed to save auth token to Hive: $e');
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

  // --- AI Chat Agent ---

  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    List<Map<String, dynamic>> history = const [],
    String? imageDescription,
    double? latitude,
    double? longitude,
    String language = 'en',
  }) async {
    try {
      final response = await _dio.post('/chat', data: {
        'message': message,
        'history': history,
        if (imageDescription != null) 'image_description': imageDescription,
        'latitude': latitude,
        'longitude': longitude,
        'language': language,
      });
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      // If offline, return a helpful placeholder instead of crashing
      return {
        'response': 'You are currently offline. Your question has been noted — please try again when connectivity is restored.',
        'offline': true,
      };
    }
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

    try {
      final response =
          await _dio.get('/facilities', queryParameters: params);
      final list = response.data as List;
      // Cache full unfiltered fetches for offline
      if (facilityType == null && status == null && district == null) {
        OfflineQueueService.cacheFacilities(list);
      }
      return list.map((e) => Facility.fromJson(e)).toList();
    } catch (e) {
      // Offline fallback — return cached data
      final cached = OfflineQueueService.getCachedFacilities();
      if (cached != null) {
        print('📴 Returning ${cached.length} cached facilities (offline)');
        var facilities = cached
            .map((e) => Facility.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        // Apply basic filters on cached data
        if (facilityType != null) {
          facilities = facilities.where((f) => f.facilityType == facilityType).toList();
        }
        if (status != null) {
          facilities = facilities.where((f) => f.status == status).toList();
        }
        return facilities;
      }
      rethrow;
    }
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

    try {
      final response =
          await _dio.get('/resources', queryParameters: params);
      final list = List<Map<String, dynamic>>.from(response.data);
      // Cache unfiltered fetches
      if (resourceType == null && status == null) {
        OfflineQueueService.cacheResources(list);
      }
      return list;
    } catch (e) {
      final cached = OfflineQueueService.getCachedResources();
      if (cached != null) {
        print('📴 Returning ${cached.length} cached resources (offline)');
        var resources = cached
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (resourceType != null) {
          resources = resources.where((r) => r['resource_type'] == resourceType).toList();
        }
        if (status != null) {
          resources = resources.where((r) => r['status'] == status).toList();
        }
        return resources;
      }
      rethrow;
    }
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

  // --- SOS Report ---

  /// Send an SOS emergency report with the user's GPS location.
  /// If offline, queues the request and returns a placeholder response.
  Future<Map<String, dynamic>> sendSOSReport({
    required String emergencyType,
    required double latitude,
    required double longitude,
    String? description,
    String? reportedBy,
  }) async {
    final body = {
      'emergency_type': emergencyType,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'reported_by': reportedBy,
    };

    try {
      final response = await _dio.post('/sos', data: body);
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      // Queue for later if we appear to be offline
      OfflineQueueService.enqueue(PendingRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        method: 'POST',
        path: '/sos',
        data: body,
        createdAt: DateTime.now(),
        label: 'SOS: $emergencyType',
      ));
      print('📴 SOS queued for later delivery (offline)');
      return {
        'status': 'queued',
        'message': 'SOS report saved and will be sent when you are back online.',
        'offline': true,
      };
    }
  }

  /// Get operational hospitals sorted by distance from given coordinates.
  Future<Facility?> getNearestHospital({
    required double latitude,
    required double longitude,
  }) async {
    final hospitals = await getFacilities(
      facilityType: 'hospital',
      status: 'operational',
      limit: 200,
    );
    if (hospitals.isEmpty) return null;

    // Calculate distance using Haversine-like simple approximation
    Facility? nearest;
    double minDist = double.infinity;
    for (final h in hospitals) {
      final dLat = (h.latitude - latitude);
      final dLon = (h.longitude - longitude);
      final dist = dLat * dLat + dLon * dLon; // squared euclidean, sufficient for comparison
      if (dist < minDist) {
        minDist = dist;
        nearest = h;
      }
    }
    return nearest;
  }
}
