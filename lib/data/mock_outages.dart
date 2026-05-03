import 'package:latlong2/latlong.dart';
import '../models/outage_report.dart';

/// Realistic seed data for brownout reports across Metro Manila and nearby provinces.
/// These match real Meralco service areas and barangay names.
List<OutageReport> getMockOutages() {
  final now = DateTime.now();
  return [
    // --- METRO MANILA ---
    OutageReport(id: 'o1', location: LatLng(14.5547, 121.0244), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 2, minutes: 15)), areaName: 'Makati CBD', barangay: 'Bel-Air', city: 'Makati', reporterCount: 12, isVerified: true),
    OutageReport(id: 'o2', location: LatLng(14.6760, 121.0437), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 1, minutes: 30)), areaName: 'Quezon City', barangay: 'Fairview', city: 'Quezon City', reporterCount: 28, isVerified: true),
    OutageReport(id: 'o3', location: LatLng(14.5896, 120.9811), status: OutageStatus.scheduled, reportedAt: now.subtract(const Duration(hours: 4)), areaName: 'Manila', barangay: 'Ermita', city: 'Manila', reporterCount: 5, notes: 'Scheduled maintenance 9AM-2PM'),
    OutageReport(id: 'o4', location: LatLng(14.5176, 121.0509), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(minutes: 45)), areaName: 'Taguig', barangay: 'Lower Bicutan', city: 'Taguig', reporterCount: 8),
    OutageReport(id: 'o5', location: LatLng(14.4793, 121.0198), status: OutageStatus.restored, reportedAt: now.subtract(const Duration(hours: 6)), restoredAt: now.subtract(const Duration(hours: 2)), areaName: 'Parañaque', barangay: 'BF Homes', city: 'Parañaque', reporterCount: 15, isVerified: true),
    OutageReport(id: 'o6', location: LatLng(14.6507, 121.1049), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 3)), areaName: 'Marikina', barangay: 'Concepcion I', city: 'Marikina', reporterCount: 19, isVerified: true),
    OutageReport(id: 'o7', location: LatLng(14.7500, 121.0500), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 1)), areaName: 'Caloocan', barangay: 'Bagong Silang', city: 'Caloocan', reporterCount: 34, isVerified: true),
    OutageReport(id: 'o8', location: LatLng(14.5311, 121.0192), status: OutageStatus.scheduled, reportedAt: now.subtract(const Duration(hours: 8)), areaName: 'Pasay', barangay: 'Malibay', city: 'Pasay', reporterCount: 3, notes: 'Line maintenance 6AM-12PM'),
    OutageReport(id: 'o9', location: LatLng(14.5764, 121.0851), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(minutes: 20)), areaName: 'Pasig', barangay: 'Ugong', city: 'Pasig', reporterCount: 7),
    OutageReport(id: 'o10', location: LatLng(14.6580, 120.9690), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 2)), areaName: 'Valenzuela', barangay: 'Bignay', city: 'Valenzuela', reporterCount: 11, isVerified: true),
    
    // --- CAVITE ---
    OutageReport(id: 'o11', location: LatLng(14.3294, 120.9367), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 4, minutes: 30)), areaName: 'Dasmariñas', barangay: 'Salawag', city: 'Dasmariñas', reporterCount: 22, isVerified: true),
    OutageReport(id: 'o12', location: LatLng(14.3878, 120.9415), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 1, minutes: 15)), areaName: 'Imus', barangay: 'Alapan II-A', city: 'Imus', reporterCount: 16),
    OutageReport(id: 'o13', location: LatLng(14.2868, 120.8636), status: OutageStatus.scheduled, reportedAt: now.subtract(const Duration(hours: 12)), areaName: 'Gen. Trias', barangay: 'Bacao', city: 'General Trias', reporterCount: 4, notes: 'Transformer upgrade'),
    OutageReport(id: 'o14', location: LatLng(14.4104, 120.9601), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 2, minutes: 45)), areaName: 'Bacoor', barangay: 'Molino', city: 'Bacoor', reporterCount: 25, isVerified: true),

    // --- BULACAN ---
    OutageReport(id: 'o15', location: LatLng(14.7964, 120.8936), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 5)), areaName: 'Meycauayan', barangay: 'Malhacan', city: 'Meycauayan', reporterCount: 13, isVerified: true),
    OutageReport(id: 'o16', location: LatLng(14.8431, 121.0454), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 3, minutes: 20)), areaName: 'San Jose del Monte', barangay: 'Sapang Palay', city: 'San Jose del Monte', reporterCount: 31, isVerified: true),
    OutageReport(id: 'o17', location: LatLng(14.8444, 120.8112), status: OutageStatus.scheduled, reportedAt: now.subtract(const Duration(hours: 10)), areaName: 'Malolos', barangay: 'Guinhawa', city: 'Malolos', reporterCount: 6, notes: 'NGCP maintenance'),

    // --- LAGUNA ---
    OutageReport(id: 'o18', location: LatLng(14.2139, 121.1650), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 2)), areaName: 'Calamba', barangay: 'Canlubang', city: 'Calamba', reporterCount: 9),
    OutageReport(id: 'o19', location: LatLng(14.1714, 121.2414), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 1, minutes: 40)), areaName: 'Los Baños', barangay: 'Batong Malake', city: 'Los Baños', reporterCount: 14, isVerified: true),
    OutageReport(id: 'o20', location: LatLng(14.2812, 121.0768), status: OutageStatus.restored, reportedAt: now.subtract(const Duration(hours: 8)), restoredAt: now.subtract(const Duration(hours: 3)), areaName: 'Sta. Rosa', barangay: 'Balibago', city: 'Sta. Rosa', reporterCount: 10, isVerified: true),

    // --- RIZAL ---
    OutageReport(id: 'o21', location: LatLng(14.5867, 121.1761), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 3, minutes: 10)), areaName: 'Antipolo', barangay: 'Dela Paz', city: 'Antipolo', reporterCount: 17, isVerified: true),
    OutageReport(id: 'o22', location: LatLng(14.6879, 121.1242), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 1, minutes: 50)), areaName: 'San Mateo', barangay: 'Guitnang Bayan', city: 'San Mateo', reporterCount: 8),

    // --- MORE METRO MANILA ---
    OutageReport(id: 'o23', location: LatLng(14.5547, 120.9981), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(minutes: 55)), areaName: 'Manila', barangay: 'Sta. Ana', city: 'Manila', reporterCount: 6),
    OutageReport(id: 'o24', location: LatLng(14.6091, 121.0223), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 4, minutes: 10)), areaName: 'Mandaluyong', barangay: 'Highway Hills', city: 'Mandaluyong', reporterCount: 9, isVerified: true),
    OutageReport(id: 'o25', location: LatLng(14.5965, 120.9445), status: OutageStatus.scheduled, reportedAt: now.subtract(const Duration(hours: 6)), areaName: 'Manila', barangay: 'Tondo', city: 'Manila', reporterCount: 2, notes: 'Cable replacement 8AM-4PM'),
    OutageReport(id: 'o26', location: LatLng(14.4545, 120.9932), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 1, minutes: 10)), areaName: 'Las Piñas', barangay: 'Pamplona Tres', city: 'Las Piñas', reporterCount: 12),
    OutageReport(id: 'o27', location: LatLng(14.4292, 120.9616), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 2, minutes: 30)), areaName: 'Muntinlupa', barangay: 'Putatan', city: 'Muntinlupa', reporterCount: 7),
    OutageReport(id: 'o28', location: LatLng(14.6329, 121.0327), status: OutageStatus.restored, reportedAt: now.subtract(const Duration(hours: 5)), restoredAt: now.subtract(const Duration(hours: 1)), areaName: 'Quezon City', barangay: 'Teachers Village', city: 'Quezon City', reporterCount: 4, isVerified: true),
    OutageReport(id: 'o29', location: LatLng(14.7128, 121.0786), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(minutes: 30)), areaName: 'Quezon City', barangay: 'Batasan Hills', city: 'Quezon City', reporterCount: 21, isVerified: true),
    OutageReport(id: 'o30', location: LatLng(14.5378, 121.0014), status: OutageStatus.nopower, reportedAt: now.subtract(const Duration(hours: 3, minutes: 45)), areaName: 'Pasay', barangay: 'Baclaran', city: 'Pasay', reporterCount: 14, isVerified: true),
  ];
}
