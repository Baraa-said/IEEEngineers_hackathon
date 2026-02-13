import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _staggerController;
  late final AnimationController _sosController;
  late final Animation<double> _sosPulse;

  @override
  void initState() {
    super.initState();

    // Staggered card entrance
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    // SOS pulsing glow
    _sosController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _sosPulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _sosController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _sosController.dispose();
    super.dispose();
  }

  Widget _staggerItem(int index, int total, Widget child) {
    final start = index / total * 0.5;
    final end = (start + 0.5).clamp(0.0, 1.0);
    final fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(start, end, curve: Curves.easeOut)),
    );
    final slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _staggerController, curve: Interval(start, end, curve: Curves.easeOutCubic)),
    );
    return SlideTransition(
      position: slide,
      child: FadeTransition(opacity: fade, child: child),
    );
  }

  /// Get the user's current GPS position, requesting permission if needed.
  Future<Position?> _getCurrentPosition(BuildContext context, String Function(String) tr) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('location_disabled')), backgroundColor: Colors.orange),
          );
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('location_denied')), backgroundColor: Colors.orange),
            );
          }
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('location_denied_forever')), backgroundColor: Colors.red),
          );
        }
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('GPS error: $e');
      return null;
    }
  }

  /// Send SOS report to the backend with GPS coordinates.
  Future<void> _sendSOSAlert(
    BuildContext context,
    WidgetRef ref,
    String emergencyType,
    String Function(String) tr,
  ) async {
    try {
      final position = await _getCurrentPosition(context, tr);
      final api = ref.read(apiServiceProvider);
      final auth = ref.read(authProvider);

      final lat = position?.latitude ?? 31.9522;
      final lon = position?.longitude ?? 35.2332;

      await api.sendSOSReport(
        emergencyType: emergencyType,
        latitude: lat,
        longitude: lon,
        description: 'SOS from mobile app',
        reportedBy: auth.userName ?? 'Mobile User',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('sos_sent')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('SOS send error: $e');
      // Don't block the call — SOS reporting is best-effort
    }
  }

  /// Find the nearest working hospital using GPS and navigate map to it.
  Future<void> _findNearestHospital(
    BuildContext context,
    WidgetRef ref,
    String Function(String) tr,
  ) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(tr('finding_hospital'))),
          ],
        ),
      ),
    );

    try {
      final position = await _getCurrentPosition(context, tr);
      final api = ref.read(apiServiceProvider);

      final lat = position?.latitude ?? 31.9522;
      final lon = position?.longitude ?? 35.2332;

      final nearest = await api.getNearestHospital(latitude: lat, longitude: lon);

      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      if (nearest != null && context.mounted) {
        // Navigate to map screen with the nearest hospital data
        Navigator.pushNamed(
          context,
          '/map',
          arguments: {
            'filter': 'hospital',
            'focusLat': nearest.latitude,
            'focusLon': nearest.longitude,
            'facilityName': nearest.name,
            'userLat': lat,
            'userLon': lon,
          },
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('no_hospital_found')), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('error_loading')), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSOSDialog(BuildContext context, WidgetRef ref, String Function(String) tr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.emergency, color: Colors.red, size: 48),
        title: Text(tr('sos_title'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('sos_desc'), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            // Palestine Red Crescent
            _SOSOption(
              icon: Icons.local_hospital,
              label: tr('sos_red_crescent'),
              subtitle: '101',
              color: Colors.red,
              onTap: () {
                Navigator.pop(ctx);
                _sendSOSAlert(context, ref, 'red_crescent', tr);
                _makeCall('101');
              },
            ),
            const SizedBox(height: 10),
            // Civil Defense
            _SOSOption(
              icon: Icons.fire_truck,
              label: tr('sos_civil_defense'),
              subtitle: '102',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(ctx);
                _sendSOSAlert(context, ref, 'civil_defense', tr);
                _makeCall('102');
              },
            ),
            const SizedBox(height: 10),
            // Police
            _SOSOption(
              icon: Icons.local_police,
              label: tr('sos_police'),
              subtitle: '100',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(ctx);
                _sendSOSAlert(context, ref, 'police', tr);
                _makeCall('100');
              },
            ),
            const SizedBox(height: 10),
            // Nearest hospital
            _SOSOption(
              icon: Icons.map,
              label: tr('sos_nearest'),
              subtitle: tr('sos_find'),
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.pop(ctx);
                _sendSOSAlert(context, ref, 'nearest_hospital', tr);
                _findNearestHospital(context, ref, tr);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
        ],
      ),
    );
  }

  void _makeCall(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final lang = ref.watch(languageProvider);
    final tr = (String key) => S.t(key, lang);

    return Directionality(
      textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('app_title')),
          actions: [
            IconButton(
              icon: const Icon(Icons.language),
              tooltip: lang == 'ar' ? 'English' : 'العربية',
              onPressed: () => ref.read(languageProvider.notifier).toggle(),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle),
              onSelected: (value) {
                if (value == 'logout') {
                  ref.read(authProvider.notifier).logout();
                  Navigator.pushReplacementNamed(context, '/login');
                } else if (value == 'settings') {
                  Navigator.pushNamed(context, '/settings');
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(auth.userName ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'settings', child: Text(tr('settings'))),
                PopupMenuItem(value: 'logout', child: Text(tr('logout'), style: const TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome — fade in
                _staggerItem(
                  0,
                  6,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tr('welcome')}, ${auth.userName ?? 'User'}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(tr('app_subtitle'), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // SOS BUTTON — pulsing
                _staggerItem(
                  1,
                  6,
                  AnimatedBuilder(
                    animation: _sosPulse,
                    builder: (context, child) => Transform.scale(
                      scale: _sosPulse.value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withAlpha((100 * (_sosPulse.value - 1.0) / 0.06 * 0.6 + 0.4).clamp(0.4, 1.0).toInt() + 40),
                              blurRadius: 16 + (_sosPulse.value - 1.0) * 100,
                              spreadRadius: (_sosPulse.value - 1.0) * 30,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: () => _showSOSDialog(context, ref, tr),
                        icon: const Icon(Icons.emergency, size: 28),
                        label: Text(tr('sos_button'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 6,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Main actions — staggered entrance
                Expanded(
                  child: GridView.count(
                    physics: const BouncingScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.1,
                    children: [
                      _staggerItem(
                        2,
                        6,
                        _BigActionCard(
                          icon: Icons.chat_outlined,
                          label: tr('ask_question'),
                          subtitle: tr('ask_subtitle'),
                          color: AppTheme.accentColor,
                          onTap: () => Navigator.pushNamed(context, '/query'),
                        ),
                      ),
                      _staggerItem(
                        3,
                        6,
                        _BigActionCard(
                          icon: Icons.map_outlined,
                          label: tr('map_view'),
                          subtitle: tr('map_sub'),
                          color: AppTheme.primaryColor,
                          onTap: () => Navigator.pushNamed(context, '/map'),
                        ),
                      ),
                      _staggerItem(
                        4,
                        6,
                        _BigActionCard(
                          icon: Icons.local_hospital,
                          label: tr('facilities'),
                          subtitle: tr('facilities_sub'),
                          color: AppTheme.warningColor,
                          onTap: () => Navigator.pushNamed(context, '/facilities'),
                        ),
                      ),
                      _staggerItem(
                        5,
                        6,
                        _BigActionCard(
                          icon: Icons.settings_outlined,
                          label: tr('settings'),
                          subtitle: tr('language'),
                          color: Colors.grey,
                          onTap: () => Navigator.pushNamed(context, '/settings'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Large tappable card with tap-scale animation
class _BigActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _BigActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_BigActionCard> createState() => _BigActionCardState();
}

class _BigActionCardState extends State<_BigActionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _tapController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _tapController.forward(),
      onTapUp: (_) {
        _tapController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _tapController.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.color.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 32),
                ),
                const SizedBox(height: 10),
                Text(widget.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text(widget.subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 11), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// SOS option row in the emergency dialog
class _SOSOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SOSOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                    Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.phone, color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
