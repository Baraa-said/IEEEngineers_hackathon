import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

/// Health data we display in the profile.
class HealthSnapshot {
  final int? stepsToday;
  final double? heartRate;        // latest BPM
  final double? bloodOxygen;      // SpO₂ %
  final double? bodyTemp;         // °C
  final double? weight;           // kg
  final double? bpSystolic;
  final double? bpDiastolic;
  final double? bloodGlucose;     // mg/dL
  final double? respiratoryRate;
  final bool authorized;
  final bool loading;
  final String? error;

  const HealthSnapshot({
    this.stepsToday,
    this.heartRate,
    this.bloodOxygen,
    this.bodyTemp,
    this.weight,
    this.bpSystolic,
    this.bpDiastolic,
    this.bloodGlucose,
    this.respiratoryRate,
    this.authorized = false,
    this.loading = false,
    this.error,
  });

  HealthSnapshot copyWith({
    int? stepsToday,
    double? heartRate,
    double? bloodOxygen,
    double? bodyTemp,
    double? weight,
    double? bpSystolic,
    double? bpDiastolic,
    double? bloodGlucose,
    double? respiratoryRate,
    bool? authorized,
    bool? loading,
    String? error,
  }) {
    return HealthSnapshot(
      stepsToday: stepsToday ?? this.stepsToday,
      heartRate: heartRate ?? this.heartRate,
      bloodOxygen: bloodOxygen ?? this.bloodOxygen,
      bodyTemp: bodyTemp ?? this.bodyTemp,
      weight: weight ?? this.weight,
      bpSystolic: bpSystolic ?? this.bpSystolic,
      bpDiastolic: bpDiastolic ?? this.bpDiastolic,
      bloodGlucose: bloodGlucose ?? this.bloodGlucose,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      authorized: authorized ?? this.authorized,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class HealthNotifier extends StateNotifier<HealthSnapshot> {
  HealthNotifier() : super(const HealthSnapshot());

  final _health = Health();

  /// Data types to read from HealthKit / Health Connect.
  static final _types = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.WEIGHT,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.RESPIRATORY_RATE,
  ];

  /// Request permissions and fetch the latest data.
  Future<void> fetchHealthData() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      state = state.copyWith(error: 'Health data not available on this platform');
      return;
    }

    state = state.copyWith(loading: true, error: null);

    try {
      await _health.configure();

      // Request read-only permission
      final granted = await _health.requestAuthorization(
        _types,
        permissions: _types.map((_) => HealthDataAccess.READ).toList(),
      );

      if (!granted) {
        state = state.copyWith(
          loading: false,
          authorized: false,
          error: 'Health permissions not granted',
        );
        return;
      }

      state = state.copyWith(authorized: true);

      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final yesterday = now.subtract(const Duration(hours: 24));

      // Steps today
      int? steps;
      try {
        steps = await _health.getTotalStepsInInterval(midnight, now);
      } catch (_) {}

      // Fetch recent health data points (last 24h)
      List<HealthDataPoint> data = [];
      try {
        data = await _health.getHealthDataFromTypes(
          types: _types.where((t) => t != HealthDataType.STEPS).toList(),
          startTime: yesterday,
          endTime: now,
        );
        data = _health.removeDuplicates(data);
      } catch (e) {
        print('Health data fetch error: $e');
      }

      // Extract newest value of each type
      double? hr, spo2, temp, wt, bpS, bpD, bg, rr;

      for (final type in [
        HealthDataType.HEART_RATE,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.BODY_TEMPERATURE,
        HealthDataType.WEIGHT,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
        HealthDataType.BLOOD_GLUCOSE,
        HealthDataType.RESPIRATORY_RATE,
      ]) {
        final points = data.where((p) => p.type == type).toList();
        if (points.isEmpty) continue;
        points.sort((a, b) => b.dateTo.compareTo(a.dateTo));
        final val = (points.first.value as NumericHealthValue).numericValue.toDouble();
        switch (type) {
          case HealthDataType.HEART_RATE:
            hr = val;
            break;
          case HealthDataType.BLOOD_OXYGEN:
            spo2 = val;
            break;
          case HealthDataType.BODY_TEMPERATURE:
            temp = val;
            break;
          case HealthDataType.WEIGHT:
            wt = val;
            break;
          case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
            bpS = val;
            break;
          case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
            bpD = val;
            break;
          case HealthDataType.BLOOD_GLUCOSE:
            bg = val;
            break;
          case HealthDataType.RESPIRATORY_RATE:
            rr = val;
            break;
          default:
            break;
        }
      }

      state = HealthSnapshot(
        stepsToday: steps,
        heartRate: hr,
        bloodOxygen: spo2,
        bodyTemp: temp,
        weight: wt,
        bpSystolic: bpS,
        bpDiastolic: bpD,
        bloodGlucose: bg,
        respiratoryRate: rr,
        authorized: true,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Failed to read health data: $e',
      );
    }
  }
}

final healthProvider =
    StateNotifierProvider<HealthNotifier, HealthSnapshot>((ref) {
  return HealthNotifier();
});
