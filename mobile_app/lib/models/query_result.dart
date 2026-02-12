/// Data model for query response from the API.
class QueryResult {
  final String queryId;
  final String query;
  final String answer;
  final double confidenceScore;
  final List<DataSource> dataSources;
  final List<MapMarker> mapMarkers;
  final Map<String, dynamic>? statistics;
  final int responseTimeMs;
  final DateTime timestamp;
  final String language;

  QueryResult({
    required this.queryId,
    required this.query,
    required this.answer,
    required this.confidenceScore,
    required this.dataSources,
    required this.mapMarkers,
    this.statistics,
    required this.responseTimeMs,
    required this.timestamp,
    required this.language,
  });

  factory QueryResult.fromJson(Map<String, dynamic> json) {
    return QueryResult(
      queryId: json['query_id'] ?? '',
      query: json['query'] ?? '',
      answer: json['answer'] ?? '',
      confidenceScore: (json['confidence_score'] ?? 0.0).toDouble(),
      dataSources: (json['data_sources'] as List? ?? [])
          .map((e) => DataSource.fromJson(e))
          .toList(),
      mapMarkers: (json['map_markers'] as List? ?? [])
          .map((e) => MapMarker.fromJson(e))
          .toList(),
      statistics: json['statistics'],
      responseTimeMs: json['response_time_ms'] ?? 0,
      timestamp:
          DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      language: json['language'] ?? 'en',
    );
  }
}

class DataSource {
  final String name;
  final String freshness;
  final int recordCount;

  DataSource({
    required this.name,
    required this.freshness,
    required this.recordCount,
  });

  factory DataSource.fromJson(Map<String, dynamic> json) {
    return DataSource(
      name: json['name'] ?? '',
      freshness: json['freshness'] ?? '',
      recordCount: json['record_count'] ?? 0,
    );
  }
}

class MapMarker {
  final double latitude;
  final double longitude;
  final String label;
  final String type;
  final String? status;
  final Map<String, dynamic>? details;

  MapMarker({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.type,
    this.status,
    this.details,
  });

  factory MapMarker.fromJson(Map<String, dynamic> json) {
    return MapMarker(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      label: json['label'] ?? '',
      type: json['type'] ?? '',
      status: json['status'],
      details: json['details'],
    );
  }
}
