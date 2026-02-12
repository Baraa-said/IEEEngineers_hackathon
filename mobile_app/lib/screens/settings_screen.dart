import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // User info
          Container(
            padding: const EdgeInsets.all(24),
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    (auth.userName ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 28, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  auth.userName ?? 'User',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  auth.userRole ?? 'viewer',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // General settings
          const _SectionHeader('General'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: const Text('English'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Select Language'),
                  children: [
                    SimpleDialogOption(
                      child: const Text('English'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SimpleDialogOption(
                      child: const Text('العربية (Arabic)'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            subtitle: const Text('Use system default'),
            value: false,
            onChanged: (v) {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive real-time alerts'),
            value: true,
            onChanged: (v) {},
          ),

          // Data settings
          const _SectionHeader('Data & Connectivity'),
          ListTile(
            leading: const Icon(Icons.cloud_download),
            title: const Text('Offline Data'),
            subtitle: const Text('Download maps and facility data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading offline data...')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Clear Cache'),
            subtitle: const Text('Remove cached queries and data'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.api),
            title: const Text('API Server'),
            subtitle: const Text('http://localhost:8000'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          // Emergency
          const _SectionHeader('Emergency'),
          SwitchListTile(
            secondary: const Icon(Icons.warning, color: Colors.red),
            title: const Text('Emergency Mode'),
            subtitle: const Text('High-visibility UI with larger controls'),
            value: false,
            onChanged: (v) {},
          ),

          // About
          const _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Ethics & Privacy Policy'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Open Source Licenses'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Situation Room',
              applicationVersion: '1.0.0',
            ),
          ),

          // Logout
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1,
        ),
      ),
    );
  }
}
