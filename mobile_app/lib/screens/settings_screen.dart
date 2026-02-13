import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final tr = (String key) => S.t(key, lang);
    final auth = ref.watch(authProvider);

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
