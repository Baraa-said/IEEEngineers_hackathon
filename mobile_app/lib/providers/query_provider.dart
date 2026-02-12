import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/query_result.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

/// State for the query feature.
class QueryState {
  final bool isLoading;
  final QueryResult? result;
  final String? error;
  final List<String> queryHistory;

  const QueryState({
    this.isLoading = false,
    this.result,
    this.error,
    this.queryHistory = const [],
  });

  QueryState copyWith({
    bool? isLoading,
    QueryResult? result,
    String? error,
    List<String>? queryHistory,
  }) {
    return QueryState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      error: error,
      queryHistory: queryHistory ?? this.queryHistory,
    );
  }
}

class QueryNotifier extends StateNotifier<QueryState> {
  final ApiService _api;

  QueryNotifier(this._api) : super(const QueryState());

  Future<void> submitQuery(
    String query, {
    double? latitude,
    double? longitude,
    String language = 'en',
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _api.submitQuery(
        query: query,
        latitude: latitude,
        longitude: longitude,
        language: language,
      );

      final history = [...state.queryHistory];
      if (!history.contains(query)) {
        history.insert(0, query);
        if (history.length > 20) history.removeLast();
      }

      state = QueryState(
        result: result,
        queryHistory: history,
      );
    } catch (e) {
      // Try cached result
      final cached = _api.getCachedQuery(query);
      if (cached != null) {
        state = QueryState(
          result: cached,
          error: 'Showing cached result (offline)',
          queryHistory: state.queryHistory,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to process query. Please try again.',
        );
      }
    }
  }

  void clearResult() {
    state = QueryState(queryHistory: state.queryHistory);
  }
}

final queryProvider =
    StateNotifierProvider<QueryNotifier, QueryState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return QueryNotifier(api);
});
