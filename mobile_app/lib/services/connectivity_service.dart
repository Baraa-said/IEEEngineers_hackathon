import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../core/constants.dart';
import 'offline_queue_service.dart';

/// Tracks network connectivity and replays queued requests when back online.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _sub;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onlineStream => _controller.stream;

  /// Start listening to connectivity changes.
  void init() {
    try {
      _connectivity.checkConnectivity().then((result) {
        _handleResult(result);
      }).catchError((e) {
        print('Connectivity check failed: $e');
      });

      _sub = _connectivity.onConnectivityChanged.listen((result) {
        _handleResult(result);
      });
    } catch (e) {
      print('Connectivity init failed: $e');
    }
  }

  /// Handle result which may be ConnectivityResult or List<ConnectivityResult>
  void _handleResult(dynamic result) {
    bool online;
    if (result is List) {
      online = result.any((r) => r != ConnectivityResult.none);
    } else if (result is ConnectivityResult) {
      online = result != ConnectivityResult.none;
    } else {
      online = true;
    }
    final wasOffline = !_isOnline;
    _isOnline = online;
    _controller.add(online);

    print('🌐 Connectivity: ${online ? "ONLINE" : "OFFLINE"} ($result)');

    if (online && wasOffline) {
      drainQueue();
    }
  }

  /// Replay all pending offline requests.
  Future<void> drainQueue() async {
    final pending = OfflineQueueService.getPending();
    if (pending.isEmpty) return;

    print('🔄 Draining ${pending.length} queued offline requests …');

    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.timeout,
      receiveTimeout: ApiConfig.timeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    ));

    for (final req in pending) {
      try {
        if (req.method == 'POST') {
          await dio.post(req.path, data: req.data);
        } else {
          await dio.get(req.path, queryParameters: req.data);
        }
        OfflineQueueService.remove(req.id);
        print('✅ Replayed: ${req.label}');
      } catch (e) {
        print('❌ Failed to replay ${req.label}: $e');
        // Leave in queue for next attempt
      }
    }
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}