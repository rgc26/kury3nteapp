import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/storage_service.dart';

class DashboardScreen extends StatefulWidget {
  final StorageService storage;
  const DashboardScreen({super.key, required this.storage});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, bool> _checklist = {};
  List<FuelLog> _fuelLogs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final cl = await widget.storage.getReadinessChecklist();
    final fl = await widget.storage.getFuelLogs();
    setState(() { _checklist = cl; _fuelLogs = fl; });
  }

  int get _readinessScore {
    if (_checklist.isEmpty) return 0;
    final checked = _checklist.values.where((v) => v).length;
    return ((checked / _checklist.length) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Text('📊 ', style: TextStyle(fontSize: 22)), Text('Crisis Dashboard')]),
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Readiness Score
        _buildReadinessSection(),
        const SizedBox(height: 20),
        // Outage History Chart
        _buildOutageHistoryChart(),
        const SizedBox(height: 20),
        // Fuel Spending
        _buildFuelSpending(),
        const SizedBox(height: 20),
        // National Status
        _buildNationalStatus(),
      ])),
    );
  }

  Widget _buildReadinessSection() {
    final score = _readinessScore;
    final c = score >= 70 ? AppColors.success : score >= 40 ? AppColors.warning : AppColors.danger;
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
      gradient: LinearGradient(colors: [c.withAlpha(15), AppColors.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withAlpha(60))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Circular gauge
          SizedBox(width: 80, height: 80, child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(value: score / 100, strokeWidth: 8, backgroundColor: AppColors.surfaceLighter, color: c),
            Text('$score', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c, fontFamily: 'Outfit')),
          ])),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Crisis Readiness Score', style: Theme.of(context).textTheme.headlineSmall),
            Text(score >= 70 ? '✅ Handa ka na!' : score >= 40 ? '⚠️ Kailangan pa ng preparation' : '❌ Hindi pa ready — kumpletuhin ang checklist!',
              style: TextStyle(fontSize: 12, color: c)),
          ])),
        ]),
        const SizedBox(height: 16),
        ..._checklist.entries.map((e) => CheckboxListTile(
          value: e.value, title: Text(e.key, style: const TextStyle(fontSize: 13)),
          activeColor: AppColors.primary, dense: true, contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) { setState(() => _checklist[e.key] = v ?? false); widget.storage.saveReadinessChecklist(_checklist); },
        )),
      ]),
    );
  }

  Widget _buildOutageHistoryChart() {
    // Simulated outage hours for last 7 days
    final data = [3.0, 0.0, 5.5, 2.0, 0.0, 4.0, 1.5];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final totalHours = data.fold(0.0, (a, b) => a + b);
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('⏱️ Outage History', style: Theme.of(context).textTheme.headlineSmall),
          const Spacer(),
          Text('${totalHours.toStringAsFixed(1)}h total', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
        ]),
        const Text('Hours without power (last 7 days)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 16),
        SizedBox(height: 160, child: BarChart(BarChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
              getTitlesWidget: (v, _) => Text(days[v.toInt()], style: const TextStyle(fontSize: 10, color: AppColors.textMuted)))),
          ),
          barGroups: data.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(toY: e.value, color: e.value > 3 ? AppColors.danger : e.value > 0 ? AppColors.warning : AppColors.success,
              width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
          ])).toList(),
        ))),
      ]),
    );
  }

  Widget _buildFuelSpending() {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('⛽ Fuel Spending', style: Theme.of(context).textTheme.headlineSmall),
          const Spacer(),
          TextButton.icon(icon: const Icon(Icons.add, size: 16), label: const Text('Log', style: TextStyle(fontSize: 12)), onPressed: _addFuelLog),
        ]),
        if (_fuelLogs.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No fuel logs yet.\nTap + Log to record a fill-up.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13))))
        else ...[
          Text('Total: ₱${_fuelLogs.fold(0.0, (s, l) => s + l.totalCost).toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(height: 8),
          ..._fuelLogs.reversed.take(5).map((l) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
            Text('${l.date.month}/${l.date.day}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(width: 12),
            Expanded(child: Text(l.stationName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
            Text('${l.liters.toStringAsFixed(1)}L', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(width: 8),
            Text('₱${l.totalCost.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ]))),
        ],
      ]),
    );
  }

  void _addFuelLog() {
    String station = '';
    String type = 'Unleaded';
    double liters = 10;
    double price = 65.0;
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surfaceLighter, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('⛽ Log Fuel Purchase', style: Theme.of(ctx).textTheme.headlineMedium),
          const SizedBox(height: 16),
          TextField(decoration: const InputDecoration(hintText: 'Station name', prefixIcon: Icon(Icons.local_gas_station, size: 18)), onChanged: (v) => station = v),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Liters', prefixIcon: Icon(Icons.water_drop, size: 18)),
              keyboardType: TextInputType.number, onChanged: (v) => liters = double.tryParse(v) ?? 10)),
            const SizedBox(width: 10),
            Expanded(child: TextField(decoration: const InputDecoration(hintText: '₱/Liter', prefixIcon: Icon(Icons.attach_money, size: 18)),
              keyboardType: TextInputType.number, onChanged: (v) => price = double.tryParse(v) ?? 65)),
          ]),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () {
            if (station.isEmpty) return;
            final log = FuelLog(id: 'fl_${DateTime.now().millisecondsSinceEpoch}', date: DateTime.now(), stationName: station, fuelType: type, liters: liters, pricePerLiter: price);
            setState(() => _fuelLogs.add(log));
            widget.storage.saveFuelLog(log);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Logged ₱${log.totalCost.toStringAsFixed(0)} at $station')));
          }, icon: const Icon(Icons.save), label: const Text('Save Log'))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _buildNationalStatus() {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🇵🇭 National Status', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Row(children: [
          _statusCard('Luzon Grid', '🟡', 'YELLOW'),
          const SizedBox(width: 8),
          _statusCard('Visayas Grid', '🟢', 'NORMAL'),
          const SizedBox(width: 8),
          _statusCard('Mindanao Grid', '🟢', 'NORMAL'),
        ]),
        const SizedBox(height: 12),
        _miniReserve('Gasoline', 0.62),
        _miniReserve('Diesel', 0.48),
      ]),
    );
  }

  Widget _statusCard(String grid, String emoji, String status) => Expanded(child: Container(
    padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      Text(grid, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      Text(status, style: TextStyle(fontSize: 9, color: status == 'YELLOW' ? AppColors.warning : AppColors.success, fontWeight: FontWeight.w700)),
    ]),
  ));

  Widget _miniReserve(String type, double pct) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
    SizedBox(width: 60, child: Text(type, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 6,
      backgroundColor: AppColors.surfaceLighter, color: pct > 0.5 ? AppColors.success : AppColors.warning))),
    const SizedBox(width: 8),
    Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
  ]));
}
