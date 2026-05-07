import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Appliance {
  final String name;
  final IconData icon;
  final int defaultWattage;
  int wattage;
  double hoursPerDay;
  bool isSelected;

  Appliance({
    required this.name,
    required this.icon,
    required this.defaultWattage,
    int? wattage,
    this.hoursPerDay = 0,
    this.isSelected = false,
  }) : wattage = wattage ?? defaultWattage;

  double get dailyKwh => (wattage * hoursPerDay) / 1000;
  double get monthlyKwh => dailyKwh * 30;

  Map<String, dynamic> toJson() => {
    'name': name,
    'wattage': wattage,
    'hoursPerDay': hoursPerDay,
    'isSelected': isSelected,
  };
}

class BayanihanPost {
  final String id;
  final BayanihanCategory category;
  final String title;
  final String description;
  final String? location;
  final String? contactInfo;
  final String? availability;
  final DateTime createdAt;
  int interestedCount;
  int salamatCount;

  BayanihanPost({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    this.location,
    this.contactInfo,
    this.availability,
    required this.createdAt,
    this.interestedCount = 0,
    this.salamatCount = 0,
  });

  String get categoryEmoji {
    switch (category) {
      case BayanihanCategory.generator: return '🔌';
      case BayanihanCategory.fuelPool: return '⛽';
      case BayanihanCategory.charging: return '🔋';
      case BayanihanCategory.businessSos: return '🏪';
    }
  }

  String get categoryLabel {
    switch (category) {
      case BayanihanCategory.generator: return 'Generator Sharing';
      case BayanihanCategory.fuelPool: return 'Fuel Pooling';
      case BayanihanCategory.charging: return 'Charging Spot';
      case BayanihanCategory.businessSos: return 'Business SOS';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    'title': title,
    'description': description,
    'location': location,
    'contactInfo': contactInfo,
    'availability': availability,
    'createdAt': createdAt.toIso8601String(),
    'interestedCount': interestedCount,
    'salamatCount': salamatCount,
  };

  factory BayanihanPost.fromJson(Map<String, dynamic> json) {
    DateTime date;
    if (json['createdAt'] is String) {
      date = DateTime.parse(json['createdAt']);
    } else if (json['createdAt'] is Timestamp) {
      date = (json['createdAt'] as Timestamp).toDate();
    } else {
      date = DateTime.now();
    }

    return BayanihanPost(
      id: json['id'] ?? '',
      category: BayanihanCategory.values.firstWhere((e) => e.name == json['category'], orElse: () => BayanihanCategory.generator),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      location: json['location'],
      contactInfo: json['contactInfo'],
      availability: json['availability'],
      createdAt: date,
      interestedCount: json['interestedCount'] ?? 0,
      salamatCount: json['salamatCount'] ?? 0,
    );
  }
}

enum BayanihanCategory { generator, fuelPool, charging, businessSos }

class FuelLog {
  final String id;
  final DateTime date;
  final String stationName;
  final String fuelType;
  final double liters;
  final double pricePerLiter;

  FuelLog({
    required this.id,
    required this.date,
    required this.stationName,
    required this.fuelType,
    required this.liters,
    required this.pricePerLiter,
  });

  double get totalCost => liters * pricePerLiter;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'stationName': stationName,
    'fuelType': fuelType,
    'liters': liters,
    'pricePerLiter': pricePerLiter,
  };

  factory FuelLog.fromJson(Map<String, dynamic> json) => FuelLog(
    id: json['id'],
    date: DateTime.parse(json['date']),
    stationName: json['stationName'],
    fuelType: json['fuelType'],
    liters: json['liters'].toDouble(),
    pricePerLiter: json['pricePerLiter'].toDouble(),
  );
}

class WatchlistArea {
  final String id;
  final String name;
  final String label;
  final double lat;
  final double lng;

  WatchlistArea({
    required this.id,
    required this.name,
    required this.label,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'label': label,
    'lat': lat,
    'lng': lng,
  };

  factory WatchlistArea.fromJson(Map<String, dynamic> json) => WatchlistArea(
    id: json['id'],
    name: json['name'],
    label: json['label'],
    lat: json['lat'].toDouble(),
    lng: json['lng'].toDouble(),
  );
}

class FuelLog {
  final String id;
  final DateTime date;
  final String stationName;
  final String fuelType;
  final double liters;
  final double pricePerLiter;

  FuelLog({
    required this.id,
    required this.date,
    required this.stationName,
    required this.fuelType,
    required this.liters,
    required this.pricePerLiter,
  });

  double get totalCost => liters * pricePerLiter;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'stationName': stationName,
    'fuelType': fuelType,
    'liters': liters,
    'pricePerLiter': pricePerLiter,
  };

  factory FuelLog.fromJson(Map<String, dynamic> json) => FuelLog(
    id: json['id'],
    date: DateTime.parse(json['date']),
    stationName: json['stationName'],
    fuelType: json['fuelType'],
    liters: json['liters'].toDouble(),
    pricePerLiter: json['pricePerLiter'].toDouble(),
  );
}

class WatchlistArea {
  final String id;
  final String name;
  final String label;
  final double lat;
  final double lng;

  WatchlistArea({
    required this.id,
    required this.name,
    required this.label,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'label': label,
    'lat': lat,
    'lng': lng,
  };

  factory WatchlistArea.fromJson(Map<String, dynamic> json) => WatchlistArea(
    id: json['id'],
    name: json['name'],
    label: json['label'],
    lat: json['lat'].toDouble(),
    lng: json['lng'].toDouble(),
  );
}
