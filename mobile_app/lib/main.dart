import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set global Flutter error handler so unhandled errors don't crash the app
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  // Initialize Hive with crash-safe box opening
  await Hive.initFlutter();
  await _openBoxSafe('settings');
  await _openBoxSafe('query_cache');
  await _openBoxSafe('offline_data');

  runApp(
    const ProviderScope(
      child: SituationRoomApp(),
    ),
  );
}

/// Opens a Hive box safely — if the box is corrupted (e.g. from a
/// force-kill during write), it deletes and recreates it.
Future<void> _openBoxSafe(String name) async {
  try {
    await Hive.openBox(name);
  } catch (e) {
    debugPrint('Hive box "$name" corrupted, recreating: $e');
    await Hive.deleteBoxFromDisk(name);
    await Hive.openBox(name);
  }
}
