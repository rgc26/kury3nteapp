import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import '../models/outage_report.dart';
import '../models/trust_system.dart';
import '../models/meralco_schedule.dart';
import '../models/fuel_station.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  User? get currentUser => _auth.currentUser;
  
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ... (previous trust logic)

  /// Listen to Fuel Stations and their community-reported status
  Stream<List<FuelStation>> getFuelStationsStream() {
    return _db.collection('fuel_stations')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          return FuelStation.fromJson(doc.data(), doc.id);
        }).toList();
      });
  }

  /// Submit a fuel station report (status, prices, queue)
  Future<void> reportFuelStation(String stationId, StationStatus status, Map<String, double> prices) async {
    final user = currentUser;
    if (user == null) return;
    
    // Use displayName if available, otherwise a friendly fallback
    final name = user.displayName ?? 'Bayani ${user.uid.substring(0, 4)}';

    final docRef = _db.collection('fuel_stations').doc(stationId);
    
    await docRef.set({
      'status': status.name,
      'prices': prices,
      'lastUpdated': FieldValue.serverTimestamp(),
      'reportedBy': name,
      'reporters': FieldValue.arrayUnion([user.uid]),
      'reportCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  // Hardcoding a mock trust level for demo purposes.
  // In a real app, this would be fetched from a 'users' collection.
  UserTrust get currentUserTrust {
    return UserTrust(
      userId: currentUser?.uid ?? 'unknown',
      confirmedReports: 5, // Make them verified level by default for demo
    );
  }

  Future<void> init() async {
    // No longer signing in anonymously automatically
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Use the built-in Firebase Auth provider for Web which handles popups perfectly
      GoogleAuthProvider authProvider = GoogleAuthProvider();
      return await _auth.signInWithPopup(authProvider);
    } catch (e) {
      print('Google Sign-In Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Ensures this device is only used by one unique account
  Future<void> registerDevice(String deviceId) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    final docRef = _db.collection('device_locks').doc(deviceId);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      final ownerUid = snapshot.data()?['ownerUid'];
      if (ownerUid != uid) {
        // Force logout if device is locked to another UID
        await signOut();
        throw Exception('ACCOUNT LOCK: This device is already registered to a different user. To protect the community from map spamming, we only allow one account per device.');
      }
    } else {
      // First time using this device, lock it to this UID
      await docRef.set({
        'ownerUid': uid,
        'linkedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Listen to active outages (Community: last 24h | Official: Always)
  Stream<List<OutageReport>> getOutagesStream() {
    final limitDate = DateTime.now().subtract(const Duration(hours: 24));
    print('DEBUG: Fetching outages since $limitDate');
    
    return _db.collection('outages')
      .snapshots()
      .map((snapshot) {
        print('DEBUG: Received snapshot with ${snapshot.docs.length} documents');
        final reports = snapshot.docs.map((doc) {
          try {
            final data = doc.data();
            data['id'] = doc.id;
            final report = OutageReport.fromJson(data);
            
            // Log each report for debugging
            print('DEBUG: Found report ${report.id} at ${report.location.latitude}, ${report.location.longitude}, status: ${report.status.name}, reportedAt: ${report.reportedAt}');
            
            return report;
          } catch (e) {
            print('DEBUG: Stream error parsing document ${doc.id}: $e');
            return null;
          }
        })
        .whereType<OutageReport>()
        .where((report) {
          // Rule: Show if it's an Official Scheduled advisory OR it's a recent community report
          if (report.status == OutageStatus.scheduled) return true;
          return report.reportedAt.isAfter(limitDate);
        }).toList();
        
        return reports;
      });
  }

  /// Listen to ALL historical outages (No time limit)
  Stream<List<OutageReport>> getOutageHistoryStream() {
    return _db.collection('outages')
      .orderBy('reportedAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          try {
            final data = doc.data();
            data['id'] = doc.id;
            return OutageReport.fromJson(data);
          } catch (e) {
            print('History Stream error parsing document ${doc.id}: $e');
            return null;
          }
        })
        .whereType<OutageReport>()
        .toList();
      });
  }

  /// Submit a new brownout report (Direct Write Version for Reliability)
  Future<void> submitReport(OutageReport report) async {
    final uid = currentUser?.uid;
    if (uid == null) {
      throw Exception('Hindi ka naka-login. Please sign in muna.');
    }

    // Check if the user already has an active report at this general location
    // (This prevents accidental double-reporting while we have clustering disabled)
    
    try {
      final docRef = _db.collection('outages').doc();
      final userWeight = currentUserTrust.voteWeight;
      
      OutageStatus initialStatus = OutageStatus.unverified;
      if (userWeight >= 3) {
        initialStatus = OutageStatus.nopower;
      }
      
      final data = {
        'id': docRef.id,
        'lat': report.location.latitude,
        'lng': report.location.longitude,
        'status': initialStatus.name,
        'source': 'crowdsource',
        'reportedAt': FieldValue.serverTimestamp(),
        'areaName': report.areaName ?? 'Unknown Location',
        'barangay': report.barangay,
        'notes': report.notes,
        'upvotes': userWeight,
        'restoredVotes': 0,
        'isVerified': false,
        'reporters': [uid],
        'restorers': [],
      };
      
      await docRef.set(data);
    } catch (e) {
      throw Exception('Failed to save report: $e');
    }
  }

  /// Add user to an existing report's reporters list (Me Too logic)
  Future<void> upvoteReport(String reportId) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    
    final docRef = _db.collection('outages').doc(reportId);
    await docRef.update({
      'reporters': FieldValue.arrayUnion([uid]),
      'upvotes': FieldValue.increment(1),
    });
  }

  /// User taps "Kuryente Na!"
  Future<void> markRestored(String reportId) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    
    final docRef = _db.collection('outages').doc(reportId);
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      
      final restorers = List<String>.from(snapshot.data()?['restorers'] ?? []);
      if (restorers.contains(uid)) return; // Already voted
      
      final currentVotes = snapshot.data()?['restoredVotes'] ?? 0;
      final userWeight = currentUserTrust.voteWeight;
      final newVotes = currentVotes + userWeight;
      
      if (newVotes >= 2) {
        // 2+ votes to confirm restoration
        transaction.update(docRef, {
          'status': OutageStatus.restored.name,
          'restoredAt': DateTime.now().toIso8601String(),
          'restoredVotes': newVotes,
          'restorers': FieldValue.arrayUnion([uid]),
        });
      } else {
        transaction.update(docRef, {
          'restoredVotes': newVotes,
          'restorers': FieldValue.arrayUnion([uid]),
        });
      }
    });
  }

  /// Reverse geocodes coordinates to a Barangay name using Nominatim API
  Future<String?> reverseGeocode(LatLng loc) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${loc.latitude}&lon=${loc.longitude}&zoom=18&addressdetails=1');
      final response = await http.get(url, headers: {
        'User-Agent': 'Kury3nteApp/1.0',
      });
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['address'] != null) {
          final address = data['address'];
          // Look for common keys that represent a barangay/village
          return address['village'] ?? address['suburb'] ?? address['quarter'] ?? address['neighbourhood'] ?? address['city'] ?? 'Unknown';
        }
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return null;
  }

  /// Search for a location by name (Forward Geocoding)
  Future<LatLng?> forwardGeocode(String query) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=1');
      final response = await http.get(url, headers: {'User-Agent': 'KuryenteApp/1.0'});
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
        }
      }
    } catch (e) {
      print('Forward Geocode Error: $e');
    }
    return null;
  }

  /// Sync Meralco maintenance schedules to Firestore as official pins
  Future<int> syncOfficialSchedules(List<MeralcoSchedule> schedules) async {
    int syncedCount = 0;
    for (var s in schedules) {
      final areaName = 'OFFICIAL: ${s.location}';
      
      try {
        final existing = await _db.collection('outages')
          .where('areaName', isEqualTo: areaName)
          .where('status', isEqualTo: OutageStatus.scheduled.name)
          .get();
          
        if (existing.docs.isEmpty) {
          // Clean query: "Manila (Sta. Ana)" -> "Sta. Ana, Manila"
          String query = s.location;
          if (query.contains('(') && query.contains(')')) {
             final match = RegExp(r'(.+?)\s*\((.+?)\)').firstMatch(query);
             if (match != null) {
               query = '${match.group(2)}, ${match.group(1)}';
             }
          }
          
          // Fallback coordinates for demo data if geocoding fails
          LatLng? loc = await forwardGeocode('$query, Philippines');
          
          if (loc == null) {
            // Hardcoded coordinates for the 2 demo locations if geocoding fails on web
            if (s.location.contains('Manila')) loc = const LatLng(14.5833, 120.9842);
            if (s.location.contains('Laguna')) loc = const LatLng(14.2137, 121.1633);
          }
          
          if (loc != null) {
            final r = OutageReport(
              id: '', 
              location: loc, 
              status: OutageStatus.scheduled, 
              reportedAt: DateTime.now(), 
              areaName: areaName, 
              barangay: s.location,
              notes: 'TIME: ${s.timeRange}\nREASON: ${s.reason}',
            );
            await _db.collection('outages').add(r.toJson());
            syncedCount++;
          }
        }
      } catch (e) {
        print('Error syncing schedule ${s.location}: $e');
      }
    }
    return syncedCount;
  }
}
