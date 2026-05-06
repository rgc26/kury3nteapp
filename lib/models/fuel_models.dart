import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum FuelStatus { open, longQueue, noStock, closed, unknown }

class FuelStation {
  final String id;
  final String name;
  final LatLng location;
  final String address;
  final String? brand;
  final String? phone;
  final bool isOfficial; // From DOE or Google

  FuelStation({
    required this.id,
    required this.name,
    required this.location,
    required this.address,
    this.brand,
    this.phone,
    this.isOfficial = false,
  });

  factory FuelStation.fromGoogle(Map<String, dynamic> json) {
    final loc = json['geometry']['location'];
    return FuelStation(
      id: json['place_id'],
      name: json['name'],
      location: LatLng(loc['lat'], loc['lng']),
      address: json['vicinity'] ?? '',
      brand: _detectBrand(json['name']),
      isOfficial: true,
    );
  }

  static String? _detectBrand(String name) {
    final n = name.toLowerCase();
    if (n.contains('petron')) return 'Petron';
    if (n.contains('shell')) return 'Shell';
    if (n.contains('caltex')) return 'Caltex';
    if (n.contains('phoenix')) return 'Phoenix';
    if (n.contains('seaoil')) return 'SeaOil';
    if (n.contains('unioil')) return 'Unioil';
    return null;
  }
}

class FuelReport {
  final String id;
  final String stationId;
  final FuelStatus status;
  final DateTime updatedAt;
  final Map<String, dynamic> prices; // e.g. {'Regular': 64.50}
  final String? queueTime;
  final String reportedBy;

  FuelReport({
    required this.id,
    required this.stationId,
    required this.status,
    required this.updatedAt,
    this.prices = const {},
    this.queueTime,
    required this.reportedBy,
  });

  Map<String, dynamic> toJson() => {
    'stationId': stationId,
    'status': status.name,
    'updatedAt': Timestamp.fromDate(updatedAt),
    'prices': prices,
    'queueTime': queueTime,
    'reportedBy': reportedBy,
  };

  factory FuelReport.fromJson(Map<String, dynamic> json, String id) {
    return FuelReport(
      id: id,
      stationId: json['stationId'],
      status: FuelStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => FuelStatus.unknown),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      prices: Map<String, dynamic>.from(json['prices'] ?? {}),
      queueTime: json['queueTime'],
      reportedBy: json['reportedBy'] ?? 'Anonymous',
    );
  }
}
