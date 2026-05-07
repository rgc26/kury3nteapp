import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/meralco_schedule.dart';
import '../models/app_models.dart';
import '../services/meralco_scraper.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
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
  List<MeralcoSchedule> _schedules = [];
  List<AlertArea> _alerts = [];
  List<WatchlistArea> _watchlist = [];
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
        _scraper.fetchAlertAreas(),
        widget.storage.getWatchlist(),
      ]);
      
      final schedules = results[0] as List<MeralcoSchedule>;
      
      setState(() {
        _schedules = schedules;
        _alerts = results[1] as List<AlertArea>;
        _watchlist = results[2] as List<WatchlistArea>;
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
        bottom: TabBar(controller: _tabCtrl, tabs: const [
          Tab(text: '📋 Meralco'), Tab(text: '⚡ Grid Status'), Tab(text: '📍 Watchlist'),
        ]),
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        _buildMeralcoTab(),
        _buildGridTab(),
        _buildWatchlistTab(),
      ]),
    );
  }

  Widget _buildMeralcoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('🔴 Red/Yellow Alert Areas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
        const SizedBox(height: 12),
        ..._alerts.map(_alertAreaCard),
        const SizedBox(height: 32),
        Row(children: [
          const Text('Maintenance Schedules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
          const SizedBox(width: 12),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: const Text('LIVE', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w900))),
        ]),
        const Text('Source: company.meralco.com.ph', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 16),
        ..._schedules.map(_scheduleCard),
      ],
    );
  }

  Widget _alertAreaCard(AlertArea a) {
    final isCritical = a.alertLevel == AlertLevel.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: const Color(0xFF261E15), borderRadius: BorderRadius.circular(16), border: Border.all(color: isCritical ? Colors.pink : AppColors.primary)),
      child: ExpansionTile(
        title: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isCritical ? Colors.pink.withOpacity(0.2) : AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text(a.alertText, style: TextStyle(color: isCritical ? Colors.pink : AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900))),
          const SizedBox(width: 12),
          Text(a.city, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        children: [
          Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 8, runSpacing: 8, children: a.barangays.map((b) => Chip(label: Text(b, style: const TextStyle(fontSize: 10)), backgroundColor: AppColors.surfaceLight)).toList())),
        ],
      ),
    );
  }

  Widget _scheduleCard(MeralcoSchedule s) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF261E15), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border.withOpacity(0.5))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Text(s.date, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800))),
        const Spacer(),
        const Icon(Icons.location_on, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(s.location, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ]),
      const SizedBox(height: 12),
      Text(s.timeRange, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Outfit')),
      const SizedBox(height: 4),
      Text(s.reason, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    ]),
  );

  Widget _buildGridTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          const Text('NGCP Grid Outlook', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
          const Spacer(),
          Text('As of ${DateTime.now().hour}:${DateTime.now().minute}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
        const SizedBox(height: 16),
        _gridCard('Luzon Grid', AlertLevel.yellow, '12.4k', '11.8k', '0.6k'),
        const SizedBox(height: 12),
        _gridCard('Visayas Grid', AlertLevel.green, '2.8k', '2.2k', '0.6k'),
        const SizedBox(height: 12),
        _gridCard('Mindanao Grid', AlertLevel.green, '3.1k', '2.5k', '0.6k'),
        const SizedBox(height: 32),
        const Text('🛢️ National Fuel Reserve', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
        const SizedBox(height: 16),
        _fuelReserveBar('Gasoline', 0.65, '45 Days'),
        _fuelReserveBar('Diesel', 0.48, '32 Days', critical: true),
        const SizedBox(height: 24),
        _buildCommunityReportCard(),
      ],
    );
  }

  Widget _gridCard(String grid, AlertLevel level, String capacity, String demand, String reserve) {
    final c = level == AlertLevel.red ? AppColors.danger : level == AlertLevel.yellow ? AppColors.warning : AppColors.success;
    final emoji = level == AlertLevel.red ? '🔴' : level == AlertLevel.yellow ? '🟡' : '🟢';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF261E15), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border.withOpacity(0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(grid, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withAlpha(25), borderRadius: BorderRadius.circular(12)),
            child: Text('$emoji ${level.name.toUpperCase()}', style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _gridStat('Capacity', capacity),
          _gridStat('Demand', demand),
          _gridStat('Reserve', reserve),
        ]),
      ]),
    );
  }

  Widget _gridStat(String l, String v) => Expanded(child: Column(children: [
    Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
    Text(l, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
  ]));

  Widget _fuelReserveBar(String type, double pct, String days, {bool critical = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(type, style: const TextStyle(fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(days, style: TextStyle(color: critical ? AppColors.danger : AppColors.primary, fontWeight: FontWeight.w900, fontSize: 12)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: AppColors.surfaceLight, color: critical ? AppColors.danger : AppColors.success)),
    ]),
  );

  Widget _buildCommunityReportCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
    child: const Row(children: [
      Icon(Icons.campaign, color: AppColors.primary),
      const SizedBox(width: 12),
      Expanded(child: Text('May brownout sa area niyo? Report it now to help the community.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _buildWatchlistTab() {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Monitor multiple locations para ma-alert ka agad ng scheduled maintenance at grid alerts.', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ..._watchlist.map(_watchlistCard),
            const SizedBox(height: 24),
            _infoCard('Smart Alerts Active', 'Makatanggap ng push notifications kapag may emergency sa iyong mga watchlist locations.'),
          ],
        ),
        Positioned(
          bottom: 24, right: 24,
          child: FloatingActionButton(backgroundColor: AppColors.primary, onPressed: _addWatchlistItem, child: const Icon(Icons.add, size: 32, color: Colors.black)),
        ),
      ],
    );
  }

  Widget _watchlistCard(WatchlistArea w) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF261E15), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border.withOpacity(0.5))),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.surfaceLight, shape: BoxShape.circle), child: Text(_labelIcon(w.label), style: const TextStyle(fontSize: 20))),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(w.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        Row(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text('NORMAL GRID STATUS', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
      ])),
      const Icon(Icons.chevron_right, color: AppColors.textMuted),
    ]),
  );

  Widget _infoCard(String title, String desc) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF261E15), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.info_outline, color: AppColors.primary, size: 16), const SizedBox(width: 8), Text(title, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))]),
      const SizedBox(height: 8),
      Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
    ]),
  );

  void _addWatchlistItem() {
    String name = '';
    String label = 'Home';
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF261E15),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surfaceLighter, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          const Text('📍 Add Location', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Outfit')),
          const SizedBox(height: 16),
          TextField(decoration: const InputDecoration(hintText: 'Location name (e.g., Bahay sa QC)'), onChanged: (v) => name = v),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: label, decoration: const InputDecoration(labelText: 'Label'),
            items: ['Home', 'Office', 'School', "Parent's House", 'Other'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (v) => label = v ?? 'Home'),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
            if (name.isEmpty) return;
            final w = WatchlistArea(id: 'w_${DateTime.now().millisecondsSinceEpoch}', name: name, label: label, lat: 14.5995, lng: 120.9842);
            setState(() => _watchlist.add(w));
            widget.storage.saveWatchlist(_watchlist);
            Navigator.pop(ctx);
          }, child: const Text('Add to Watchlist'))),
          const SizedBox(height: 24),
        ]),
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
