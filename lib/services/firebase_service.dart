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

  // --- Trust & Points System ---

  UserTrust get currentUserTrust {
    return UserTrust(
      userId: currentUser?.uid ?? 'unknown',
      confirmedReports: 5, // Default for demo, should be fetched from Firestore in production
    );
  }

  Stream<int> getUserPointsStream() {
    final uid = currentUser?.uid;
    if (uid == null) return Stream.value(0);
    return _db.collection('users').doc(uid).snapshots().map((doc) => doc.data()?['points'] ?? 0);
  }

  Future<void> incrementUserPoints(int amount) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'points': FieldValue.increment(amount),
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // --- Auth & Profile ---

  Future<UserCredential?> signInWithGoogle() async {
    try {
      GoogleAuthProvider authProvider = GoogleAuthProvider();
      return await _auth.signInWithPopup(authProvider);
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<Map<String, dynamic>> getUserProfileStream() {
    final uid = currentUser?.uid;
    if (uid == null) return Stream.value({});
    return _db.collection('users').doc(uid).snapshots().map((doc) => doc.data() ?? {});
  }

  Future<String?> uploadToCloudinary(Uint8List bytes) async {
    try {
      const cloudName = 'dm7x0aibx'; 
      const uploadPreset = 'ml_default'; 
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'profile.jpg'));

      final response = await request.send();
      final resData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final json = jsonDecode(resData);
        final url = json['secure_url'] as String;
        final uid = currentUser?.uid;
        if (uid != null) {
          await _db.collection('users').doc(uid).set({'photoUrl': url}, SetOptions(merge: true));
          await currentUser?.updatePhotoURL(url);
        }
        return url;
      }
      return null;
    } catch (e) {
      debugPrint('Cloudinary Error: $e');
      return null;
    }
  }

  // --- Outages & Reports ---

  Stream<List<OutageReport>> getOutagesStream() {
    final startOfToday = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _db.collection('outages').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          return OutageReport.fromJson(data);
        } catch (e) { return null; }
      })
      .whereType<OutageReport>()
      .where((report) {
        if (report.status == OutageStatus.scheduled) return true;
        return report.reportedAt.isAfter(startOfToday);
      }).toList();
    });
  }

  Stream<List<OutageReport>> getOutageHistoryStream() {
    return _db.collection('outages')
      .orderBy('reportedAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return OutageReport.fromJson(data);
        }).toList();
      });
  }

  Future<void> submitReport(OutageReport report) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    final docRef = _db.collection('outages').doc();
    final userWeight = currentUserTrust.voteWeight;
    final initialStatus = userWeight >= 3 ? OutageStatus.nopower : OutageStatus.unverified;
    
    await docRef.set({
      'id': docRef.id,
      'lat': report.location.latitude,
      'lng': report.location.longitude,
      'status': initialStatus.name,
      'reportedAt': FieldValue.serverTimestamp(),
      'areaName': report.areaName ?? 'Unknown Location',
      'barangay': report.barangay,
      'notes': report.notes,
      'upvotes': userWeight,
      'reporters': [uid],
      'isVerified': userWeight >= 3,
    });
    await incrementUserPoints(10);
  }

  Future<void> upvoteReport(String reportId) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    final docRef = _db.collection('outages').doc(reportId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;
      final reporters = List<String>.from(snap.data()?['reporters'] ?? []);
      if (reporters.contains(uid)) return;
      final newUpvotes = (snap.data()?['upvotes'] ?? 0) + currentUserTrust.voteWeight;
      tx.update(docRef, {
        'reporters': FieldValue.arrayUnion([uid]),
        'upvotes': newUpvotes,
        'isVerified': newUpvotes >= 3,
        'status': newUpvotes >= 3 ? OutageStatus.nopower.name : snap.data()?['status'],
      });
    });
  }

  Future<void> markRestored(String reportId) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    final docRef = _db.collection('outages').doc(reportId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;
      final restorers = List<String>.from(snap.data()?['restorers'] ?? []);
      if (restorers.contains(uid)) return;
      final newVotes = (snap.data()?['restoredVotes'] ?? 0) + currentUserTrust.voteWeight;
      tx.update(docRef, {
        'restorers': FieldValue.arrayUnion([uid]),
        'restoredVotes': newVotes,
        'status': newVotes >= 2 ? OutageStatus.restored.name : snap.data()?['status'],
      });
    });
  }

  Future<List<OutageReport>> fetchActiveReports() async {
    final limitDate = DateTime.now().subtract(const Duration(hours: 24));
    final snap = await _db.collection('outages').get();
    return snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return OutageReport.fromJson(data);
    }).where((r) => r.reportedAt.isAfter(limitDate) || r.status == OutageStatus.scheduled).toList();
  }

  // --- Bayanihan Community ---

  Stream<List<BayanihanPost>> getBayanihanPostsStream() {
    return _db.collection('bayanihan').orderBy('createdAt', descending: true).snapshots().map((snap) {
      return snap.docs.map((doc) => BayanihanPost.fromJson({...doc.data(), 'id': doc.id})).toList();
    });
  }

  Future<void> submitBayanihanPost(BayanihanPost post) async {
    final user = currentUser;
    if (user == null) return;
    final data = post.toJson();
    data['authorName'] = user.displayName ?? 'Bayani';
    data['authorId'] = user.uid;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['interestedUserIds'] = [];
    data['salamatUserIds'] = [];
    data['commentCount'] = 0;
    await _db.collection('bayanihan').add(data);
    await incrementUserPoints(20);
  }

  Future<void> reactToBayanihanPost(BayanihanPost post, String type) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    final field = type == 'interested' ? 'interestedUserIds' : 'salamatUserIds';
    final docRef = _db.collection('bayanihan').doc(post.id);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;

      final existingIds = List<String>.from(snap.data()?[field] ?? []);
      if (existingIds.contains(uid)) {
        tx.update(docRef, {field: FieldValue.arrayRemove([uid])});
      } else {
        tx.update(docRef, {field: FieldValue.arrayUnion([uid])});
        if (post.authorId != uid) {
          await sendNotification(
            recipientId: post.authorId,
            type: type,
            title: type == 'interested' ? 'Interested in your post!' : 'Someone said Salamat!',
            message: '${currentUser?.displayName ?? "Someone"} reacted to your post: "${post.title}"',
            relatedId: post.id,
          );
        }
      }
    });
  }

  Future<void> addCommentToPost(BayanihanPost post, String content) async {
    final user = currentUser;
    if (user == null) return;

    final docRef = _db.collection('bayanihan').doc(post.id);
    final commentRef = docRef.collection('comments').doc();

    await _db.runTransaction((tx) async {
      tx.set(commentRef, {
        'authorId': user.uid,
        'authorName': user.displayName ?? 'Bayani',
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(docRef, {'commentCount': FieldValue.increment(1)});
    });

    if (post.authorId != user.uid) {
      await sendNotification(
        recipientId: post.authorId,
        type: 'comment',
        title: 'New Comment!',
        message: '${user.displayName ?? "Someone"} commented on your post: "${post.title}"',
        relatedId: post.id,
      );
    }
    await incrementUserPoints(5);
  }

  Future<List<Map<String, String>>> getUserNames(List<String> uids) async {
    if (uids.isEmpty) return [];
    final chunks = <List<String>>[];
    for (var i = 0; i < uids.length; i += 10) {
      chunks.add(uids.sublist(i, i + 10 > uids.length ? uids.length : i + 10));
    }
    final List<Map<String, String>> results = [];
    for (var chunk in chunks) {
      final snap = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(snap.docs.map((doc) => {
        'id': doc.id,
        'name': doc.data()['displayName'] as String? ?? 'Bayani',
      }));
    }
    return results;
  }

  Stream<List<BayanihanComment>> getCommentsStream(String postId) {
    return _db.collection('bayanihan').doc(postId).collection('comments')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => BayanihanComment.fromJson(doc.data(), doc.id)).toList());
  }

  // --- Notifications ---

  Stream<List<AppNotification>> getNotificationsStream() {
    final uid = currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _db.collection('users').doc(uid).collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => AppNotification.fromJson(doc.data(), doc.id)).toList());
  }

  Future<void> sendNotification({
    required String recipientId,
    required String type,
    required String title,
    required String message,
    String? relatedId,
  }) async {
    await _db.collection('users').doc(recipientId).collection('notifications').add({
      'type': type,
      'title': title,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'relatedId': relatedId,
    });
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('notifications').doc(notificationId).update({'isRead': true});
  }


  // --- Fuel & Geocoding ---

  Stream<List<FuelStation>> getFuelStationsStream() {
    return _db.collection('fuel_stations').snapshots().map((snap) {
      return snap.docs.map((doc) => FuelStation.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Future<void> reportFuelStation(String stationId, StationStatus status, Map<String, double> prices) async {
    final user = currentUser;
    if (user == null) return;
    final uid = user.uid;
    final docRef = _db.collection('fuel_stations').doc(stationId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;

      final data = snap.data() ?? {};
      final currentPrices = Map<String, double>.from(data['prices'] ?? {});
      final pending = Map<String, dynamic>.from(data['pendingPrices'] ?? {});
      
      bool priceUpdated = false;

      // Process each reported price
      prices.forEach((fuelType, price) {
        final priceStr = price.toStringAsFixed(2);
        final fuelTypeKey = fuelType.toLowerCase();
        
        if (!pending.containsKey(fuelTypeKey)) pending[fuelTypeKey] = {};
        final priceMap = Map<String, dynamic>.from(pending[fuelTypeKey]);
        
        if (!priceMap.containsKey(priceStr)) priceMap[priceStr] = [];
        final voters = List<String>.from(priceMap[priceStr]);
        
        if (!voters.contains(uid)) {
          voters.add(uid);
          priceMap[priceStr] = voters;
          pending[fuelTypeKey] = priceMap;
          
          // Consensus reached (3 or more unique users)
          if (voters.length >= 3) {
            currentPrices[fuelType] = price;
            priceUpdated = true;
            // Clear pending for this fuel type after consensus
            pending.remove(fuelTypeKey);
          }
        }
      });

      tx.set(docRef, {
        'status': status.name,
        'prices': currentPrices,
        'pendingPrices': pending,
        'lastUpdated': FieldValue.serverTimestamp(),
        'reportedBy': user.displayName ?? 'Bayani',
        'reporters': FieldValue.arrayUnion([uid]),
        'reportCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    });
    
    await incrementUserPoints(15);
  }

  Future<String?> reverseGeocode(LatLng loc) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${loc.latitude}&lon=${loc.longitude}&zoom=18');
      final res = await http.get(url, headers: {'User-Agent': 'Kuryentahin/1.0'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['address']?['village'] ?? data['address']?['suburb'] ?? data['address']?['neighbourhood'] ?? 'Unknown';
      }
    } catch (e) { debugPrint('Geocode Error: $e'); }
    return null;
  }

  Future<LatLng?> forwardGeocode(String query) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=1');
      final res = await http.get(url, headers: {'User-Agent': 'Kuryentahin/1.0'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (data.isNotEmpty) return LatLng(double.parse(data[0]['lat']), double.parse(data[0]['lon']));
      }
    } catch (e) { debugPrint('Forward Geocode Error: $e'); }
    return null;
  }

  Future<int> syncOfficialSchedules(List<MeralcoSchedule> schedules) async {
    int count = 0;
    for (var s in schedules) {
      final areaName = 'OFFICIAL: ${s.location}';
      final exists = await _db.collection('outages').where('areaName', isEqualTo: areaName).get();
      if (exists.docs.isEmpty) {
        LatLng? loc = await forwardGeocode('${s.location}, Philippines');
        if (loc != null) {
          await _db.collection('outages').add(OutageReport(
            id: '', location: loc, status: OutageStatus.scheduled, reportedAt: DateTime.now(),
            areaName: areaName, barangay: s.location, notes: 'TIME: ${s.timeRange}\nREASON: ${s.reason}',
          ).toJson());
          count++;
        }
      }
    }
    return count;
  }

  // --- Initializers & Safety ---

  Future<void> init() async {
    try {
      NotificationSettings settings = await _fcm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _fcm.subscribeToTopic('outages');
        await _fcm.subscribeToTopic('fuel');
      }
    } catch (e) { debugPrint('FCM Error: $e'); }
  }

  Future<void> registerDevice(String deviceId) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    final docRef = _db.collection('device_locks').doc(deviceId);
    final snap = await docRef.get();
    if (snap.exists && snap.data()?['ownerUid'] != uid) {
      await signOut();
      throw Exception('Device locked to another account.');
    }
    await docRef.set({'ownerUid': uid, 'linkedAt': FieldValue.serverTimestamp()});
  }
}
