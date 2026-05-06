import 'package:latlong2/latlong.dart';

enum OutageStatus { unverified, nopower, scheduled, restored }

class OutageReport {
  final String id;
  final LatLng location;
  final OutageStatus status;
  final String source; // 'crowdsource' or 'official'
  final DateTime reportedAt;
  final DateTime? restoredAt;
  final String? areaName;
  final String? barangay;
  final String? city;
  final int upvotes; // Trust score weighted votes
  final int restoredVotes; // Votes for 'Kuryente Na!'
  final String? notes;
  final bool isVerified;
  final List<String> reporters; // UIDs of users who reported/upvoted
  final List<String> restorers; // UIDs of users who voted restored

  OutageReport({
    required this.id,
    required this.location,
    required this.status,
    this.source = 'crowdsource',
    required this.reportedAt,
    this.restoredAt,
    this.areaName,
    this.barangay,
    this.city,
    this.upvotes = 1,
    this.restoredVotes = 0,
    this.notes,
    this.isVerified = false,
    this.reporters = const [],
    this.restorers = const [],
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
    'source': source,
    'reportedAt': reportedAt.toIso8601String(),
    'restoredAt': restoredAt?.toIso8601String(),
    'areaName': areaName,
    'barangay': barangay,
    'city': city,
    'upvotes': upvotes,
    'restoredVotes': restoredVotes,
    'notes': notes,
    'isVerified': isVerified,
    'reporters': reporters,
    'restorers': restorers,
  };

  factory OutageReport.fromJson(Map<String, dynamic> json) => OutageReport(
    id: json['id'],
    location: LatLng(json['lat'], json['lng']),
    status: OutageStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => OutageStatus.unverified),
    source: json['source'] ?? 'crowdsource',
    reportedAt: DateTime.parse(json['reportedAt']),
    restoredAt: json['restoredAt'] != null ? DateTime.parse(json['restoredAt']) : null,
    areaName: json['areaName'],
    barangay: json['barangay'],
    city: json['city'],
    upvotes: json['upvotes'] ?? 1,
    restoredVotes: json['restoredVotes'] ?? 0,
    notes: json['notes'],
    isVerified: json['isVerified'] ?? false,
    reporters: List<String>.from(json['reporters'] ?? []),
    restorers: List<String>.from(json['restorers'] ?? []),
  );
}
