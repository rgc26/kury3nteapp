import 'package:latlong2/latlong.dart';
import '../models/fuel_station.dart';

/// Refactored mock gas stations to match the updated FuelStation model.
List<FuelStation> getMockStations() {
  final now = DateTime.now();
  return [
    FuelStation(
      id: 'fs1', 
      brand: 'Shell', 
      name: 'Shell EDSA-Balintawak', 
      address: 'EDSA cor. Balintawak, Quezon City', 
      location: LatLng(14.6573, 121.0038), 
      status: StationStatus.openHasStock, 
      prices: {'Unleaded 91': 65.45, 'Diesel': 58.20, 'Premium 95': 72.95}, 
      lastUpdated: now.subtract(const Duration(minutes: 30))
    ),
    FuelStation(
      id: 'fs5', 
      brand: 'Petron', 
      name: 'Petron EDSA-Cubao', 
      address: 'EDSA, Cubao, Quezon City', 
      location: LatLng(14.6195, 121.0555), 
      status: StationStatus.longQueue, 
      prices: {'Unleaded 91': 64.85, 'Diesel': 57.60, 'Premium 95': 72.35}, 
      lastUpdated: now.subtract(const Duration(minutes: 45))
    ),
  ];
}
