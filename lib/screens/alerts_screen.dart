import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/meralco_schedule.dart';
import '../models/app_models.dart';
import '../services/meralco_scraper.dart';
import '../services/storage_service.dart';

class AlertsScreen extends StatefulWidget {
  final StorageService storage;
  const AlertsScreen({super.key, required this.storage});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with SingleTickerProviderStateMixin {
  final _scraper = MeralcoScraper();
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
      setState(() {
        _schedules = results[0] as List<MeralcoSchedule>;
        _alerts = results[1] as List<AlertArea>;
        _watchlist = results[2] as List<WatchlistArea>;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = 'Failed to load Meralco data. Check connection.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
    if (_loading) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: AppColors.primary),
      SizedBox(height: 16),
      Text('Fetching from company.meralco.com.ph...', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
    ]));
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.wifi_off, color: AppColors.danger, size: 48),
      const SizedBox(height: 16),
      Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
    ]));

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        // Live data badge
        Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AppColors.success.withAlpha(15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.success.withAlpha(60))),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Expanded(child: Text('LIVE DATA — Scraped from company.meralco.com.ph', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600))),
            Text('${_schedules.length} schedules', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
        if (_schedules.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(32),
          child: Text('No maintenance schedules found.\nPull down to refresh.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)))),
        ..._schedules.map(_scheduleCard),
        if (_alerts.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('🔴 Red/Yellow Alert Areas', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          ..._alerts.take(10).map(_alertAreaCard),
        ],
      ]),
    );
  }

  Widget _scheduleCard(MeralcoSchedule s) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: AppColors.warning.withAlpha(25), borderRadius: BorderRadius.circular(8)),
          child: Text('🟡 ${s.date}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning))),
        const Spacer(),
        Text(s.location, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ]),
      const SizedBox(height: 8),
      Row(children: [const Icon(Icons.schedule, size: 14, color: AppColors.primary), const SizedBox(width: 6),
        Expanded(child: Text(s.timeRange, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))]),
      const SizedBox(height: 6),
      Text(s.affectedAreas, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4), maxLines: 4, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 6),
      Row(children: [const Icon(Icons.info_outline, size: 12, color: AppColors.textMuted), const SizedBox(width: 4),
        Expanded(child: Text(s.reason, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic)))]),
    ])),
  );

  Widget _alertAreaCard(AlertArea a) => Card(
    margin: const EdgeInsets.only(bottom: 6),
    child: ExpansionTile(
      leading: Text(a.alertEmoji, style: const TextStyle(fontSize: 18)),
      title: Text(a.city, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text('${a.province} • ${a.barangays.length} barangays', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      children: [
        Padding(padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          child: Wrap(spacing: 6, runSpacing: 4, children: a.barangays.map((b) => Chip(
            label: Text(b, style: const TextStyle(fontSize: 10)),
            backgroundColor: AppColors.surfaceLight, padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )).toList())),
      ],
    ),
  );

  Widget _buildGridTab() {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('⚡ NGCP Grid Outlook', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text('Simulated data based on NGCP daily outlook format', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 16),
      _gridCard('Luzon Grid', AlertLevel.yellow, '12,450 MW', '11,800 MW', '650 MW', 'Thin power reserves due to plant outages'),
      _gridCard('Visayas Grid', AlertLevel.green, '2,800 MW', '2,200 MW', '600 MW', 'Adequate supply'),
      _gridCard('Mindanao Grid', AlertLevel.green, '3,100 MW', '2,500 MW', '600 MW', 'Normal operations'),
      const SizedBox(height: 24),
      Text('🛢️ National Fuel Reserve', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      _fuelReserveBar('Gasoline', 0.62, '45 days'),
      _fuelReserveBar('Diesel', 0.48, '32 days'),
      _fuelReserveBar('LPG', 0.71, '52 days'),
    ]));
  }

  Widget _gridCard(String grid, AlertLevel level, String capacity, String demand, String reserve, String note) {
    final c = level == AlertLevel.red ? AppColors.danger : level == AlertLevel.yellow ? AppColors.warning : AppColors.success;
    final emoji = level == AlertLevel.red ? '🔴' : level == AlertLevel.yellow ? '🟡' : '🟢';
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text(grid, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withAlpha(25), borderRadius: BorderRadius.circular(12)),
          child: Text('$emoji ${level.name.toUpperCase()}', style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)))]),
      const SizedBox(height: 12),
      Row(children: [
        _gridStat('Capacity', capacity), _gridStat('Demand', demand), _gridStat('Reserve', reserve),
      ]),
      const SizedBox(height: 8),
      Text(note, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
    ])));
  }

  Widget _gridStat(String l, String v) => Expanded(child: Column(children: [
    Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    Text(l, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
  ]));

  Widget _fuelReserveBar(String type, double pct, String days) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text(type, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), const Spacer(), Text(days, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600))]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: pct, minHeight: 10,
        backgroundColor: AppColors.surfaceLighter, color: pct > 0.5 ? AppColors.success : pct > 0.3 ? AppColors.warning : AppColors.danger)),
      Text('${(pct * 100).toStringAsFixed(0)}% of 60-day target', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
    ]),
  );

  Widget _buildWatchlistTab() {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Expanded(child: Text('Monitor multiple locations para ma-alert ka agad.', style: Theme.of(context).textTheme.bodyMedium)),
        FloatingActionButton.small(heroTag: 'add_watch', onPressed: _addWatchlistItem, child: const Icon(Icons.add)),
      ])),
      Expanded(child: _watchlist.isEmpty
        ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_off, color: AppColors.textMuted, size: 48),
            SizedBox(height: 12),
            Text('No locations added yet', style: TextStyle(color: AppColors.textMuted)),
            Text('Tap + to add your home, office, etc.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ]))
        : ListView.builder(itemCount: _watchlist.length, itemBuilder: (_, i) {
            final w = _watchlist[i];
            return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: ListTile(
              leading: CircleAvatar(backgroundColor: AppColors.primary.withAlpha(25), child: Text(_labelIcon(w.label), style: const TextStyle(fontSize: 18))),
              title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(w.label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              trailing: IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                onPressed: () { setState(() => _watchlist.removeAt(i)); widget.storage.saveWatchlist(_watchlist); }),
            ));
          }),
      ),
    ]);
  }

  String _labelIcon(String label) {
    switch (label.toLowerCase()) {
      case 'home': return '🏠';
      case 'office': return '🏢';
      case 'school': return '🏫';
      default: return '📍';
    }
  }

  void _addWatchlistItem() {
    String name = '';
    String label = 'Home';
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surfaceLighter, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('📍 Add Location to Watchlist', style: Theme.of(ctx).textTheme.headlineMedium),
          const SizedBox(height: 16),
          TextField(decoration: const InputDecoration(hintText: 'Location name (e.g., Bahay sa QC)', prefixIcon: Icon(Icons.location_on, size: 20)),
            onChanged: (v) => name = v),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: label, decoration: const InputDecoration(labelText: 'Label', prefixIcon: Icon(Icons.label, size: 20)),
            items: ['Home', 'Office', 'School', "Parent's House", 'Other'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (v) => label = v ?? 'Home'),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () {
            if (name.isEmpty) return;
            final w = WatchlistArea(id: 'w_${DateTime.now().millisecondsSinceEpoch}', name: name, label: label, lat: 14.5995, lng: 120.9842);
            setState(() => _watchlist.add(w));
            widget.storage.saveWatchlist(_watchlist);
            Navigator.pop(ctx);
          }, icon: const Icon(Icons.add_location), label: const Text('Add to Watchlist'))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}
