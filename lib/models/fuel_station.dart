import 'package:latlong2/latlong.dart';

enum StationStatus { open, closed, limited }
enum QueueTime { none, short5min, medium30min, long1hr }

class FuelStation {
  final String id;
  final String brand;
  final String name;
  final String address;
  final LatLng location;
  final StationStatus status;
  final double? priceUnleaded;
  final double? priceDiesel;
  final double? pricePremium;
  final QueueTime queueTime;
  final DateTime lastUpdated;
  final String? notes;
  double? distanceKm;

  FuelStation({
    required this.id,
    required this.brand,
    required this.name,
    required this.address,
    required this.location,
    required this.status,
    this.priceUnleaded,
    this.priceDiesel,
    this.pricePremium,
    this.queueTime = QueueTime.none,
    required this.lastUpdated,
    this.notes,
    this.distanceKm,
  });

  String get statusText {
    switch (status) {
      case StationStatus.open: return 'Open';
      case StationStatus.closed: return 'Closed';
      case StationStatus.limited: return 'Limited Stock';
    }
  }

  String get statusEmoji {
    switch (status) {
      case StationStatus.open: return '🟢';
      case StationStatus.closed: return '🔴';
      case StationStatus.limited: return '🟡';
    }
  }

  String get queueText {
    switch (queueTime) {
      case QueueTime.none: return 'No queue';
      case QueueTime.short5min: return '~5 min wait';
      case QueueTime.medium30min: return '~30 min wait';
      case QueueTime.long1hr: return '1 hour+ wait';
    }
  }

  double? get cheapestPrice {
    final prices = [priceUnleaded, priceDiesel, pricePremium].whereType<double>();
    if (prices.isEmpty) return null;
    return prices.reduce((a, b) => a < b ? a : b);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'brand': brand,
    'name': name,
    'address': address,
    'lat': location.latitude,
    'lng': location.longitude,
    'status': status.name,
    'priceUnleaded': priceUnleaded,
    'priceDiesel': priceDiesel,
    'pricePremium': pricePremium,
    'queueTime': queueTime.name,
    'lastUpdated': lastUpdated.toIso8601String(),
    'notes': notes,
  };

  factory FuelStation.fromJson(Map<String, dynamic> json) => FuelStation(
    id: json['id'],
    brand: json['brand'],
    name: json['name'],
    address: json['address'],
    location: LatLng(json['lat'], json['lng']),
    status: StationStatus.values.firstWhere((e) => e.name == json['status']),
    priceUnleaded: json['priceUnleaded']?.toDouble(),
    priceDiesel: json['priceDiesel']?.toDouble(),
    pricePremium: json['pricePremium']?.toDouble(),
    queueTime: QueueTime.values.firstWhere(
      (e) => e.name == json['queueTime'],
      orElse: () => QueueTime.none,
    ),
    lastUpdated: DateTime.parse(json['lastUpdated']),
    notes: json['notes'],
  );
}
