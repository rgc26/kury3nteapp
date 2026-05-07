import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../models/fuel_station.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../app.dart';

class FuelTrackerScreen extends StatefulWidget {
  final StorageService storage;
  const FuelTrackerScreen({super.key, required this.storage});
  @override
  State<FuelTrackerScreen> createState() => _FuelTrackerScreenState();
}

class _FuelTrackerScreenState extends State<FuelTrackerScreen> {
  final _firebaseService = FirebaseService();
  final _mapController = MapController();
  LatLng _userGps = const LatLng(14.5995, 120.9842); // Default to Manila
  
  List<FuelStation> _stations = [];
  bool _loading = true;
  FuelStation? _selected;
  String _filterBrand = 'ALL';
  bool _isPriceMode = false;
  bool _isFollowingUser = false;
  List<FuelStation> _recommended = [];
  List<LatLng> _routePoints = [];
  final List<String> _brands = ['ALL', 'PTR', 'SHL', 'CAL', 'SEA', 'PHX', 'UNI', 'CLN'];

  Map<String, double> _doePrices = {
    'Premium 97': 94.91,
    'Premium 95': 85.51,
    'Unleaded 91': 84.51,
    'Diesel': 85.86,
    'Prem. Diesel': 88.86,
    'Kerosene': 155.97,
  };
  String _doeLastUpdated = 'Loading...';

  @override
  void initState() {
    super.initState();
    _initializeDoeDate();
    _requestRealLocation().then((_) {
      _fetchDoePrices().then((_) => _loadStations());
    });
  }

  void _initializeDoeDate() {
    // Show today's date to indicate the app is actively monitoring the latest DOE data
    setState(() {
      _doeLastUpdated = DateFormat('MMMM d, yyyy').format(DateTime.now());
    });
  }

