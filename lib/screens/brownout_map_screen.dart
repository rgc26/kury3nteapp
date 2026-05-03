import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import '../models/outage_report.dart';
import '../data/mock_outages.dart';
import '../services/storage_service.dart';

class BrownoutMapScreen extends StatefulWidget {
  final StorageService storage;
  const BrownoutMapScreen({super.key, required this.storage});
  @override
  State<BrownoutMapScreen> createState() => _BrownoutMapScreenState();
}

class _BrownoutMapScreenState extends State<BrownoutMapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  List<OutageReport> _outages = [];
  bool _showHeatmap = false;
  OutageReport? _selected;
  late AnimationController _pulse;
  static const _center = LatLng(14.5995, 120.9842);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _load();
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  Future<void> _load() async {
    final user = await widget.storage.getOutageReports();
    setState(() => _outages = [...getMockOutages(), ...user]);
  }

  @override
  Widget build(BuildContext context) {
    final noP = _outages.where((o) => o.status == OutageStatus.nopower).length;
    final sched = _outages.where((o) => o.status == OutageStatus.scheduled).length;
    final rest = _outages.where((o) => o.status == OutageStatus.restored).length;
    return Scaffold(
      body: Stack(children: [
        FlutterMap(mapController: _mapController, options: MapOptions(
          initialCenter: _center, initialZoom: 11, minZoom: 8, maxZoom: 18,
          onTap: (_, __) => setState(() => _selected = null),
        ), children: [
          TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', subdomains: const ['a','b','c','d']),
          MarkerLayer(markers: _outages.map(_marker).toList()),
          if (_showHeatmap) CircleLayer(circles: _outages.where((o) => o.status == OutageStatus.nopower)
            .map((o) => CircleMarker(point: o.location, radius: 40, color: AppColors.danger.withAlpha(40), borderColor: AppColors.danger.withAlpha(80), borderStrokeWidth: 1)).toList()),
        ]),
        // Top stats
        Positioned(top: 0, left: 0, right: 0, child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 16, right: 16, bottom: 12),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.background.withAlpha(230), AppColors.background.withAlpha(0)])),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('⚡', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text('Kuryente', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.primary, fontFamily: 'Outfit')),
              const Spacer(),
              Text('Live Map', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _chip('🔴 $noP', 'No Power', AppColors.danger),
              const SizedBox(width: 8),
              _chip('🟡 $sched', 'Scheduled', AppColors.warning),
              const SizedBox(width: 8),
              _chip('🟢 $rest', 'Restored', AppColors.success),
            ]),
          ]),
        )),
        // Controls
        Positioned(top: MediaQuery.of(context).padding.top + 70, right: 16, child: Column(children: [
          _ctrlBtn(Icons.layers, 'Heat', _showHeatmap, () => setState(() => _showHeatmap = !_showHeatmap)),
          const SizedBox(height: 8),
          _ctrlBtn(Icons.my_location, 'Me', false, () => _mapController.move(_center, 13)),
        ])),
        // Detail card
        if (_selected != null) Positioned(bottom: 16, left: 16, right: 16, child: _detail(_selected!)),
        // Report button
        Positioned(bottom: _selected != null ? 200 : 16, left: 0, right: 0, child: Center(child: ElevatedButton.icon(
          onPressed: _report, icon: const Icon(Icons.flash_off, size: 18), label: const Text('Report Brownout'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 8, shadowColor: AppColors.danger.withAlpha(100)),
        ))),
      ]),
    );
  }

  Widget _chip(String e, String l, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: c.withAlpha(30), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withAlpha(80))),
    child: Text('$e $l', style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
  );

  Widget _ctrlBtn(IconData ic, String l, bool active, VoidCallback tap) => GestureDetector(onTap: tap, child: Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: active ? AppColors.primary.withAlpha(40) : AppColors.surface.withAlpha(220), borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? AppColors.primary : AppColors.border)),
    child: Column(children: [Icon(ic, color: active ? AppColors.primary : AppColors.textSecondary, size: 20), Text(l, style: TextStyle(color: active ? AppColors.primary : AppColors.textMuted, fontSize: 9))]),
  ));

  Marker _marker(OutageReport o) {
    final c = o.status == OutageStatus.nopower ? AppColors.danger : o.status == OutageStatus.scheduled ? AppColors.warning : AppColors.success;
    final ic = o.status == OutageStatus.nopower ? Icons.flash_off : o.status == OutageStatus.scheduled ? Icons.schedule : Icons.flash_on;
    return Marker(point: o.location, width: 36, height: 36, child: GestureDetector(
      onTap: () => setState(() => _selected = o),
      child: AnimatedBuilder(animation: _pulse, builder: (_, ch) => Transform.scale(scale: o.status == OutageStatus.nopower ? 1.0 + _pulse.value * 0.12 : 1.0, child: ch),
        child: Container(decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.withAlpha(100), blurRadius: 8, spreadRadius: 2)]),
          child: Icon(ic, color: Colors.white, size: 18))),
    ));
  }

  Widget _detail(OutageReport o) {
    final c = o.status == OutageStatus.nopower ? AppColors.danger : o.status == OutageStatus.scheduled ? AppColors.warning : AppColors.success;
    final st = o.status == OutageStatus.nopower ? '🔴 Walang Kuryente' : o.status == OutageStatus.scheduled ? '🟡 Scheduled' : '🟢 Restored';
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withAlpha(100)), boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 20, offset: const Offset(0, -4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.withAlpha(30), borderRadius: BorderRadius.circular(12)),
            child: Text(st, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600))),
          const Spacer(),
          if (o.isVerified) const Icon(Icons.verified, color: AppColors.accent, size: 16),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _selected = null), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ]),
        const SizedBox(height: 8),
        Text(o.areaName ?? 'Unknown', style: Theme.of(context).textTheme.titleLarge),
        if (o.barangay != null) Text('Brgy. ${o.barangay}, ${o.city ?? ""}', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.timer, size: 14, color: AppColors.textMuted), const SizedBox(width: 4),
          Text(o.durationText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Icon(Icons.people, size: 14, color: AppColors.textMuted), const SizedBox(width: 4),
          Text('${o.reporterCount} reports', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
        if (o.notes != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(o.notes!, style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }

  void _report() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        String? notes;
        return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surfaceLighter, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('🔴 I-report ang Brownout', style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('I-confirm na walang kuryente sa location mo.', style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(decoration: const InputDecoration(hintText: 'Notes (optional)', prefixIcon: Icon(Icons.notes, size: 20)), onChanged: (v) => notes = v),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: () {
                final r = OutageReport(id: 'u_${DateTime.now().millisecondsSinceEpoch}', location: _center, status: OutageStatus.nopower, reportedAt: DateTime.now(), areaName: 'My Location', notes: notes);
                widget.storage.saveOutageReport(r);
                setState(() => _outages.add(r));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Brownout reported! Salamat! 🙏')));
              },
              icon: const Icon(Icons.send), label: const Text('I-submit'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
            )),
            const SizedBox(height: 20),
          ]),
        );
      });
  }
}
