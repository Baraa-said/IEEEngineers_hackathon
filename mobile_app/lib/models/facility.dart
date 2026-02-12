/// Data model for health facility.
class Facility {
  final String id;
  final String name;
  final String? nameAr;
  final String facilityType;
  final String status;
  final double latitude;
  final double longitude;
  final String? address;
  final String? district;
  final String? governorate;
  final int totalBeds;
  final int availableBeds;
  final int icuBeds;
  final int icuAvailable;
  final int traumaBeds;
  final int traumaAvailable;
  final bool hasPower;
  final bool hasGenerator;
  final bool hasOxygen;
  final bool hasWater;
  final List<String> specialties;
  final bool emergencyDepartment;
  final int? edWaitTimeMinutes;
  final int totalStaff;
  final int availableStaff;
  final int doctorsOnDuty;
  final int nursesOnDuty;
  final String? phone;
  final String? emergencyPhone;
  final DateTime? lastStatusUpdate;
  final double? distanceKm;

  Facility({
    required this.id,
    required this.name,
    this.nameAr,
    required this.facilityType,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.address,
    this.district,
    this.governorate,
    this.totalBeds = 0,
    this.availableBeds = 0,
    this.icuBeds = 0,
    this.icuAvailable = 0,
    this.traumaBeds = 0,
    this.traumaAvailable = 0,
    this.hasPower = true,
    this.hasGenerator = false,
    this.hasOxygen = true,
    this.hasWater = true,
    this.specialties = const [],
    this.emergencyDepartment = false,
    this.edWaitTimeMinutes,
    this.totalStaff = 0,
    this.availableStaff = 0,
    this.doctorsOnDuty = 0,
    this.nursesOnDuty = 0,
    this.phone,
    this.emergencyPhone,
    this.lastStatusUpdate,
    this.distanceKm,
  });

  factory Facility.fromJson(Map<String, dynamic> json) {
    return Facility(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['name_ar'],
      facilityType: json['facility_type'] ?? 'hospital',
      status: json['status'] ?? 'operational',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      address: json['address'],
      district: json['district'],
      governorate: json['governorate'],
      totalBeds: json['total_beds'] ?? 0,
      availableBeds: json['available_beds'] ?? 0,
      icuBeds: json['icu_beds'] ?? 0,
      icuAvailable: json['icu_available'] ?? 0,
      traumaBeds: json['trauma_beds'] ?? 0,
      traumaAvailable: json['trauma_available'] ?? 0,
      hasPower: json['has_power'] ?? true,
      hasGenerator: json['has_generator'] ?? false,
      hasOxygen: json['has_oxygen'] ?? true,
      hasWater: json['has_water'] ?? true,
      specialties: List<String>.from(json['specialties'] ?? []),
      emergencyDepartment: json['emergency_department'] ?? false,
      edWaitTimeMinutes: json['ed_wait_time_minutes'],
      totalStaff: json['total_staff'] ?? 0,
      availableStaff: json['available_staff'] ?? 0,
      doctorsOnDuty: json['doctors_on_duty'] ?? 0,
      nursesOnDuty: json['nurses_on_duty'] ?? 0,
      phone: json['phone'],
      emergencyPhone: json['emergency_phone'],
      lastStatusUpdate: json['last_status_update'] != null
          ? DateTime.tryParse(json['last_status_update'])
          : null,
      distanceKm: json['distance_km']?.toDouble(),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'operational':
        return 'Operational';
      case 'reduced_capacity':
        return 'Reduced Capacity';
      case 'damaged':
        return 'Damaged';
      case 'offline':
        return 'Offline';
      default:
        return status;
    }
  }

  double get bedOccupancyRate {
    if (totalBeds == 0) return 0;
    return (totalBeds - availableBeds) / totalBeds;
  }
}