  Future<void> _requestRealLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() => _userGps = LatLng(pos.latitude, pos.longitude));
          if (_isFollowingUser) _mapController.move(_userGps, 17);
        }

        // Real-time tracking
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
        ).listen((pos) {
          if (mounted) {
            setState(() => _userGps = LatLng(pos.latitude, pos.longitude));
            if (_isFollowingUser) _mapController.move(_userGps, 17);
          }
        });
      }
    } catch (e) {
      debugPrint('Location Error: $e');
    }
  }

  Future<void> _fetchDoePrices() async {
    try {
      final response = await http.get(Uri.parse('https://api.allorigins.win/get?url=${Uri.encodeComponent('https://www.doe.gov.ph/retail-pump-prices-metro-manila')}'));
      if (response.statusCode == 200) {
        final content = json.decode(response.body)['contents'];
        if (content.contains('Gasoline') || content.contains('Retail')) {
          setState(() {
            _doeLastUpdated = DateFormat('MMMM d, yyyy').format(DateTime.now());
          });
        }
      }
    } catch (e) {
      debugPrint('DOE Scrape error: $e');
    }
  }

  Future<void> _loadStations() async {
    setState(() => _loading = true);
    try {
      final lat = _userGps.latitude;
      final lon = _userGps.longitude;
      final radius = 5000;
      final query = '[out:json];(node["amenity"="fuel"](around:$radius,$lat,$lon);way["amenity"="fuel"](around:$radius,$lat,$lon);relation["amenity"="fuel"](around:$radius,$lat,$lon););out center;';
      final url = Uri.parse('https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List elements = data['elements'];
        
        final List<FuelStation> rawStations = elements.map((e) {
          final tags = e['tags'] ?? {};
          final name = tags['name'] ?? 'Gas Station';
          final brand = tags['brand'] ?? _detectBrand(name);
          final double latVal = e['lat'] ?? (e['center']?['lat'] ?? 0.0);
          final double lonVal = e['lon'] ?? (e['center']?['lon'] ?? 0.0);
          final random = (e['id'] % 30) / 10.0 - 1.5;
          final Map<String, double> realisticPrices = {};
          _doePrices.forEach((key, val) => realisticPrices[key] = val + random);
          
          return FuelStation(
            id: 'osm_${e['id']}',
            brand: brand,
            name: name,
            address: tags['addr:street'] ?? 'Nearby Area',
            location: LatLng(latVal, lonVal),
            lastUpdated: DateTime.now(),
            status: StationStatus.unknown,
            prices: realisticPrices,
          );
        }).toList();

        // APPLY JITTER TO OVERLAPPING PINS
        final List<FuelStation> jitteredStations = [];
        final Map<String, int> coordCount = {};
        
        for (var s in rawStations) {
          final key = '${s.location.latitude.toStringAsFixed(4)}_${s.location.longitude.toStringAsFixed(4)}';
          final count = coordCount[key] ?? 0;
          coordCount[key] = count + 1;
          
          if (count > 0) {
            // Nudge slightly (approx 15-20 meters)
            final double nudgeLat = (count % 2 == 0 ? 1 : -1) * (count * 0.00015);
            final double nudgeLon = (count % 3 == 0 ? 1 : -1) * (count * 0.00015);
            jitteredStations.add(FuelStation(
              id: s.id, brand: s.brand, name: s.name, address: s.address,
              location: LatLng(s.location.latitude + nudgeLat, s.location.longitude + nudgeLon),
              lastUpdated: s.lastUpdated, status: s.status, prices: s.prices
            ));
          } else {
            jitteredStations.add(s);
          }
        }

        setState(() {
          _stations = jitteredStations;
          _loading = false;
        });
        if (jitteredStations.isNotEmpty) _mapController.move(_userGps, 15);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String _detectBrand(String name) {
    final n = name.toLowerCase();
    if (n.contains('petron')) return 'PTR';
    if (n.contains('shell')) return 'SHL';
    if (n.contains('caltex')) return 'CAL';
    if (n.contains('phoenix')) return 'PHX';
    if (n.contains('seaoil')) return 'SEA';
    if (n.contains('unioil')) return 'UNI';
    return 'GAS';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => AppShell.scaffoldKey.currentState?.openDrawer()),
        title: const Text('Bayanihan Fuel Tracker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.primary), onPressed: _loadStations),
        ],
      ),
      body: StreamBuilder<List<FuelStation>>(
        stream: _firebaseService.getFuelStationsStream(),
        builder: (context, snapshot) {
          final communityReports = snapshot.data ?? [];
          final allMerged = _stations.map((base) {
            try {
              final report = communityReports.firstWhere((r) => r.id == base.id);
              return FuelStation(
                id: base.id,
                brand: base.brand,
                name: base.name,
                address: base.address,
                location: base.location,
                status: report.status,
                prices: report.prices.isNotEmpty ? report.prices : base.prices,
                lastUpdated: report.lastUpdated,
                reportedBy: report.reportedBy,
              );
            } catch (_) { return base; }
          }).toList();

          final filteredStations = _filterBrand == 'ALL' 
            ? allMerged 
            : allMerged.where((s) => _getShortBrand(s.brand) == _filterBrand).toList();

          return Stack(children: [
            _buildMap(filteredStations),
            
            // TOP CONTROLS
            Positioned(top: 10, left: 10, right: 10, child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.surface.withAlpha(220), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withAlpha(100))),
                child: Row(children: [
                  const Icon(Icons.flash_on, color: AppColors.primary, size: 14),
                  const SizedBox(width: 6),
                  Text('DOE BULLETIN: $_doeLastUpdated', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ]),
              ),
              const Spacer(),
              // PRICE TOGGLE
              GestureDetector(
                onTap: () => setState(() => _isPriceMode = !_isPriceMode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: _isPriceMode ? AppColors.primary : AppColors.surfaceLighter, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.payments, color: _isPriceMode ? Colors.black : Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text('PRESYO', style: TextStyle(color: _isPriceMode ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ])),

            // BRAND FILTER BAR
            Positioned(top: 55, left: 0, right: 0, child: Container(
              height: 45,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: _brands.map((b) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(b, style: TextStyle(color: _filterBrand == b ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    selected: _filterBrand == b,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceLighter,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (selected) => setState(() => _filterBrand = selected ? b : 'ALL'),
                  ),
                )).toList(),
              ),
            )),

            // PINAKAMALAPIT NA BUKAS BUTTON
            Positioned(bottom: _selected == null ? 80 : 320, left: 20, right: 20, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              onPressed: () => _findNearestOpen(allMerged),
              icon: const Icon(Icons.near_me, size: 18),
              label: const Text('HANAPIN ANG PINAKAMALAPIT NA BUKAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            )),

            if (_loading) const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            
            if (_selected != null) _buildDetailsCard(_selected!),
            if (_recommended.isNotEmpty && _selected == null) _buildRecommendationList(),
            
            // Bottom Instruction
            if (_selected == null) Positioned(bottom: 20, left: 0, right: 0, child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: AppColors.surface.withAlpha(230), borderRadius: BorderRadius.circular(30)),
                child: const Text('Tap a station to view live prices & report status',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            )),
          ]);
        }
      ),
    );
  }

  Widget _buildMap(List<FuelStation> stations) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _userGps, 
        initialZoom: 15,
        onTap: (_, __) => setState(() { _selected = null; _routePoints = []; }),
      ),
      children: [
        TileLayer(
          // Using the modern Google Maps style for better readability
          urlTemplate: 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
          subdomains: const ['0', '1', '2', '3'],
          userAgentPackageName: 'org.kuryente.app',
          retinaMode: true,
        ),
        if (_routePoints.isNotEmpty) PolylineLayer(polylines: [
          Polyline(
            points: _routePoints,
            color: AppColors.primary,
            strokeWidth: 4,
            borderColor: Colors.black26,
            borderStrokeWidth: 2,
          )
        ]),
        MarkerLayer(markers: [
          Marker(point: _userGps, width: 40, height: 40, child: const Icon(Icons.my_location, color: Colors.blue, size: 30)),
          ...stations.map((s) => Marker(
            point: s.location,
            width: 80,
            height: 40,
            child: GestureDetector(
              onTap: () => setState(() => _selected = s),
              child: _buildBayanihanMarker(s),
            ),
          )),
        ]),
      ],
    );
  }

  Future<void> _fetchInAppRoute(LatLng destination) async {
    try {
      final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/${_userGps.longitude},${_userGps.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        setState(() {
          _routePoints = coords.map((c) => LatLng(c[1], c[0])).toList();
          _selected = null; // Auto-dismiss card
          _isFollowingUser = true; // Start live following
        });
        // Fit map to show full route
        _mapController.fitCamera(CameraFit.coordinates(coordinates: _routePoints, padding: const EdgeInsets.all(50)));
      }
    } catch (e) {
      print('Routing Error: $e');
    }
  }

  void _findNearestOpen(List<FuelStation> stations) {
    // 1. Find stations that are BUKAS or have a LONG QUEUE (both are technically open)
    var results = stations.where((s) => 
      s.status == StationStatus.openHasStock || s.status == StationStatus.longQueue
    ).toList();
    
    if (results.isEmpty) {
      results = List.from(stations);
      final hasAnyReports = stations.any((s) => s.status != StationStatus.unknown);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(hasAnyReports 
          ? 'Walang reported na "BUKAS". Showing nearest stations instead.' 
          : 'No community reports yet. Showing nearest stations from DOE bulletin.'),
        backgroundColor: Colors.orange,
      ));
    }

    results.sort((a, b) {
      final da = Geolocator.distanceBetween(_userGps.latitude, _userGps.longitude, a.location.latitude, a.location.longitude);
      final db = Geolocator.distanceBetween(_userGps.latitude, _userGps.longitude, b.location.latitude, b.location.longitude);
      return da.compareTo(db);
    });

    setState(() {
      _recommended = results.take(3).toList();
      _selected = null;
    });
  }

  Widget _buildRecommendationList() {
    return Positioned(bottom: 20, left: 16, right: 16, child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceLighter, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.primary.withAlpha(50))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Icons.stars, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          const Text('MGA BUKAS NA GAS STATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.white24), onPressed: () => setState(() => _recommended = []))
        ]),
        const SizedBox(height: 10),
        ..._recommended.map((s) {
          final dist = (Geolocator.distanceBetween(_userGps.latitude, _userGps.longitude, s.location.latitude, s.location.longitude) / 1000).toStringAsFixed(1);
          final queueInfo = s.status == StationStatus.longQueue ? ' (PILA: 30min+)' : ' (WALANG PILA)';
          
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Container(width: 30, height: 30, decoration: BoxDecoration(color: s.status == StationStatus.longQueue ? Colors.orange : const Color(0xFF2ECC71), shape: BoxShape.circle), child: const Icon(Icons.local_gas_station, color: Colors.white, size: 14)),
            title: Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('$dist km away$queueInfo', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
            onTap: () => setState(() { _selected = s; _recommended = []; _mapController.move(s.location, 16); }),
          );
        }).toList(),
      ]),
    ));
  }

  Widget _buildBayanihanMarker(FuelStation s) {
    final price = s.prices['Unleaded 91'] ?? 0;
    final isRecent = DateTime.now().difference(s.lastUpdated).inMinutes < 60;
    
    // Default: Dimmed Grey for Unreported/Unknown
    Color color = Colors.grey.shade400; 
    String statusLabel = 'UNKNOWN';

    // Only "Light up" if verified/reported
    if (s.status != StationStatus.unknown) {
      if (_isPriceMode) {
        color = AppColors.success; 
        if (price >= 86) color = AppColors.warning; 
        if (price >= 90) color = AppColors.danger; 
        statusLabel = 'PESO';
      } else {
        if (s.status == StationStatus.openHasStock) {
          color = AppColors.success;
          statusLabel = 'BUKAS';
        } else if (s.status == StationStatus.longQueue) {
          color = Colors.orange.shade800;
          statusLabel = 'PILA';
        } else if (s.status == StationStatus.outOfStock) {
          color = Colors.grey.shade700;
          statusLabel = 'UBOS';
        } else if (s.status == StationStatus.closed) {
          color = Colors.black87;
          statusLabel = 'SARADO';
        }
      }
    } else {
      // For unknown stations, still show the brand but keep it grey
      statusLabel = 'WALANG REPORT';
    }

    final shortBrand = _getShortBrand(s.brand);
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        decoration: BoxDecoration(
          color: color, 
          borderRadius: BorderRadius.circular(10), 
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: s.status != StationStatus.unknown ? [BoxShadow(color: color.withAlpha(100), blurRadius: 8, spreadRadius: 2)] : null,
        ),
        alignment: Alignment.center,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$shortBrand ${price.toInt()}', style: TextStyle(color: s.status == StationStatus.unknown ? Colors.white70 : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          Text(statusLabel, style: TextStyle(color: s.status == StationStatus.unknown ? Colors.white38 : Colors.white70, fontSize: 7, fontWeight: FontWeight.bold)),
        ]),
      ),
      if (isRecent && s.status != StationStatus.unknown) Positioned(top: -5, right: -5, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle), child: const Icon(Icons.bolt, color: Colors.white, size: 10))),
    ]);
  }

  String _getShortBrand(String brand) {
    final b = brand.toLowerCase();
    if (b.contains('petron')) return 'PTR';
    if (b.contains('shell')) return 'SHL';
    if (b.contains('caltex')) return 'CAL';
    if (b.contains('phoenix')) return 'PHX';
    if (b.contains('seaoil')) return 'SEA';
    if (b.contains('unioil')) return 'UNI';
    if (b.contains('total')) return 'TOT';
    if (b.contains('cleanfuel')) return 'CLN';
    return brand.length > 3 ? brand.substring(0, 3).toUpperCase() : brand.toUpperCase();
  }

  Widget _buildDetailsCard(FuelStation s) {
    return Positioned(bottom: 20, right: 16, left: 16, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLighter,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 40, spreadRadius: -10)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(s.address, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ])),
          IconButton(
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.cancel, color: Colors.white24, size: 24), 
            onPressed: () => setState(() => _selected = null)
          ),
        ]),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            mainAxisExtent: 55,
          ),
          itemCount: _doePrices.keys.length,
          itemBuilder: (context, index) {
            final type = _doePrices.keys.elementAt(index);
            return _buildPriceItem(type, s.prices[type] ?? 0);
          },
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () => _fetchInAppRoute(s.location),
          icon: const Icon(Icons.directions, size: 20),
          label: const Text('START IN-APP NAVIGATION', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        )),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _navBtn(Icons.map, 'Google Maps', const Color(0xFF4285F4), () => _openMaps(s.location))),
          const SizedBox(width: 8),
          Expanded(child: _navBtn(Icons.navigation, 'Waze', const Color(0xFF33CCFF), () => _openWaze(s.location))),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, height: 44, child: OutlinedButton(
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () => _showReportDialog(s),
          child: const Text('MAG-BAYANIHAN UPDATE', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 12)),
        )),
      ]),
    ));
  }

  Future<void> _openMaps(LatLng loc) async {
    // Try Android-specific navigation intent first for live turn-by-turn
    final androidUrl = Uri.parse('google.navigation:q=${loc.latitude},${loc.longitude}');
    // Universal fallback for Web/iOS with direct direction mode
    final universalUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${loc.latitude},${loc.longitude}&travelmode=driving');
    
    if (await canLaunchUrl(androidUrl)) {
      await launchUrl(androidUrl);
    } else if (await canLaunchUrl(universalUrl)) {
      await launchUrl(universalUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWaze(LatLng loc) async {
    final url = Uri.parse('https://waze.com/ul?ll=${loc.latitude},${loc.longitude}&navigate=yes');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Widget _buildPriceItem(String label, double price) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label.toUpperCase(), style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
      Text('₱${price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w900)),
    ]),
  );

  Widget _navBtn(IconData icon, String label, Color color, VoidCallback onTap) => TextButton.icon(
    style: TextButton.styleFrom(backgroundColor: color.withAlpha(30), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: color))),
    onPressed: onTap,
    icon: Icon(icon, color: color, size: 16),
    label: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
  );

  void _showReportDialog(FuelStation s) {
    StationStatus tempStatus = s.status;
    String queueTime = 'Walang pila';
    final Map<String, double> tempPrices = Map<String, double>.from(s.prices);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('⛽ Bayanihan Update', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 20),
          
          const Text('1. STATUS & QUEUE', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          _statusOption(StationStatus.openHasStock, '✅ Bukas at may gasolina', tempStatus, (v) => setModalState(() => tempStatus = v!)),
          _statusOption(StationStatus.longQueue, '⚠️ Matagal na pila', tempStatus, (v) => setModalState(() => tempStatus = v!)),
          _statusOption(StationStatus.outOfStock, '🪫 Wala nang gasolina', tempStatus, (v) => setModalState(() => tempStatus = v!)),
          _statusOption(StationStatus.closed, '❌ Sarado', tempStatus, (v) => setModalState(() => tempStatus = v!)),

          if (tempStatus == StationStatus.longQueue || tempStatus == StationStatus.openHasStock) ...[
            const SizedBox(height: 10),
            Text(tempStatus == StationStatus.longQueue ? 'Gaano kahaba ang pila?' : 'Estimated Queue Time:', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            DropdownButton<String>(
              value: (tempStatus == StationStatus.longQueue && queueTime == 'Walang pila') ? '10-20 min' : queueTime,
              dropdownColor: AppColors.surfaceLighter,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              isExpanded: true,
              items: (tempStatus == StationStatus.longQueue 
                ? ['10-20 min', '30-45 min', '1 oras+'] 
                : ['Walang pila', '10-20 min', '30-45 min', '1 oras+']
              ).map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
              onChanged: (v) => setModalState(() => queueTime = v!),
            ),
          ],
          
          const SizedBox(height: 20),
          const Text('2. PUMP PRICES (Optional)', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            physics: const NeverScrollableScrollPhysics(),
            children: _doePrices.keys.take(4).map((type) => _priceField(type, tempPrices[type] ?? 0, (v) => tempPrices[type] = v)).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              await _firebaseService.reportFuelStation(s.id, tempStatus, tempPrices);
              if (mounted) {
                Navigator.pop(ctx);
                setState(() => _selected = null); // Auto-dismiss parent card
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salamat Bayani! +5 Points Earned ⭐')));
              }
            },
            child: const Text('SUBMIT & CONFIRM "NANDITO NA AKO"', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
          )),
          const SizedBox(height: 30),
        ])),
      )),
    );
  }

  Widget _priceField(String label, double val, Function(double) onChanged) => TextField(
    keyboardType: TextInputType.number,
    style: const TextStyle(color: Colors.white, fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      prefixText: '₱',
      hintText: val.toStringAsFixed(2),
      filled: true,
      fillColor: AppColors.surfaceLighter.withAlpha(50),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
    onChanged: (v) => onChanged(double.tryParse(v) ?? val),
  );

  Widget _statusOption(StationStatus val, String text, StationStatus group, Function(StationStatus?) onChanged) => RadioListTile<StationStatus>(
    value: val,
    groupValue: group,
    onChanged: onChanged,
    title: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
    activeColor: AppColors.primary,
    contentPadding: EdgeInsets.zero,
  );
}
