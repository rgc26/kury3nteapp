import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/meralco_schedule.dart';
import '../models/app_models.dart';
import '../services/meralco_scraper.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../models/outage_report.dart';
import 'package:latlong2/latlong.dart';
import '../app.dart';

class AlertsScreen extends StatefulWidget {
  final StorageService storage;
  const AlertsScreen({super.key, required this.storage});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with SingleTickerProviderStateMixin {
  final _scraper = MeralcoScraper();
  final _firebaseService = FirebaseService();
  final _locationService = LocationService();
  List<MeralcoSchedule> _schedules = [];
  List<WatchlistArea> _watchlist = [];
  List<OutageReport> _reports = [];
  bool _loading = true;
  String? _error;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _scraper.fetchMaintenanceSchedules(),
        widget.storage.getWatchlist(),
        Future.delayed(const Duration(milliseconds: 800)), // Ensure animation visibility
      ]);
      
      final schedules = results[0] as List<MeralcoSchedule>;
      final reports = await _firebaseService.fetchActiveReports();
      
      setState(() {
        _schedules = schedules;
        _watchlist = results[1] as List<WatchlistArea>;
        _reports = reports;
        _loading = false;
      });

      // SYNC: Push these official Meralco schedules to the Map as "Official Scheduled" markers
      final synced = await _firebaseService.syncOfficialSchedules(schedules);
      if (synced > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚡ Sync: Added $synced official schedules to map!'), backgroundColor: AppColors.primary),
        );
      }
      
    } catch (e) {
      setState(() { _loading = false; _error = 'Failed to load Meralco data. Check connection.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AppShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Row(children: [Text('🔔 ', style: TextStyle(fontSize: 22)), Text('Smart Alerts')]),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)],
        bottom: TabBar(
          controller: _tabCtrl, 
          isScrollable: true,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          tabs: const [
            Tab(text: '📋 Meralco'), Tab(text: '📍 Watchlist'), Tab(text: '👤 My Notifications'),
          ],
        ),
      ),
      body: SelectionContainer.disabled(
        child: Stack(
          children: [
            TabBarView(controller: _tabCtrl, children: [
              _buildMeralcoTab(),
              _buildWatchlistTab(),
              _buildNotificationsTab(),
            ]),
            if (_loading) const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return StreamBuilder<List<AppNotification>>(
      stream: _firebaseService.getNotificationsStream(),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        if (notifications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_none, size: 64, color: AppColors.textMuted),
                SizedBox(height: 16),
                Text('Walang notifications...', style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: notifications.length,
          separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
          itemBuilder: (context, index) {
            final n = notifications[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: (n.isRead ? AppColors.textMuted : AppColors.primary).withAlpha(30),
                child: Icon(
                  n.type == 'interested' ? Icons.person_add : n.type == 'salamat' ? Icons.favorite : Icons.comment,
                  color: n.isRead ? AppColors.textMuted : AppColors.primary,
                  size: 18,
                ),
              ),
              title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold, fontSize: 13)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.message, style: const TextStyle(fontSize: 11)),
                  Text(_timeAgo(n.createdAt), style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                ],
              ),
              onTap: () => _firebaseService.markNotificationAsRead(n.id),
            );
          },
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }


  Widget _buildMeralcoTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(children: [
          const Text('Maintenance Schedules', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Outfit', letterSpacing: -0.5)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.3), blurRadius: 8)],
            ),
            child: const Text('LIVE', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
          ),
        ]),
        const Text('Source: company.meralco.com.ph', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        ..._schedules.map(_scheduleCard),
        const SizedBox(height: 40),
      ],
    );
  }


  Widget _scheduleCard(MeralcoSchedule s) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: const Color(0x663C3329),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))],
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () {
        // Find the synced official report for this schedule
        try {
          final officialReport = _reports.firstWhere((r) => 
            r.status == OutageStatus.scheduled && r.barangay == s.location);
          AppShell.shellKey.currentState?.jumpToReport(officialReport);
        } catch (_) {
          // If not synced yet, we could potentially geocode on the fly, 
          // but for now we just show a message or do nothing if no match found.
        }
      },
      splashColor: AppColors.primary.withOpacity(0.1),
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(30)),
              child: Text(s.date.toUpperCase(), style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
            const Spacer(),
            Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary.withOpacity(0.6)),
            const SizedBox(width: 6),
            Text(s.location, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 20),
          Text(s.timeRange, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Outfit', color: Colors.white)),
          const SizedBox(height: 12),
          
          // REASON SECTION
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('REASON: ${s.reason}', style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4, fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 12),

          // AFFECTED AREAS
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AFFECTED AREAS', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(s.affectedAreas, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ]),
      ),
    ),
  );


  Widget _buildWatchlistTab() {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Monitor multiple locations para ma-alert ka agad ng scheduled maintenance at grid alerts.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500)),
            const SizedBox(height: 28),
            if (_watchlist.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(color: const Color(0x663C3329), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white10)),
                child: Column(children: [
                  Icon(Icons.location_on_outlined, color: AppColors.primary.withOpacity(0.3), size: 48),
                  const SizedBox(height: 16),
                  const Text('Walang nakalistang location.', style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
                  const Text('I-tap ang (+) para mag-add.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ]),
              )
            else
              ..._watchlist.map(_watchlistCard),
            const SizedBox(height: 24),
            _infoCard('Smart Alerts Active', 'Makatanggap ng push notifications kapag may emergency sa iyong mga watchlist locations.'),
            const SizedBox(height: 100),
          ],
        ),
        Positioned(
          bottom: 30, right: 24,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
            ),
            child: FloatingActionButton(
              heroTag: 'add_watchlist_btn',
              backgroundColor: AppColors.primary, 
              elevation: 0,
              onPressed: _addWatchlistItem, 
              child: const Icon(Icons.add, size: 28, color: Colors.black),
            ),
          ),
        ),
      ],
    );
  }

  Widget _watchlistCard(WatchlistArea w) {
    // Check if any report is within 3km of this watchlist item
    OutageReport? activeAlert;
    try {
      activeAlert = _reports.firstWhere((r) {
        final dist = _calculateDistance(w.lat, w.lng, r.location.latitude, r.location.longitude);
        return dist < 3.0; // 3km radius
      });
    } catch (_) {}

    final hasAlert = activeAlert != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0x663C3329),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: hasAlert ? AppColors.danger.withOpacity(0.5) : Colors.white.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: hasAlert ? AppColors.danger.withOpacity(0.1) : Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: hasAlert ? () {
          AppShell.shellKey.currentState?.jumpToReport(activeAlert!);
        } : null,
        splashColor: (hasAlert ? AppColors.danger : AppColors.primary).withOpacity(0.1),
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12), 
              decoration: BoxDecoration(color: (hasAlert ? AppColors.danger : Colors.white).withOpacity(0.05), shape: BoxShape.circle), 
              child: Text(_labelIcon(w.label), style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(w.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8, fontSize: 15, fontFamily: 'Outfit')),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  width: 8, height: 8, 
                  decoration: BoxDecoration(
                    color: hasAlert ? AppColors.danger : AppColors.success, 
                    shape: BoxShape.circle, 
                    boxShadow: [BoxShadow(color: hasAlert ? AppColors.danger : AppColors.success, blurRadius: 4)]
                  )
                ),
                const SizedBox(width: 8),
                Text(
                  hasAlert ? 'ACTIVE OUTAGE ALERT' : 'NORMAL GRID STATUS', 
                  style: TextStyle(color: hasAlert ? AppColors.danger : AppColors.success, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                ),
              ]),
            ])),
            if (hasAlert)
              const Icon(Icons.arrow_forward_ios, color: AppColors.danger, size: 14)
            else
              Icon(Icons.chevron_right, color: AppColors.primary.withOpacity(0.4), size: 20),
          ]),
        ),
      ),
    );
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, LatLng(lat1, lon1), LatLng(lat2, lon2));
  }

  Widget _infoCard(String title, String desc) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.05), 
      borderRadius: BorderRadius.circular(24), 
      border: Border.all(color: AppColors.primary.withOpacity(0.15)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 18), 
        const SizedBox(width: 10), 
        Text(title, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 13, fontFamily: 'Outfit')),
      ]),
      const SizedBox(height: 10),
      Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5, fontWeight: FontWeight.w500)),
    ]),
  );

  void _addWatchlistItem() {
    String name = '';
    String label = 'Home';
    List<LocationSuggestion> suggestions = [];
    bool searching = false;
    double? lat, lng;
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: const Color(0xFF1F1B16),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 32),
            const Text('📍 Add Location', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'Outfit')),
            const SizedBox(height: 8),
            const Text('Mag-search ng location para sa alerts.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 28),
            
            // LOCATION SEARCH FIELD
            TextField(
              controller: searchCtrl,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Search Location',
                hintText: 'e.g., Quezon City, Manila',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searching ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))) : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.03),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onChanged: (v) async {
                name = v;
                if (v.length > 2) {
                  setModalState(() => searching = true);
                  final results = await _locationService.searchLocations(v);
                  setModalState(() {
                    suggestions = results;
                    searching = false;
                  });
                } else {
                  setModalState(() => suggestions = []);
                }
              },
            ),
            
            // SUGGESTIONS LIST
            if (suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
                  itemBuilder: (ctx, i) => ListTile(
                    dense: true,
                    title: Text(suggestions[i].name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    subtitle: Text(suggestions[i].address, style: const TextStyle(color: AppColors.textMuted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      setModalState(() {
                        searchCtrl.value = TextEditingValue(
                          text: suggestions[i].name,
                          selection: TextSelection.collapsed(offset: suggestions[i].name.length),
                        );
                        name = suggestions[i].name;
                        lat = suggestions[i].lat;
                        lng = suggestions[i].lng;
                        suggestions = [];
                      });
                    },
                  ),
                ),
              ),

            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: label, 
              decoration: InputDecoration(
                labelText: 'Label',
                prefixIcon: const Icon(Icons.label_outline),
                filled: true,
                fillColor: Colors.white.withOpacity(0.03),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              items: ['Home', 'Office', 'School', "Parent's House", 'Other'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: (v) => label = v ?? 'Home',
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, 
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () {
                  final finalName = searchCtrl.text.trim();
                  if (finalName.isEmpty) return;
                  final w = WatchlistArea(
                    id: 'w_${DateTime.now().millisecondsSinceEpoch}', 
                    name: finalName, 
                    label: label, 
                    lat: lat ?? 14.5995, 
                    lng: lng ?? 120.9842
                  );
                  setState(() => _watchlist.add(w));
                  widget.storage.saveWatchlist(_watchlist);
                  Navigator.pop(ctx);
                }, 
                child: const Text('Save Location', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  String _labelIcon(String label) {
    switch (label.toLowerCase()) {
      case 'home': return '🏠';
      case 'office': return '🏢';
      case 'school': return '🏫';
      default: return '📍';
    }
  }
}
