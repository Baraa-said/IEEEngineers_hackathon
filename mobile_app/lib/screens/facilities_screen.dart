import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../models/facility.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/scroll_reveal.dart';

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
  String _sortBy = 'name'; // name, beds, status

  Map<String, dynamic> get _filters => {
        'facility_type': _typeFilter,
        'status': _statusFilter,
      };

  List<Facility> _sortFacilities(List<Facility> list) {
    final sorted = [...list];
    switch (_sortBy) {
      case 'beds':
        sorted.sort((a, b) => b.availableBeds.compareTo(a.availableBeds));
        break;
      case 'status':
        const order = {'operational': 0, 'reduced_capacity': 1, 'damaged': 2, 'offline': 3};
        sorted.sort((a, b) => (order[a.status] ?? 4).compareTo(order[b.status] ?? 4));
        break;
      default:
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final facilitiesAsync = ref.watch(facilitiesProvider(_filters));
    final lang = ref.watch(languageProvider);
    final tr = (String key) => S.t(key, lang);

    return Directionality(
      textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('health_facilities')),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: tr('search_facilities'),
                  hintStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.15),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: tr('sort'),
              onSelected: (v) => setState(() => _sortBy = v),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'name', child: Row(children: [
                  Icon(_sortBy == 'name' ? Icons.check : Icons.sort_by_alpha, size: 18),
                  const SizedBox(width: 8),
                  Text(tr('sort_name')),
                ])),
                PopupMenuItem(value: 'beds', child: Row(children: [
                  Icon(_sortBy == 'beds' ? Icons.check : Icons.bed, size: 18),
                  const SizedBox(width: 8),
                  Text(tr('sort_beds')),
                ])),
                PopupMenuItem(value: 'status', child: Row(children: [
                  Icon(_sortBy == 'status' ? Icons.check : Icons.circle, size: 18),
                  const SizedBox(width: 8),
                  Text(tr('sort_status')),
                ])),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFilterSheet(context, tr),
            ),
          ],
        ),
        body: facilitiesAsync.when(
          data: (facilities) {
            final searched = facilities
                .where((f) =>
                    f.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    (f.district?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
                .toList();
            final filtered = _sortFacilities(searched);

            if (filtered.isEmpty) {
              return Center(child: Text(tr('no_facilities'), style: const TextStyle(color: Colors.grey)));
            }

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(10),
              itemCount: filtered.length,
              itemBuilder: (context, index) => ScrollReveal(
                index: index,
                child: _FacilityCard(facility: filtered[index], tr: tr),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('${tr('error_loading')}\n$err', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.refresh(facilitiesProvider(_filters)),
                  child: Text(tr('retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, String Function(String) tr) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('filter'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(tr('type'), style: const TextStyle(fontWeight: FontWeight.w600)),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: Text(tr('all')), selected: _typeFilter == null, onSelected: (_) => setState(() { _typeFilter = null; Navigator.pop(context); })),
              ChoiceChip(label: Text(tr('hospital')), selected: _typeFilter == 'hospital', onSelected: (_) => setState(() { _typeFilter = 'hospital'; Navigator.pop(context); })),
              ChoiceChip(label: Text(tr('clinic')), selected: _typeFilter == 'clinic', onSelected: (_) => setState(() { _typeFilter = 'clinic'; Navigator.pop(context); })),
            ]),
            const SizedBox(height: 10),
            Text(tr('status'), style: const TextStyle(fontWeight: FontWeight.w600)),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: Text(tr('all')), selected: _statusFilter == null, onSelected: (_) => setState(() { _statusFilter = null; Navigator.pop(context); })),
              ChoiceChip(label: Text(tr('operational')), selected: _statusFilter == 'operational', onSelected: (_) => setState(() { _statusFilter = 'operational'; Navigator.pop(context); })),
              ChoiceChip(label: Text(tr('damaged')), selected: _statusFilter == 'damaged', onSelected: (_) => setState(() { _statusFilter = 'damaged'; Navigator.pop(context); })),
            ]),
          ],
        ),
      ),
    );
  }
}

class _FacilityCard extends StatelessWidget {
  final Facility facility;
  final String Function(String) tr;
  const _FacilityCard({required this.facility, required this.tr});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(facility.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color,
          radius: 18,
          child: Icon(
            facility.facilityType == 'hospital' ? Icons.local_hospital : Icons.medical_services,
            color: Colors.white, size: 18,
          ),
        ),
        title: Text(facility.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(facility.statusLabel, style: TextStyle(color: color, fontSize: 10)),
          ),
          if (facility.district != null) ...[
            const SizedBox(width: 6),
            Flexible(child: Text(facility.district!, style: TextStyle(fontSize: 11, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
          ],
        ]),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(children: [
              const Divider(),
              Row(children: [
                _InfoCell(tr('beds'), '${facility.availableBeds}/${facility.totalBeds}'),
                _InfoCell(tr('icu'), '${facility.icuAvailable}/${facility.icuBeds}'),
                _InfoCell(tr('trauma'), '${facility.traumaAvailable}/${facility.traumaBeds}'),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                _StatusDot(tr('power'), facility.hasPower),
                const SizedBox(width: 12),
                _StatusDot(tr('oxygen'), facility.hasOxygen),
              ]),
            ]),
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
      child: Column(children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ]),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String label;
  final bool active;
  const _StatusDot(this.label, this.active);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(active ? Icons.check_circle : Icons.cancel, size: 14, color: active ? Colors.green : Colors.red),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }
}
