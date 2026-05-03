import 'package:latlong2/latlong.dart';
import '../models/fuel_station.dart';

/// Real gas station brands and locations across Metro Manila.
/// Coordinates are approximate but placed in correct areas.
List<FuelStation> getMockStations() {
  final now = DateTime.now();
  return [
    // --- SHELL ---
    FuelStation(id: 'fs1', brand: 'Shell', name: 'Shell EDSA-Balintawak', address: 'EDSA cor. Balintawak, Quezon City', location: LatLng(14.6573, 121.0038), status: StationStatus.open, priceUnleaded: 65.45, priceDiesel: 58.20, pricePremium: 72.95, queueTime: QueueTime.short5min, lastUpdated: now.subtract(const Duration(minutes: 30))),
    FuelStation(id: 'fs2', brand: 'Shell', name: 'Shell Makati Ave', address: 'Makati Avenue, Makati City', location: LatLng(14.5563, 121.0213), status: StationStatus.open, priceUnleaded: 66.10, priceDiesel: 58.85, pricePremium: 73.50, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 1))),
    FuelStation(id: 'fs3', brand: 'Shell', name: 'Shell Taft Avenue', address: 'Taft Avenue, Pasay City', location: LatLng(14.5381, 120.9943), status: StationStatus.limited, priceUnleaded: 65.45, priceDiesel: null, pricePremium: 72.95, queueTime: QueueTime.medium30min, lastUpdated: now.subtract(const Duration(hours: 2)), notes: 'Diesel out of stock'),
    FuelStation(id: 'fs4', brand: 'Shell', name: 'Shell C5-Taguig', address: 'C5 Road, Taguig City', location: LatLng(14.5207, 121.0563), status: StationStatus.open, priceUnleaded: 65.45, priceDiesel: 58.20, pricePremium: 72.95, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 3))),

    // --- PETRON ---
    FuelStation(id: 'fs5', brand: 'Petron', name: 'Petron EDSA-Cubao', address: 'EDSA, Cubao, Quezon City', location: LatLng(14.6195, 121.0555), status: StationStatus.open, priceUnleaded: 64.85, priceDiesel: 57.60, pricePremium: 72.35, queueTime: QueueTime.short5min, lastUpdated: now.subtract(const Duration(minutes: 45))),
    FuelStation(id: 'fs6', brand: 'Petron', name: 'Petron Alabang', address: 'Alabang-Zapote Road, Muntinlupa', location: LatLng(14.4201, 121.0249), status: StationStatus.open, priceUnleaded: 64.85, priceDiesel: 57.60, pricePremium: 72.35, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 1, minutes: 30))),
    FuelStation(id: 'fs7', brand: 'Petron', name: 'Petron Commonwealth', address: 'Commonwealth Avenue, Quezon City', location: LatLng(14.6824, 121.0770), status: StationStatus.closed, priceUnleaded: null, priceDiesel: null, pricePremium: null, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 5)), notes: 'Temporarily closed - no supply'),
    FuelStation(id: 'fs8', brand: 'Petron', name: 'Petron Dasmariñas', address: 'Aguinaldo Highway, Dasmariñas, Cavite', location: LatLng(14.3281, 120.9407), status: StationStatus.open, priceUnleaded: 64.50, priceDiesel: 57.20, pricePremium: 71.85, queueTime: QueueTime.long1hr, lastUpdated: now.subtract(const Duration(hours: 2))),

    // --- CALTEX ---
    FuelStation(id: 'fs9', brand: 'Caltex', name: 'Caltex SLEX-Sucat', address: 'SLEX Service Road, Sucat, Parañaque', location: LatLng(14.4612, 121.0297), status: StationStatus.open, priceUnleaded: 65.20, priceDiesel: 58.05, pricePremium: 73.10, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 1))),
    FuelStation(id: 'fs10', brand: 'Caltex', name: 'Caltex Ortigas', address: 'Ortigas Avenue, Pasig City', location: LatLng(14.5840, 121.0615), status: StationStatus.open, priceUnleaded: 65.20, priceDiesel: 58.05, pricePremium: 73.10, queueTime: QueueTime.short5min, lastUpdated: now.subtract(const Duration(minutes: 50))),
    FuelStation(id: 'fs11', brand: 'Caltex', name: 'Caltex Imus', address: 'Aguinaldo Highway, Imus, Cavite', location: LatLng(14.4017, 120.9360), status: StationStatus.limited, priceUnleaded: 65.20, priceDiesel: 58.05, pricePremium: null, queueTime: QueueTime.medium30min, lastUpdated: now.subtract(const Duration(hours: 3)), notes: 'Premium unavailable'),

    // --- PHOENIX ---
    FuelStation(id: 'fs12', brand: 'Phoenix', name: 'Phoenix Quezon Ave', address: 'Quezon Avenue, Quezon City', location: LatLng(14.6334, 121.0184), status: StationStatus.open, priceUnleaded: 63.95, priceDiesel: 56.80, pricePremium: 70.95, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 1, minutes: 20))),
    FuelStation(id: 'fs13', brand: 'Phoenix', name: 'Phoenix Mandaluyong', address: 'Shaw Blvd, Mandaluyong City', location: LatLng(14.5797, 121.0488), status: StationStatus.open, priceUnleaded: 63.95, priceDiesel: 56.80, pricePremium: 70.95, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 2))),
    FuelStation(id: 'fs14', brand: 'Phoenix', name: 'Phoenix Bacoor', address: 'Molino Blvd, Bacoor, Cavite', location: LatLng(14.4152, 120.9573), status: StationStatus.closed, priceUnleaded: null, priceDiesel: null, pricePremium: null, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 8)), notes: 'No power - brownout area'),

    // --- SEAOIL ---
    FuelStation(id: 'fs15', brand: 'Seaoil', name: 'Seaoil Marcos Highway', address: 'Marcos Highway, Marikina City', location: LatLng(14.6343, 121.1083), status: StationStatus.open, priceUnleaded: 63.50, priceDiesel: 56.40, pricePremium: 70.50, queueTime: QueueTime.short5min, lastUpdated: now.subtract(const Duration(hours: 1))),
    FuelStation(id: 'fs16', brand: 'Seaoil', name: 'Seaoil Antipolo', address: 'Sumulong Highway, Antipolo City', location: LatLng(14.5924, 121.1649), status: StationStatus.open, priceUnleaded: 63.50, priceDiesel: 56.40, pricePremium: 70.50, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 2, minutes: 30))),

    // --- UNIOIL ---
    FuelStation(id: 'fs17', brand: 'Unioil', name: 'Unioil BGC', address: 'Bonifacio Global City, Taguig', location: LatLng(14.5506, 121.0494), status: StationStatus.open, priceUnleaded: 64.10, priceDiesel: 57.00, pricePremium: 71.50, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(minutes: 40))),
    FuelStation(id: 'fs18', brand: 'Unioil', name: 'Unioil Calamba', address: 'National Highway, Calamba, Laguna', location: LatLng(14.2115, 121.1588), status: StationStatus.open, priceUnleaded: 63.80, priceDiesel: 56.70, pricePremium: 71.20, queueTime: QueueTime.short5min, lastUpdated: now.subtract(const Duration(hours: 3))),

    // --- JETTI ---
    FuelStation(id: 'fs19', brand: 'Jetti', name: 'Jetti Novaliches', address: 'Quirino Highway, Novaliches, QC', location: LatLng(14.7102, 121.0382), status: StationStatus.open, priceUnleaded: 63.40, priceDiesel: 56.30, pricePremium: null, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 4))),
    FuelStation(id: 'fs20', brand: 'Jetti', name: 'Jetti San Pedro', address: 'National Highway, San Pedro, Laguna', location: LatLng(14.3519, 121.0487), status: StationStatus.limited, priceUnleaded: 63.40, priceDiesel: null, pricePremium: null, queueTime: QueueTime.medium30min, lastUpdated: now.subtract(const Duration(hours: 2)), notes: 'Unleaded only'),

    // --- TOTAL ---
    FuelStation(id: 'fs21', brand: 'Total', name: 'Total Pasig', address: 'C. Raymundo Ave, Pasig City', location: LatLng(14.5757, 121.0782), status: StationStatus.open, priceUnleaded: 65.00, priceDiesel: 57.80, pricePremium: 72.80, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 1, minutes: 15))),
    FuelStation(id: 'fs22', brand: 'Total', name: 'Total Las Piñas', address: 'Alabang-Zapote Road, Las Piñas', location: LatLng(14.4474, 120.9938), status: StationStatus.open, priceUnleaded: 65.00, priceDiesel: 57.80, pricePremium: 72.80, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 2))),

    // --- CLEANFUEL ---
    FuelStation(id: 'fs23', brand: 'Cleanfuel', name: 'Cleanfuel Cainta', address: 'Ortigas Avenue Ext, Cainta, Rizal', location: LatLng(14.5748, 121.1219), status: StationStatus.open, priceUnleaded: 62.95, priceDiesel: 55.80, pricePremium: null, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 3))),
    FuelStation(id: 'fs24', brand: 'Cleanfuel', name: 'Cleanfuel Marilao', address: 'MacArthur Highway, Marilao, Bulacan', location: LatLng(14.7586, 120.9476), status: StationStatus.closed, priceUnleaded: null, priceDiesel: null, pricePremium: null, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 6)), notes: 'Closed - awaiting fuel delivery'),

    // --- MORE ---
    FuelStation(id: 'fs25', brand: 'Shell', name: 'Shell Sta. Rosa', address: 'National Highway, Sta. Rosa, Laguna', location: LatLng(14.3041, 121.1127), status: StationStatus.open, priceUnleaded: 65.45, priceDiesel: 58.20, pricePremium: 72.95, queueTime: QueueTime.short5min, lastUpdated: now.subtract(const Duration(hours: 1))),
    FuelStation(id: 'fs26', brand: 'Petron', name: 'Petron Meycauayan', address: 'MacArthur Highway, Meycauayan, Bulacan', location: LatLng(14.7370, 120.9582), status: StationStatus.open, priceUnleaded: 64.50, priceDiesel: 57.20, pricePremium: 71.85, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 4))),
    FuelStation(id: 'fs27', brand: 'Caltex', name: 'Caltex Taytay', address: 'Manila East Road, Taytay, Rizal', location: LatLng(14.5556, 121.1313), status: StationStatus.open, priceUnleaded: 65.20, priceDiesel: 58.05, pricePremium: 73.10, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 2))),
    FuelStation(id: 'fs28', brand: 'Phoenix', name: 'Phoenix Malolos', address: 'MacArthur Highway, Malolos, Bulacan', location: LatLng(14.8422, 120.8117), status: StationStatus.limited, priceUnleaded: 63.95, priceDiesel: 56.80, pricePremium: null, queueTime: QueueTime.long1hr, lastUpdated: now.subtract(const Duration(hours: 3)), notes: 'Long queue - limited stock'),
    FuelStation(id: 'fs29', brand: 'Shell', name: 'Shell Gen. Trias', address: 'Arnaldo Highway, General Trias, Cavite', location: LatLng(14.3097, 120.8795), status: StationStatus.open, priceUnleaded: 65.45, priceDiesel: 58.20, pricePremium: 72.95, queueTime: QueueTime.short5min, lastUpdated: now.subtract(const Duration(hours: 1, minutes: 45))),
    FuelStation(id: 'fs30', brand: 'Petron', name: 'Petron San Pablo', address: 'Maharlika Highway, San Pablo, Laguna', location: LatLng(14.0711, 121.3224), status: StationStatus.open, priceUnleaded: 64.50, priceDiesel: 57.20, pricePremium: 71.85, queueTime: QueueTime.none, lastUpdated: now.subtract(const Duration(hours: 5))),
  ];
}
