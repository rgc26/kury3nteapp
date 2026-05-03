import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import '../models/fuel_station.dart';
import '../data/mock_stations.dart';
import '../services/storage_service.dart';
import '../data/appliances_data.dart';

class FuelTrackerScreen extends StatefulWidget {
  final StorageService storage;
  const FuelTrackerScreen({super.key, required this.storage});
  @override
  State<FuelTrackerScreen> createState() => _FuelTrackerScreenState();
}

class _FuelTrackerScreenState extends State<FuelTrackerScreen> with SingleTickerProviderStateMixin {
  List<FuelStation> _stations = [];
  bool _mapView = true;
  double _radius = 5.0;
  String _sortBy = 'distance';
  bool _showCostCalc = false;
  String _vehicleType = 'Sedan';
  double _tripKm = 20;
  FuelStation? _selected;
  late TabController _tabCtrl;
  static const _center = LatLng(14.5995, 120.9842);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _stations = getMockStations();
    // Simulate distances
    final d = const Distance();
    for (var s in _stations) {
      s.distanceKm = d.as(LengthUnit.Kilometer, _center, s.location);
    }
    _stations.sort((a, b) => (a.distanceKm ?? 99).compareTo(b.distanceKm ?? 99));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _stations.where((s) => (s.distanceKm ?? 99) <= _radius).toList();
    if (_sortBy == 'price') filtered.sort((a, b) => (a.cheapestPrice ?? 999).compareTo(b.cheapestPrice ?? 999));
    final openStations = filtered.where((s) => s.status == StationStatus.open).length;
    final closedStations = filtered.where((s) => s.status == StationStatus.closed).length;

    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Text('⛽ ', style: TextStyle(fontSize: 22)), Text('Fuel Tracker')]),
        actions: [
          IconButton(icon: Icon(_mapView ? Icons.list : Icons.map), onPressed: () => setState(() => _mapView = !_mapView)),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(40), child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            _statBadge('🟢 $openStations Open', AppColors.success),
            const SizedBox(width: 8),
            _statBadge('🔴 $closedStations Closed', AppColors.danger),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)),
              child: DropdownButton<double>(value: _radius, isDense: true, underline: const SizedBox(), dropdownColor: AppColors.surface, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                items: [1, 3, 5, 10, 20].map((r) => DropdownMenuItem(value: r.toDouble(), child: Text('${r}km'))).toList(),
                onChanged: (v) => setState(() => _radius = v ?? 5)),
            ),
          ]),
        )),
      ),
      body: Column(children: [
        if (_mapView) Expanded(child: _buildMap(filtered)) else Expanded(child: _buildList(filtered)),
        _buildCostCalcPanel(),
      ]),
    );
  }

  Widget _statBadge(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: c.withAlpha(25), borderRadius: BorderRadius.circular(12)),
    child: Text(t, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
  );

  Widget _buildMap(List<FuelStation> stations) {
    return FlutterMap(
      options: MapOptions(initialCenter: _center, initialZoom: 12, onTap: (_, __) => setState(() => _selected = null)),
      children: [
        TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', subdomains: const ['a','b','c','d']),
        MarkerLayer(markers: stations.map((s) {
          final c = s.status == StationStatus.open ? AppColors.success : s.status == StationStatus.closed ? AppColors.danger : AppColors.warning;
          return Marker(point: s.location, width: 32, height: 32, child: GestureDetector(
            onTap: () => setState(() => _selected = s),
            child: Container(decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: c.withAlpha(80), blurRadius: 6)]),
              child: const Icon(Icons.local_gas_station, color: Colors.white, size: 16)),
          ));
        }).toList()),
        if (_selected != null) Positioned(child: Container()),
      ],
    );
  }

  Widget _buildList(List<FuelStation> stations) {
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [
        const Text('Sort: ', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ChoiceChip(label: const Text('Distance'), selected: _sortBy == 'distance', onSelected: (_) => setState(() => _sortBy = 'distance'), selectedColor: AppColors.primary.withAlpha(40)),
        const SizedBox(width: 8),
        ChoiceChip(label: const Text('Price'), selected: _sortBy == 'price', onSelected: (_) => setState(() => _sortBy = 'price'), selectedColor: AppColors.primary.withAlpha(40)),
        const Spacer(),
        TextButton.icon(icon: const Icon(Icons.attach_money, size: 16), label: const Text('Pinakamura', style: TextStyle(fontSize: 12)),
          onPressed: () => setState(() => _sortBy = 'price')),
      ])),
      Expanded(child: ListView.builder(itemCount: stations.length, padding: const EdgeInsets.only(bottom: 16), itemBuilder: (_, i) => _stationCard(stations[i]))),
    ]);
  }

  Widget _stationCard(FuelStation s) {
    final c = s.status == StationStatus.open ? AppColors.success : s.status == StationStatus.closed ? AppColors.danger : AppColors.warning;
    return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() { _selected = s; _mapView = true; }),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.withAlpha(25), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.local_gas_station, color: c, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(s.address, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: c.withAlpha(25), borderRadius: BorderRadius.circular(8)),
              child: Text('${s.statusEmoji} ${s.statusText}', style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600))),
            if (s.distanceKm != null) Text('${s.distanceKm!.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ]),
        if (s.status != StationStatus.closed) ...[
          const SizedBox(height: 10),
          Row(children: [
            if (s.priceUnleaded != null) _priceTag('Unleaded', s.priceUnleaded!),
            if (s.priceDiesel != null) _priceTag('Diesel', s.priceDiesel!),
            if (s.pricePremium != null) _priceTag('Premium', s.pricePremium!),
            const Spacer(),
            Text(s.queueText, style: TextStyle(fontSize: 10, color: s.queueTime == QueueTime.long1hr ? AppColors.danger : AppColors.textMuted)),
          ]),
        ],
        if (s.notes != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('ℹ️ ${s.notes}', style: const TextStyle(fontSize: 11, color: AppColors.warning, fontStyle: FontStyle.italic))),
      ])),
    ));
  }

  Widget _priceTag(String type, double price) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(type, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
      Text('₱${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
    ]),
  );

  Widget _buildCostCalcPanel() {
    return GestureDetector(
      onTap: () => setState(() => _showCostCalc = !_showCostCalc),
      child: AnimatedContainer(duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: AppColors.surfaceLight, border: Border(top: BorderSide(color: AppColors.border))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.calculate, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            const Text('Trip Cost Estimator', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const Spacer(),
            Icon(_showCostCalc ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: AppColors.textMuted),
          ]),
          if (_showCostCalc) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: _vehicleType, decoration: const InputDecoration(labelText: 'Vehicle', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                items: VehicleFuelData.kmPerLiter.keys.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _vehicleType = v ?? 'Sedan'),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                initialValue: '20', decoration: const InputDecoration(labelText: 'Distance (km)', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                keyboardType: TextInputType.number, onChanged: (v) => setState(() => _tripKm = double.tryParse(v) ?? 20),
              )),
            ]),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.local_gas_station, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text('Estimated Cost: ', style: const TextStyle(fontSize: 13)),
                Text('₱${_calcTripCost().toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
                const SizedBox(width: 8),
                Text('(${(_tripKm / (VehicleFuelData.kmPerLiter[_vehicleType] ?? 10)).toStringAsFixed(1)}L)', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  double _calcTripCost() {
    final efficiency = VehicleFuelData.kmPerLiter[_vehicleType] ?? 10;
    final liters = _tripKm / efficiency;
    final cheapest = _stations.where((s) => s.status == StationStatus.open && s.priceUnleaded != null)
      .map((s) => s.priceUnleaded!).fold<double>(999, (a, b) => a < b ? a : b);
    return liters * (cheapest < 999 ? cheapest : 65.0);
  }
}
