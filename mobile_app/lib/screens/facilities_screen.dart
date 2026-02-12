import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../models/facility.dart';
import '../providers/auth_provider.dart';

final facilitiesProvider = FutureProvider.family<List<Facility>, Map<String, dynamic>>(
  (ref, filters) async {
    final api = ref.watch(apiServiceProvider);
    return api.getFacilities(
      facilityType: filters['facility_type'],
      status: filters['status'],
      district: filters['district'],
      hasPower: filters['has_power'],
      hasOxygen: filters['has_oxygen'],
    );
  },
);

class FacilitiesScreen extends ConsumerStatefulWidget {
  const FacilitiesScreen({super.key});

  @override
  ConsumerState<FacilitiesScreen> createState() => _FacilitiesScreenState();
}

class _FacilitiesScreenState extends ConsumerState<FacilitiesScreen> {
  String? _typeFilter;
  String? _statusFilter;
  String _searchQuery = '';

  Map<String, dynamic> get _filters => {
        'facility_type': _typeFilter,
        'status': _statusFilter,
      };

  @override
  Widget build(BuildContext context) {
    final facilitiesAsync = ref.watch(facilitiesProvider(_filters));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Facilities'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search facilities...',
                hintStyle: TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: facilitiesAsync.when(
        data: (facilities) {
          final filtered = facilities
              .where((f) =>
                  f.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  (f.district?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
              .toList();

          if (filtered.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No facilities found'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            itemBuilder: (context, index) =>
                _FacilityCard(facility: filtered[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading facilities:\n$err',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(facilitiesProvider(_filters)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter Facilities',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Type', style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                    label: const Text('All'),
                    selected: _typeFilter == null,
                    onSelected: (_) =>
                        setState(() { _typeFilter = null; Navigator.pop(context); })),
                ChoiceChip(
                    label: const Text('Hospital'),
                    selected: _typeFilter == 'hospital',
                    onSelected: (_) =>
                        setState(() { _typeFilter = 'hospital'; Navigator.pop(context); })),
                ChoiceChip(
                    label: const Text('Clinic'),
                    selected: _typeFilter == 'clinic',
                    onSelected: (_) =>
                        setState(() { _typeFilter = 'clinic'; Navigator.pop(context); })),
                ChoiceChip(
                    label: const Text('Pharmacy'),
                    selected: _typeFilter == 'pharmacy',
                    onSelected: (_) =>
                        setState(() { _typeFilter = 'pharmacy'; Navigator.pop(context); })),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                    label: const Text('All'),
                    selected: _statusFilter == null,
                    onSelected: (_) =>
                        setState(() { _statusFilter = null; Navigator.pop(context); })),
                ChoiceChip(
                    label: const Text('Operational'),
                    selected: _statusFilter == 'operational',
                    onSelected: (_) =>
                        setState(() { _statusFilter = 'operational'; Navigator.pop(context); })),
                ChoiceChip(
                    label: const Text('Reduced'),
                    selected: _statusFilter == 'reduced_capacity',
                    onSelected: (_) =>
                        setState(() { _statusFilter = 'reduced_capacity'; Navigator.pop(context); })),
                ChoiceChip(
                    label: const Text('Damaged'),
                    selected: _statusFilter == 'damaged',
                    onSelected: (_) =>
                        setState(() { _statusFilter = 'damaged'; Navigator.pop(context); })),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FacilityCard extends StatelessWidget {
  final Facility facility;
  const _FacilityCard({required this.facility});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(facility.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(
            facility.facilityType == 'hospital'
                ? Icons.local_hospital
                : facility.facilityType == 'pharmacy'
                    ? Icons.local_pharmacy
                    : Icons.medical_services,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          facility.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                facility.statusLabel,
                style: TextStyle(color: color, fontSize: 11),
              ),
            ),
            if (facility.district != null) ...[
              const SizedBox(width: 8),
              Text(facility.district!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                const Divider(),
                // Statistics grid
                Row(
                  children: [
                    _InfoCell('Beds', '${facility.availableBeds}/${facility.totalBeds}'),
                    _InfoCell('ICU', '${facility.icuAvailable}/${facility.icuBeds}'),
                    _InfoCell('Trauma', '${facility.traumaAvailable}/${facility.traumaBeds}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _InfoCell(
                        'Power',
                        facility.hasPower ? '✅' : '❌'),
                    _InfoCell(
                        'Oxygen',
                        facility.hasOxygen ? '✅' : '❌'),
                    _InfoCell(
                        'Water',
                        facility.hasWater ? '✅' : '❌'),
                  ],
                ),
                if (facility.edWaitTimeMinutes != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('ED Wait: ${facility.edWaitTimeMinutes} min',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
                if (facility.specialties.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: facility.specialties
                        .map((s) => Chip(
                              label: Text(s, style: const TextStyle(fontSize: 10)),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.phone, size: 16),
                        label: const Text('Call', style: TextStyle(fontSize: 13)),
                        onPressed: facility.phone != null ? () {} : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.map, size: 16),
                        label: const Text('Map', style: TextStyle(fontSize: 13)),
                        onPressed: () =>
                            Navigator.pushNamed(context, '/map'),
                      ),
                    ),
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

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCell(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
