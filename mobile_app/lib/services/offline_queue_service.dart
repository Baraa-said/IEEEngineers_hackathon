import 'dart:convert';
import 'package:hive/hive.dart';

/// A single pending offline request.
class PendingRequest {
  final String id;
  final String method; // POST, GET
  final String path; // e.g. /sos, /chat
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final String label; // human-readable label like "SOS Alert"

  PendingRequest({
    required this.id,
    required this.method,
    required this.path,
    this.data,
    required this.createdAt,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'path': path,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'label': label,
      };

  factory PendingRequest.fromJson(Map<String, dynamic> json) {
    return PendingRequest(
      id: json['id'] as String,
      method: json['method'] as String,
      path: json['path'] as String,
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'])
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      label: json['label'] as String? ?? '',
    );
  }
}

/// Manages a persistent queue of requests made while offline.
/// Requests are stored in Hive and replayed when connectivity returns.
class OfflineQueueService {
  static const _boxName = 'offline_data';
  static const _queueKey = 'pending_requests';
  static const _facilitiesCacheKey = 'cached_facilities';
  static const _resourcesCacheKey = 'cached_resources';
  static const _dashboardCacheKey = 'cached_dashboard';

  // --------------- Queue Management ---------------

  /// Add a request to the offline queue.
  static void enqueue(PendingRequest request) {
    try {
      final box = Hive.box(_boxName);
      final raw = box.get(_queueKey, defaultValue: <dynamic>[]) as List;
      final list = List<Map<String, dynamic>>.from(
        raw.map((e) => Map<String, dynamic>.from(e as Map)),
      );
      list.add(request.toJson());
      box.put(_queueKey, list);
      print('📥 Queued offline: ${request.label} (${request.path})');
    } catch (e) {
      print('Failed to enqueue offline request: $e');
    }
  }

  /// Get all pending requests.
  static List<PendingRequest> getPending() {
    try {
      final box = Hive.box(_boxName);
      final raw = box.get(_queueKey, defaultValue: <dynamic>[]) as List;
      return raw
          .map((e) =>
              PendingRequest.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      print('Failed to read pending queue: $e');
      return [];
    }
  }

  /// Remove a request by ID after successful replay.
  static void remove(String id) {
    try {
      final box = Hive.box(_boxName);
      final raw = box.get(_queueKey, defaultValue: <dynamic>[]) as List;
      final list = List<Map<String, dynamic>>.from(
        raw.map((e) => Map<String, dynamic>.from(e as Map)),
      );
      list.removeWhere((e) => e['id'] == id);
      box.put(_queueKey, list);
    } catch (_) {}
  }

  /// Clear entire queue.
  static void clearQueue() {
    try {
      Hive.box(_boxName).delete(_queueKey);
    } catch (_) {}
  }

  /// Number of pending requests.
  static int get pendingCount => getPending().length;

  // --------------- Data Cache ---------------

  /// Cache facilities list as JSON.
  static void cacheFacilities(List<dynamic> facilitiesJson) {
    try {
      final box = Hive.box(_boxName);
      box.put(_facilitiesCacheKey, jsonEncode(facilitiesJson));
      print('💾 Cached ${facilitiesJson.length} facilities offline');
    } catch (e) {
      print('Failed to cache facilities: $e');
    }
  }

  /// Get cached facilities JSON list, or null.
  static List<dynamic>? getCachedFacilities() {
    try {
      final box = Hive.box(_boxName);
      final raw = box.get(_facilitiesCacheKey);
      if (raw != null) {
        return jsonDecode(raw as String) as List<dynamic>;
      }
    } catch (e) {
      print('Failed to read cached facilities: $e');
    }
    return null;
  }

  /// Cache resources list as JSON.
  static void cacheResources(List<dynamic> resourcesJson) {
    try {
      final box = Hive.box(_boxName);
      box.put(_resourcesCacheKey, jsonEncode(resourcesJson));
      print('💾 Cached ${resourcesJson.length} resources offline');
    } catch (e) {
      print('Failed to cache resources: $e');
    }
  }

  /// Get cached resources JSON list, or null.
  static List<dynamic>? getCachedResources() {
    try {
      final box = Hive.box(_boxName);
      final raw = box.get(_resourcesCacheKey);
      if (raw != null) {
        return jsonDecode(raw as String) as List<dynamic>;
      }
    } catch (e) {
      print('Failed to read cached resources: $e');
    }
    return null;
  }

  /// Cache dashboard stats.
  static void cacheDashboard(Map<String, dynamic> stats) {
    try {
      final box = Hive.box(_boxName);
      box.put(_dashboardCacheKey, jsonEncode(stats));
    } catch (_) {}
  }

  /// Get cached dashboard stats.
  static Map<String, dynamic>? getCachedDashboard() {
    try {
      final box = Hive.box(_boxName);
      final raw = box.get(_dashboardCacheKey);
      if (raw != null) {
        return Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
      }
    } catch (_) {}
    return null;
  }
}
