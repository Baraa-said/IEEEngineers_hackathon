import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/health_provider.dart';
import '../core/theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final tr = (String key) => S.t(key, lang);
    final auth = ref.watch(authProvider);
    final health = ref.watch(healthProvider);

    return Directionality(
      textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(tr('settings'))),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // User info
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(auth.userName ?? tr('guest')),
                subtitle: Text(auth.userRole ?? ''),
              ),
            ),
            const SizedBox(height: 8),

            // ── Health Data Section ──
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: Icon(Icons.favorite, color: Colors.red[400]),
                    title: Text(tr('health_data'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: health.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : health.authorized
                            ? Icon(Icons.check_circle,
                                color: Colors.green[400], size: 24)
                            : FilledButton.icon(
                                onPressed: () => ref
                                    .read(healthProvider.notifier)
                                    .fetchHealthData(),
                                icon: const Icon(Icons.sync, size: 16),
                                label: Text(tr('health_sync'),
                                    style: const TextStyle(fontSize: 12)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                ),
                              ),
                  ),
                  if (health.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(health.error!,
                          style:
                              TextStyle(color: Colors.red[400], fontSize: 12)),
                    ),
                  if (!health.authorized && !health.loading && health.error == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(tr('health_tap_sync'),
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12)),
                    ),
                  if (health.authorized) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: _HealthGrid(health: health, tr: tr),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Language
            Card(
              child: ListTile(
                leading: const Icon(Icons.language),
                title: Text(tr('language')),
                subtitle: Text(lang == 'ar' ? 'العربية' : 'English'),
                trailing: Switch(
                  value: lang == 'ar',
                  onChanged: (_) => ref.read(languageProvider.notifier).toggle(),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Info
            Card(
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(tr('about')),
                  subtitle: Text(tr('app_title')),
                ),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(tr('version')),
                  subtitle: const Text('1.0.0'),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                  Navigator.pushReplacementNamed(context, '/login');
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: Text(tr('logout'), style: const TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2×4 grid of health metric tiles.
class _HealthGrid extends StatelessWidget {
  final HealthSnapshot health;
  final String Function(String) tr;

  const _HealthGrid({required this.health, required this.tr});

  @override
  Widget build(BuildContext context) {
    final items = <_HealthTileData>[
      _HealthTileData(
        icon: Icons.directions_walk,
        color: Colors.blue,
        label: tr('health_steps'),
        value: health.stepsToday != null ? '${health.stepsToday}' : '--',
        unit: '',
      ),
      _HealthTileData(
        icon: Icons.favorite,
        color: Colors.red,
        label: tr('health_heart_rate'),
        value: health.heartRate != null
            ? '${health.heartRate!.round()}'
            : '--',
        unit: tr('health_bpm'),
      ),
      _HealthTileData(
        icon: Icons.water_drop,
        color: Colors.lightBlue,
        label: tr('health_spo2'),
        value: health.bloodOxygen != null
            ? '${health.bloodOxygen!.round()}%'
            : '--',
        unit: '',
      ),
      _HealthTileData(
        icon: Icons.thermostat,
        color: Colors.orange,
        label: tr('health_temp'),
        value: health.bodyTemp != null
            ? '${health.bodyTemp!.toStringAsFixed(1)}°'
            : '--',
        unit: '',
      ),
      _HealthTileData(
        icon: Icons.monitor_weight,
        color: Colors.teal,
        label: tr('health_weight'),
        value: health.weight != null
            ? '${health.weight!.toStringAsFixed(1)}'
            : '--',
        unit: 'kg',
      ),
      _HealthTileData(
        icon: Icons.speed,
        color: Colors.purple,
        label: tr('health_bp'),
        value: health.bpSystolic != null && health.bpDiastolic != null
            ? '${health.bpSystolic!.round()}/${health.bpDiastolic!.round()}'
            : '--',
        unit: 'mmHg',
      ),
      _HealthTileData(
        icon: Icons.bloodtype,
        color: Colors.pink,
        label: tr('health_glucose'),
        value: health.bloodGlucose != null
            ? '${health.bloodGlucose!.round()}'
            : '--',
        unit: 'mg/dL',
      ),
      _HealthTileData(
        icon: Icons.air,
        color: Colors.green,
        label: tr('health_resp'),
        value: health.respiratoryRate != null
            ? '${health.respiratoryRate!.round()}'
            : '--',
        unit: '/min',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: items.map((d) => _HealthTile(data: d)).toList(),
    );
  }
}

class _HealthTileData {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;

  _HealthTileData({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
  });
}

class _HealthTile extends StatelessWidget {
  final _HealthTileData data;
  const _HealthTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final hasData = data.value != '--';
    return Container(
      decoration: BoxDecoration(
        color: data.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: data.color.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(data.icon, color: data.color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(data.label,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(data.value,
                        style: TextStyle(
                          fontSize: hasData ? 18 : 16,
                          fontWeight: FontWeight.w800,
                          color: hasData ? data.color : Colors.grey[400],
                        )),
                    if (data.unit.isNotEmpty) ...[
                      const SizedBox(width: 3),
                      Text(data.unit,
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[500])),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
