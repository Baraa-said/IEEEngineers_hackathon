import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/facility.dart';

final facilitiesMapProvider = FutureProvider<List<Facility>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getFacilities();
});

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  String _selectedFilter = 'all';
  Facility? _selectedFacility;

  @override
  Widget build(BuildContext context) {
    final facilitiesAsync = ref.watch(facilitiesMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crisis Map'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _selectedFilter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Facilities')),
              const PopupMenuItem(value: 'hospital', child: Text('Hospitals')),
              const PopupMenuItem(value: 'clinic', child: Text('Clinics')),
              const PopupMenuItem(value: 'operational', child: Text('Operational Only')),
              const PopupMenuItem(value: 'damaged', child: Text('Damaged')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              _mapController.move(
                const LatLng(AppConstants.defaultLat, AppConstants.defaultLon),
                10,
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(
                AppConstants.defaultLat,
                AppConstants.defaultLon,
              ),
              initialZoom: AppConstants.defaultZoom,
              onTap: (_, __) => setState(() => _selectedFacility = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'lb.situationroom.app',
              ),
              facilitiesAsync.when(
                data: (facilities) {
                  final filtered = _filterFacilities(facilities);
                  return MarkerLayer(
                    markers: filtered.map((f) => _buildMarker(f)).toList(),
                  );
                },
                loading: () => const MarkerLayer(markers: []),
                error: (_, __) => const MarkerLayer(markers: []),
              ),
            ],
          ),

          // Filter chips
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _selectedFilter == 'all',
                    onTap: () => setState(() => _selectedFilter = 'all'),
                  ),
                  _FilterChip(
                    label: 'Hospitals',
                    selected: _selectedFilter == 'hospital',
                    color: Colors.red,
                    onTap: () => setState(() => _selectedFilter = 'hospital'),
                  ),
                  _FilterChip(
                    label: 'Clinics',
                    selected: _selectedFilter == 'clinic',
                    color: Colors.blue,
                    onTap: () => setState(() => _selectedFilter = 'clinic'),
                  ),
                  _FilterChip(
                    label: 'Operational',
                    selected: _selectedFilter == 'operational',
                    color: Colors.green,
                    onTap: () =>
                        setState(() => _selectedFilter = 'operational'),
                  ),
                  _FilterChip(
                    label: 'Damaged',
                    selected: _selectedFilter == 'damaged',
                    color: Colors.orange,
                    onTap: () => setState(() => _selectedFilter = 'damaged'),
                  ),
                ],
              ),
            ),
          ),

          // Legend
          Positioned(
            bottom: _selectedFacility != null ? 250 : 16,
            right: 8,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LegendItem(color: AppTheme.operational, label: 'Operational'),
                    _LegendItem(color: AppTheme.reducedCapacity, label: 'Reduced'),
                    _LegendItem(color: AppTheme.damaged, label: 'Damaged'),
                    _LegendItem(color: AppTheme.offline, label: 'Offline'),
                  ],
                ),
              ),
            ),
          ),

          // Selected facility detail panel
          if (_selectedFacility != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _FacilityDetailPanel(
                facility: _selectedFacility!,
                onClose: () => setState(() => _selectedFacility = null),
              ),
            ),

          // Loading indicator
          if (facilitiesAsync.isLoading)
            const Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/query'),
        child: const Icon(Icons.chat),
      ),
    );
  }

  List<Facility> _filterFacilities(List<Facility> facilities) {
    switch (_selectedFilter) {
      case 'hospital':
        return facilities.where((f) => f.facilityType == 'hospital').toList();
      case 'clinic':
        return facilities.where((f) => f.facilityType == 'clinic').toList();
      case 'operational':
        return facilities.where((f) => f.status == 'operational').toList();
      case 'damaged':
        return facilities
            .where((f) => f.status == 'damaged' || f.status == 'offline')
            .toList();
      default:
        return facilities;
    }
  }

  Marker _buildMarker(Facility f) {
    final color = AppTheme.statusColor(f.status);
    return Marker(
      point: LatLng(f.latitude, f.longitude),
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () => setState(() => _selectedFacility = f),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            f.facilityType == 'hospital'
                ? Icons.local_hospital
                : f.facilityType == 'pharmacy'
                    ? Icons.local_pharmacy
                    : Icons.medical_services,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.white,
        selectedColor: (color ?? AppTheme.primaryColor).withOpacity(0.2),
        checkmarkColor: color ?? AppTheme.primaryColor,
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(backgroundColor: color, radius: 5),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _FacilityDetailPanel extends StatelessWidget {
  final Facility facility;
  final VoidCallback onClose;

  const _FacilityDetailPanel({
    required this.facility,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  facility.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.statusColor(facility.status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  facility.statusLabel,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (facility.address != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                facility.address!,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                label: 'Beds',
                value: '${facility.availableBeds}/${facility.totalBeds}',
                icon: Icons.bed,
              ),
              _StatItem(
                label: 'ICU',
                value: '${facility.icuAvailable}/${facility.icuBeds}',
                icon: Icons.monitor_heart,
              ),
              _StatItem(
                label: 'Power',
                value: facility.hasPower ? 'Yes' : 'No',
                icon: Icons.power,
                color: facility.hasPower ? Colors.green : Colors.red,
              ),
              _StatItem(
                label: 'O₂',
                value: facility.hasOxygen ? 'Yes' : 'No',
                icon: Icons.air,
                color: facility.hasOxygen ? Colors.green : Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Call'),
                  onPressed: facility.phone != null ? () {} : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Navigate'),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color ?? Colors.grey[700]),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}
