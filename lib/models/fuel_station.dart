import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum StationStatus { 
  openHasStock,   // Bukas at may gasolina
  longQueue,      // Matagal na pila
  outOfStock,     // Wala nang gasolina
  closed,         // Sarado
  unknown 
}

enum FuelType { regular, unleaded, diesel, premium }

class FuelStation {
  final String id;
  final String brand;
  final String name;
  final String address;
  final LatLng location;
  final StationStatus status;
  final Map<String, double> prices; // e.g. {'Regular': 64.50}
  final DateTime lastUpdated;
  final String? reportedBy;
  double? distanceKm;

  FuelStation({
    required this.id,
    required this.brand,
    required this.name,
    required this.address,
    required this.location,
    this.status = StationStatus.unknown,
    this.prices = const {},
    required this.lastUpdated,
    this.reportedBy,
    this.distanceKm,
  });

  String get statusText {
    switch (status) {
      case StationStatus.openHasStock: return 'Bukas at may gasolina';
      case StationStatus.longQueue: return 'Matagal na pila';
      case StationStatus.outOfStock: return 'Wala nang gasolina';
      case StationStatus.closed: return 'Sarado';
      case StationStatus.unknown: return 'Unknown Status';
    }
  }

  String get statusEmoji {
    switch (status) {
      case StationStatus.openHasStock: return '✅';
      case StationStatus.longQueue: return '⚠️';
      case StationStatus.outOfStock: return '🪫';
      case StationStatus.closed: return '❌';
      case StationStatus.unknown: return '⚪';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'brand': brand,
    'name': name,
    'address': address,
    'location': GeoPoint(location.latitude, location.longitude),
    'status': status.name,
    'prices': prices,
    'lastUpdated': Timestamp.fromDate(lastUpdated),
    'reportedBy': reportedBy,
  };

  factory FuelStation.fromJson(Map<String, dynamic> json, [String? docId]) {
    final gp = json['location'] as GeoPoint?;
    return FuelStation(
      id: docId ?? json['id'] ?? '',
      brand: json['brand'] ?? 'Unknown',
      name: json['name'] ?? 'Gas Station',
      address: json['address'] ?? '',
      location: gp != null ? LatLng(gp.latitude, gp.longitude) : const LatLng(0, 0),
      status: StationStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => StationStatus.unknown),
      prices: Map<String, double>.from(json['prices'] ?? {}),
      lastUpdated: (json['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reportedBy: json['reportedBy'],
    );
  }
}
