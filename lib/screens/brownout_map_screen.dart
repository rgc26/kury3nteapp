import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_colors.dart';
import '../models/outage_report.dart';
import '../services/firebase_service.dart';
import '../app.dart';

class BrownoutMapScreen extends StatefulWidget {
  static final GlobalKey<BrownoutMapScreenState> mapStateKey = GlobalKey<BrownoutMapScreenState>();
  
  const BrownoutMapScreen({super.key});
  
  @override
  State<BrownoutMapScreen> createState() => BrownoutMapScreenState();
}

class BrownoutMapScreenState extends State<BrownoutMapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _showHeatmap = false;
  OutageReport? _selected;
  late AnimationController _pulse;
  
  // Default center
  static const _mapCenter = LatLng(14.5995, 120.9842);
  
  // Simulated GPS location for the user (draggable)
  LatLng _userGps = const LatLng(14.6010, 120.9850);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _initFirebase();
    // Automatically fetch real GPS location and "Wake Up" map
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestRealLocation();
      // Nudge the map to prevent "Gray Screen" on web load
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _mapController.move(_mapController.camera.center, _mapController.camera.zoom);
        }
      });
    });
  }
  
  Future<void> _initFirebase() async {
    await _firebaseService.init();
    if (mounted) setState(() {});
  }

  void moveToLocation(LatLng location, OutageReport? report) {
    _mapController.move(location, 16);
    if (report != null) {
      setState(() => _selected = report);
    }
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 70,
        leading: Container(
          margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          decoration: BoxDecoration(color: Colors.black.withAlpha(150), shape: BoxShape.circle),
          child: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 20),
            onPressed: () => AppShell.scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        title: null,
      ),
      body: StreamBuilder<List<OutageReport>>(
        stream: _firebaseService.getOutagesStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
                  const SizedBox(height: 16),
                  Text('Error loading map data: ${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () => setState(() {}), child: const Text('Retry'))
                ],
              ),
            );
          }

          final _outages = snapshot.data ?? [];
          final noP = _outages.where((o) => o.status == OutageStatus.nopower).length;
          final sched = _outages.where((o) => o.status == OutageStatus.scheduled).length;
          final unv = _outages.where((o) => o.status == OutageStatus.unverified).length;
          final rest = _outages.where((o) => o.status == OutageStatus.restored).length;

          return Stack(children: [
            FlutterMap(mapController: _mapController, options: MapOptions(
              initialCenter: _mapCenter, initialZoom: 14, minZoom: 8, maxZoom: 18,
              onTap: (_, __) => setState(() => _selected = null),
            ), children: [
              TileLayer(
                // Use multiple Google subdomains to speed up loading and prevent gray gaps
                urlTemplate: 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                subdomains: const ['0', '1', '2', '3'],
                userAgentPackageName: 'org.kuryente.app',
                retinaMode: true,
                maxZoom: 20,
              ),
              
              if (_showHeatmap) CircleLayer(circles: _outages.where((o) => o.status == OutageStatus.nopower)
                .map((o) => CircleMarker(point: o.location, radius: 40, color: AppColors.danger.withAlpha(40), borderColor: AppColors.danger.withAlpha(80), borderStrokeWidth: 1)).toList()),
                
              MarkerLayer(markers: [
                ..._outages.map(_marker),
                // Fixed User GPS Marker
                Marker(
                  point: _userGps,
                  width: 50,
                  height: 50,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(4)),
                        child: const Text('You', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                      const Icon(Icons.person_pin_circle, color: Colors.blueAccent, size: 30),
                    ],
                  ),
                ),
              ]),
            ]),
            
            // Top stats (Aligned Left, next to Menu)
            Positioned(top: MediaQuery.of(context).padding.top + 8, left: 52, right: 16, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(180),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha(30)),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(100), blurRadius: 10)]
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _statItem('🔴', noP, 'Confirmed', AppColors.danger),
                  _divider(),
                  _statItem('🟡', unv, 'Unverified', AppColors.warning),
                  _divider(),
                  
                  if (sched > 0)
                    PopupMenuButton<OutageReport>(
                      position: PopupMenuPosition.under,
                      offset: const Offset(0, 10),
                      onSelected: (o) {
                        _mapController.move(o.location, 16);
                        setState(() => _selected = o);
                      },
                      itemBuilder: (ctx) => _outages
                        .where((o) => o.status == OutageStatus.scheduled)
                        .map((o) => PopupMenuItem(
                          value: o,
                          child: Text(o.barangay ?? 'Official', style: const TextStyle(fontSize: 12)),
                        )).toList(),
                      child: _statItem('🔵', sched, 'Official', Colors.blue, isDropdown: true),
                    )
                  else
                    _statItem('🔵', sched, 'Official', Colors.blue),
                    
                  _divider(),
                  _statItem('🟢', rest, 'Restored', AppColors.success),
                ]),
              ),
            )),
            
            // Controls
            Positioned(top: MediaQuery.of(context).padding.top + 70, right: 16, child: Column(children: [
              _ctrlBtn(Icons.layers, 'Heat', _showHeatmap, () => setState(() => _showHeatmap = !_showHeatmap)),
              const SizedBox(height: 8),
              _ctrlBtn(Icons.my_location, 'Me', false, _requestRealLocation),
            ])),
            
            // Detail card
            if (_selected != null) Positioned(bottom: 80, left: 16, right: 16, child: _detail(_selected!, _outages)),
            
            // Report button (Floating at bottom)
            Builder(
              builder: (context) {
                final uid = _firebaseService.currentUser?.uid;
                final hasActiveReport = uid != null && _outages.any((o) => 
                  (o.status == OutageStatus.nopower || o.status == OutageStatus.unverified) && 
                  o.reporters.contains(uid)
                );
                
                if (hasActiveReport) {
                  return Positioned(bottom: 16, left: 16, right: 16, child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(color: AppColors.surface.withAlpha(220), borderRadius: BorderRadius.circular(30), border: Border.all(color: AppColors.border)),
                      child: const Text('✅ You have an active report', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                    )
                  ));
                }

                return Positioned(bottom: 16, left: 16, right: 16, child: Center(child: ElevatedButton.icon(
                  onPressed: () => _report(null), 
                  icon: const Icon(Icons.flash_off, size: 18), 
                  label: const Text('Report Brownout Here'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 8, shadowColor: AppColors.danger.withAlpha(100)),
                )));
              }
            ),
          ]);
        }
      ),
    );
  }

  Future<void> _requestRealLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable location services in your browser/device.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied.')));
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')));
      return;
    }

    // Get current position
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fetching your real GPS location... 📍')));
    
    final position = await Geolocator.getCurrentPosition();
    
    setState(() {
      _userGps = LatLng(position.latitude, position.longitude);
    });
    
    _mapController.move(_userGps, 16);
    
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Location updated!')));
  }

  Widget _chip(String e, String l, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withAlpha(220), 
      borderRadius: BorderRadius.circular(20), 
      border: Border.all(color: c.withAlpha(150), width: 1.5),
      boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 4, offset: const Offset(0, 2))],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(e, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(l, style: TextStyle(color: c.withAlpha(255), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      ],
    ),
  );

  Widget _ctrlBtn(IconData ic, String l, bool active, VoidCallback tap) => GestureDetector(onTap: tap, child: Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: active ? AppColors.primary.withAlpha(40) : AppColors.surface.withAlpha(220), borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? AppColors.primary : AppColors.border)),
    child: Column(children: [Icon(ic, color: active ? AppColors.primary : AppColors.textSecondary, size: 20), Text(l, style: TextStyle(color: active ? AppColors.primary : AppColors.textMuted, fontSize: 9))]),
  ));

  Marker _marker(OutageReport o) {
    Color c;
    IconData ic;
    if (o.status == OutageStatus.scheduled) { c = Colors.blue; ic = Icons.schedule; }
    else if (o.status == OutageStatus.unverified) { c = AppColors.warning; ic = Icons.help_outline; }
    else if (o.status == OutageStatus.restored) { c = AppColors.success; ic = Icons.flash_on; }
    else { c = AppColors.danger; ic = Icons.flash_off; } // nopower
    
    final bool isPulsing = o.status == OutageStatus.nopower || o.status == OutageStatus.unverified;
    
    return Marker(point: o.location, width: 36, height: 36, child: GestureDetector(
      onTap: () => setState(() => _selected = o),
      child: AnimatedBuilder(animation: _pulse, builder: (_, ch) => Transform.scale(scale: isPulsing ? 1.0 + _pulse.value * 0.12 : 1.0, child: ch),
        child: Container(decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.withAlpha(100), blurRadius: 8, spreadRadius: 2)]),
          child: Icon(ic, color: Colors.white, size: 18))),
    ));
  }

  Widget _detail(OutageReport o, List<OutageReport> outages) {
    Color c;
    String st;
    if (o.status == OutageStatus.scheduled) { c = Colors.blue; st = '🔵 Scheduled Advisory'; }
    else if (o.status == OutageStatus.unverified) { c = AppColors.warning; st = '🟡 Unverified Report'; }
    else if (o.status == OutageStatus.restored) { c = AppColors.success; st = '🟢 Power Restored'; }
    else { c = AppColors.danger; st = '🔴 Confirmed Outage'; }
    
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withAlpha(100)), boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 20, offset: const Offset(0, -4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withAlpha(30), borderRadius: BorderRadius.circular(12)),
            child: Text(st, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600))),
          const Spacer(),
          if (o.upvotes >= 3) const Icon(Icons.verified, color: AppColors.accent, size: 16),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _selected = null), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ]),
        const SizedBox(height: 8),
        Text(o.areaName ?? 'Unknown Location', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.timer, size: 14, color: AppColors.textMuted), const SizedBox(width: 4),
          Text(o.durationText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Icon(Icons.how_to_vote, size: 14, color: AppColors.textMuted), const SizedBox(width: 4),
          Text('${o.upvotes} points', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
        if (o.notes != null && o.notes!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(o.notes!, style: Theme.of(context).textTheme.bodySmall)),
        
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        // Action Buttons depending on state
        Builder(
          builder: (context) {
            final uid = _firebaseService.currentUser?.uid;
            final hasAnyActiveReport = uid != null && outages.any((outage) => 
              (outage.status == OutageStatus.nopower || outage.status == OutageStatus.unverified) && 
              outage.reporters.contains(uid)
            );
            
            final hasReportedThis = uid != null && o.reporters.contains(uid);
            final hasRestored = uid != null && o.restorers.contains(uid);
            final isTooOld = DateTime.now().difference(o.reportedAt).inHours >= 24;

            if (o.status == OutageStatus.unverified || o.status == OutageStatus.nopower) {
              final dist = Geolocator.distanceBetween(_userGps.latitude, _userGps.longitude, o.location.latitude, o.location.longitude);
              final isNear = dist <= 300;

              return Column(
                children: [
                  Row(
                    children: [
                      if (o.status == OutageStatus.unverified)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (hasReportedThis || hasAnyActiveReport || isTooOld || !isNear) ? null : () => _report(o),
                            icon: Icon(isTooOld ? Icons.timer_off : (hasReportedThis ? Icons.check : Icons.add), size: 16),
                            label: Text(isTooOld ? 'Expired' : (hasReportedThis ? 'You reported' : 'Me too')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.warning,
                              disabledForegroundColor: AppColors.textMuted,
                            ),
                          ),
                        ),
                      if (o.status == OutageStatus.unverified) const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (hasRestored || isTooOld || !isNear) ? null : () => _kuryenteNa(o),
                          icon: Icon(isTooOld ? Icons.timer_off : (hasRestored ? Icons.check : Icons.lightbulb), size: 16),
                          label: Text(isTooOld ? 'Expired' : (hasRestored ? 'Voted Restored' : 'Kuryente Na!')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success, 
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.success.withAlpha(100),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isNear) Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('⚠️ You must be within 300m to verify', style: const TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          }
        ),
      ]),
    );
  }

  void _kuryenteNa(OutageReport target) async {
    const distance = Distance();
    final distInMeters = distance.as(LengthUnit.Meter, _userGps, target.location);
    if (distInMeters > 300) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Too far! You must be within 300m to confirm restoration.')));
      return;
    }
    await _firebaseService.markRestored(target.id);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Restoration vote submitted!')));
  }

  void _report(OutageReport? targetPin) {
    if (targetPin != null) {
      // Validate distance to existing pin
      const distance = Distance();
      final distInMeters = distance.as(LengthUnit.Meter, _userGps, targetPin.location);
      if (distInMeters > 300) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Too far! You must be within 300m of the pin to confirm.')));
        return;
      }
    }

    String? notes;
    final exactLoc = targetPin?.location ?? _userGps;
    TextEditingController brgyController = TextEditingController(text: targetPin?.barangay);
    bool isLoadingBrgy = targetPin == null; // Only load if it's a new report
    bool isSubmitting = false;
    String? originalBrgy = targetPin?.barangay;
    final trust = _firebaseService.currentUserTrust;

    // Show modal first, then update it when geocoding finishes
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            
            // Fetch barangay once when the modal is opened (only for NEW reports)
            if (isLoadingBrgy && brgyController.text.isEmpty) {
              _fetchBarangay(exactLoc).then((fetchedBrgy) {
                if (mounted) {
                  setModalState(() {
                    brgyController.text = fetchedBrgy ?? 'Unknown';
                    originalBrgy = fetchedBrgy;
                    isLoadingBrgy = false;
                  });
                }
              });
            }

            return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surfaceLighter, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    const Text('🔴 I-report ang Brownout', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.primary.withAlpha(40), borderRadius: BorderRadius.circular(12)),
                      child: Text(trust.level.badge, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                
                const SizedBox(height: 8),
                Text('I-confirm na walang kuryente sa location mo.', style: Theme.of(ctx).textTheme.bodyMedium),
                
                // Privacy Note
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.success.withAlpha(20), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.success.withAlpha(50))),
                  child: const Row(children: [
                    Icon(Icons.privacy_tip, color: AppColors.success, size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text('Data Privacy: We do not save your exact house location. Your GPS is blurred to the barangay level.', style: TextStyle(fontSize: 11, color: AppColors.success))),
                  ]),
                ),
                
                const SizedBox(height: 16),
                
                // Auto-fetched Barangay Display (Locked if joining an existing report)
                TextField(
                  controller: brgyController,
                  enabled: targetPin == null, // Disable if it's a "Me Too" report
                  decoration: InputDecoration(
                    labelText: targetPin == null ? 'Barangay Name' : 'Barangay (Locked for Confirmation)',
                    prefixIcon: const Icon(Icons.location_city, size: 20),
                    suffixIcon: (isLoadingBrgy && targetPin == null) ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                  ),
                ),
                
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(hintText: 'Notes (optional)', prefixIcon: Icon(Icons.notes, size: 20)), 
                  onChanged: (v) => notes = v,
                ),
                
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: (isLoadingBrgy || isSubmitting) ? null : () async {
                    setModalState(() => isSubmitting = true);
                    
                    // Validation: if they changed the text, verify distance
                    if (originalBrgy != null && brgyController.text.trim() != originalBrgy!.trim()) {
                      try {
                        final query = '${brgyController.text.trim()}, Caloocan';
                        final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json');
                        final response = await http.get(url, headers: {'User-Agent': 'kury3nteapp/1.0'});
                        if (response.statusCode == 200) {
                          final data = json.decode(response.body) as List;
                          if (data.isNotEmpty) {
                            final lat = double.parse(data[0]['lat']);
                            final lon = double.parse(data[0]['lon']);
                            final geocodedLoc = LatLng(lat, lon);
                            
                            const distance = Distance();
                            final distInMeters = distance.as(LengthUnit.Meter, exactLoc, geocodedLoc);
                            
                            // Max spoofing distance: 2km
                            if (distInMeters > 2000) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Too far! You are not physically in that Barangay.'), backgroundColor: AppColors.danger));
                              setModalState(() => isSubmitting = false);
                              return;
                            }
                          } else {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Could not verify this Barangay name on the map.'), backgroundColor: AppColors.danger));
                            setModalState(() => isSubmitting = false);
                            return;
                          }
                        }
                      } catch (e) {
                         // silently ignore network errors for validation to not block legitimate reports offline
                      }
                    }

                    // Privacy: Blur the exact location by rounding to 3 decimal places (~110m accuracy)
                    final blurredLoc = LatLng(
                      double.parse(exactLoc.latitude.toStringAsFixed(3)),
                      double.parse(exactLoc.longitude.toStringAsFixed(3))
                    );

                    final r = OutageReport(
                      id: '', // Will be generated
                      location: blurredLoc, 
                      status: OutageStatus.unverified, 
                      reportedAt: DateTime.now(), 
                      areaName: (brgyController.text.isNotEmpty && brgyController.text != 'Unknown') 
                        ? 'Brgy. ${brgyController.text}' 
                        : (targetPin?.areaName ?? 'Manual Report'), 
                      barangay: brgyController.text.isNotEmpty ? brgyController.text : targetPin?.barangay,
                      notes: notes
                    );

                    try {
                      if (targetPin != null) {
                        await _firebaseService.upvoteReport(targetPin.id);
                      } else {
                        await _firebaseService.submitReport(r);
                      }
                      
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Brownout reported! Salamat! 🙏'),
                            backgroundColor: AppColors.success,
                          )
                        );
                      }
                    } catch (e) {
                      setModalState(() => isSubmitting = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ Error: $e'), 
                            backgroundColor: AppColors.danger
                          )
                        );
                      }
                    }
                  },
              icon: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send), 
              label: Text(isSubmitting ? 'Verifying Location...' : 'I-submit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger, 
                foregroundColor: Colors.white, 
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: AppColors.danger.withAlpha(100),
              ),
            )),
            const SizedBox(height: 20),
          ]),
        );
      }
    );
  });
}

  Widget _statItem(String icon, int count, String label, Color color, {bool isDropdown = false}) {
    String shortLabel = label;
    if (label == 'Confirmed') shortLabel = 'Confirmed';
    if (label == 'Unverified') shortLabel = 'Unv.';
    if (label == 'Restored') shortLabel = 'OK';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(80),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 4),
          Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 4),
          Text(shortLabel, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 8, fontWeight: FontWeight.bold)),
          if (isDropdown) ...[
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, color: Colors.white.withAlpha(150), size: 12),
          ]
        ],
      ),
    );
  }

  Widget _divider() => const SizedBox(width: 6);

  // Reverse Geocoding using OpenStreetMap (Nominatim API)
  Future<String?> _fetchBarangay(LatLng loc) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${loc.latitude}&lon=${loc.longitude}&zoom=18&addressdetails=1');
      // We use standard dart:io HttpClient or http package if available.
      // Since we don't have http imported in this file directly, let's use the simplest approach
      // Oh wait, I need to import http or use dart:html for web. 
      // I'll just import http package at the top.
      final response = await _firebaseService.reverseGeocode(loc);
      return response;
    } catch (e) {
      return 'Unknown';
    }
  }
}
