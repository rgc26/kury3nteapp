import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/outage_report.dart';
import '../models/trust_system.dart';
import '../models/meralco_schedule.dart';
import '../models/fuel_station.dart';
import '../models/app_models.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  
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

    // Award points for fuel update
    await incrementUserPoints(15);
  }

  /// Listen to current user profile data (Points, Photo, etc)
  Stream<Map<String, dynamic>> getUserProfileStream() {
    final uid = currentUser?.uid;
    if (uid == null) return Stream.value({});
    
    return _db.collection('users').doc(uid).snapshots().map((doc) => doc.data() ?? {});
  }

  /// Uploads an image to Cloudinary (Alternative to Firebase Storage)
  /// Requires Cloudinary Cloud Name and Unsigned Upload Preset
  Future<String?> uploadToCloudinary(Uint8List bytes) async {
    const cloudName = 'dm7x0aibx'; 
    const uploadPreset = 'ml_default'; 

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'profile.jpg'));

    final response = await request.send();
    if (response.statusCode == 200) {
      final resData = await response.stream.bytesToString();
      final json = jsonDecode(resData);
      final url = json['secure_url'] as String;
      
      // Update Firestore profile
      final uid = currentUser?.uid;
      if (uid != null) {
        await _db.collection('users').doc(uid).set({
          'photoUrl': url,
        }, SetOptions(merge: true));
        
        // Also update Firebase Auth profile for consistency
        await currentUser?.updatePhotoURL(url);
      }
      return url;
    }
    return null;
  }

  /// Listen to current user points for gamification (Bayanihan Points)
  Stream<int> getUserPointsStream() {
    final uid = currentUser?.uid;
    if (uid == null) return Stream.value(0);
    
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      return doc.data()?['points'] ?? 0;
    });
  }

  /// Award points to a user for helpful reports
  Future<void> incrementUserPoints(int amount) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    
    await _db.collection('users').doc(uid).set({
      'points': FieldValue.increment(amount),
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Hardcoding a mock trust level for demo purposes.
  // In a real app, this would be fetched from a 'users' collection.
  UserTrust get currentUserTrust {
    return UserTrust(
      userId: currentUser?.uid ?? 'unknown',
      confirmedReports: 5, // verified level by default for demo
    );
  }

  /// Listen to live Bayanihan community posts
  Stream<List<BayanihanPost>> getBayanihanPostsStream() {
    return _db.collection('bayanihan')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return BayanihanPost.fromJson({...data, 'id': doc.id});
        }).toList();
      });
  }

  /// Submit a new Bayanihan community post
  Future<void> submitBayanihanPost(BayanihanPost post) async {
    final user = currentUser;
    if (user == null) return;
    
    final data = post.toJson();
    data['authorName'] = user.displayName ?? 'Bayani';
    data['authorId'] = user.uid;
    data['createdAt'] = FieldValue.serverTimestamp(); // Use server time for consistency

    await _db.collection('bayanihan').add(data);
    await incrementUserPoints(20); // Higher points for community help posts
  }

  /// React to a Bayanihan post (Interested/Salamat)
  Future<void> reactToBayanihanPost(String postId, String type) async {
    final field = type == 'interested' ? 'interestedCount' : 'salamatCount';
    await _db.collection('bayanihan').doc(postId).update({
      field: FieldValue.increment(1),
    });
  }

  Future<void> init() async {
    // Request notification permissions for PWA
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ User granted notification permission');
        // Subscribe to global topics for community alerts
        await _fcm.subscribeToTopic('outages');
        await _fcm.subscribeToTopic('fuel');
      }
    } catch (e) {
      debugPrint('⚠️ FCM Init Error: $e');
    }
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

  /// Listen to active outages (Community: Since Midnight Today | Official: Always)
  Stream<List<OutageReport>> getOutagesStream() {
    // Rule: Community reports clear at midnight for a fresh start each day
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    
    debugPrint('📡 Fetching active outages since midnight: $startOfToday');
    
    return _db.collection('outages')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          try {
            final data = doc.data();
            data['id'] = doc.id;
            return OutageReport.fromJson(data);
          } catch (e) {
            debugPrint('⚠️ Error parsing report: $e');
            return null;
          }
        })
        .whereType<OutageReport>()
        .where((report) {
          // Rule: Show if it's an Official Scheduled advisory OR it's a community report from TODAY
          if (report.status == OutageStatus.scheduled) return true;
          return report.reportedAt.isAfter(startOfToday);
        }).toList();
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
            debugPrint('History Stream error parsing document ${doc.id}: $e');
            return null;
          }
        })
        .whereType<OutageReport>()
        .toList();
      });
  }

  /// Submit a new brownout report
  Future<void> submitReport(OutageReport report) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Please login first.');

    // Prevention: Check if user already reported TODAY
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    
    final reportsToday = await _db.collection('outages')
      .where('reportedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
      .get();

    final alreadyReported = reportsToday.docs.any((doc) {
      final reporters = List<String>.from(doc.data()['reporters'] ?? []);
      return reporters.contains(uid);
    });

    if (alreadyReported) {
      throw Exception('May report ka na para sa araw na ito! ⚡ Isang report lang per day per user para maiwasan ang spam.');
    }
    
    try {
      final docRef = _db.collection('outages').doc();
      final userWeight = currentUserTrust.voteWeight;
      
      OutageStatus initialStatus = OutageStatus.unverified;
      if (userWeight >= 3) {
        initialStatus = OutageStatus.nopower; // Trusted users auto-verify
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
        'isVerified': userWeight >= 3,
        'reporters': [uid],
        'restorers': [],
      };
      
      await docRef.set(data);
    
      // Award points for community report
      await incrementUserPoints(10);
    } catch (e) {
      throw Exception('Failed to save report: $e');
    }
  }

  /// Add user to an existing report (Me Too logic) with verification check
  Future<void> upvoteReport(String reportId) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    
    final docRef = _db.collection('outages').doc(reportId);
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      
      final reporters = List<String>.from(snapshot.data()?['reporters'] ?? []);
      if (reporters.contains(uid)) return; // Already reported
      
      final currentUpvotes = snapshot.data()?['upvotes'] ?? 0;
      final userWeight = currentUserTrust.voteWeight;
      final newUpvotes = currentUpvotes + userWeight;
      
      // Auto-verify threshold = 3
      final bool shouldVerify = newUpvotes >= 3;
      
      transaction.update(docRef, {
        'reporters': FieldValue.arrayUnion([uid]),
        'upvotes': newUpvotes,
        'status': shouldVerify ? OutageStatus.nopower.name : snapshot.data()?['status'],
        'isVerified': shouldVerify,
      });
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
