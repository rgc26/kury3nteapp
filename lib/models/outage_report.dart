import 'package:latlong2/latlong.dart';

enum OutageStatus { nopower, scheduled, restored }

class OutageReport {
  final String id;
  final LatLng location;
  final OutageStatus status;
  final DateTime reportedAt;
  final DateTime? restoredAt;
  final String? areaName;
  final String? barangay;
  final String? city;
  final int reporterCount;
  final String? notes;
  final bool isVerified;

  OutageReport({
    required this.id,
    required this.location,
    required this.status,
    required this.reportedAt,
    this.restoredAt,
    this.areaName,
    this.barangay,
    this.city,
    this.reporterCount = 1,
    this.notes,
    this.isVerified = false,
  });

  Duration get outageDuration {
    final end = restoredAt ?? DateTime.now();
    return end.difference(reportedAt);
  }

  String get durationText {
    final d = outageDuration;
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }
    return '${d.inMinutes}m';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'lat': location.latitude,
    'lng': location.longitude,
    'status': status.name,
    'reportedAt': reportedAt.toIso8601String(),
    'restoredAt': restoredAt?.toIso8601String(),
    'areaName': areaName,
    'barangay': barangay,
    'city': city,
    'reporterCount': reporterCount,
    'notes': notes,
    'isVerified': isVerified,
  };

  factory OutageReport.fromJson(Map<String, dynamic> json) => OutageReport(
    id: json['id'],
    location: LatLng(json['lat'], json['lng']),
    status: OutageStatus.values.firstWhere((e) => e.name == json['status']),
    reportedAt: DateTime.parse(json['reportedAt']),
    restoredAt: json['restoredAt'] != null ? DateTime.parse(json['restoredAt']) : null,
    areaName: json['areaName'],
    barangay: json['barangay'],
    city: json['city'],
    reporterCount: json['reporterCount'] ?? 1,
    notes: json['notes'],
    isVerified: json['isVerified'] ?? false,
  );
}
