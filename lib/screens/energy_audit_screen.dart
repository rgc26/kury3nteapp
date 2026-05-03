import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_colors.dart';
import '../models/app_models.dart';
import '../data/appliances_data.dart';
import '../services/storage_service.dart';
import '../services/gemini_service.dart';

class EnergyAuditScreen extends StatefulWidget {
  final StorageService storage;
  const EnergyAuditScreen({super.key, required this.storage});
  @override
  State<EnergyAuditScreen> createState() => _EnergyAuditScreenState();
}

class _EnergyAuditScreenState extends State<EnergyAuditScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Appliance> _appliances = [];
  final _gemini = GeminiService();
  String _aiTips = '';
  bool _loadingTips = false;
  double _monthlyBillInput = 3000;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _appliances = getDefaultAppliances();
    _loadGeminiKey();
  }

  Future<void> _loadGeminiKey() async {
    final key = await widget.storage.getGeminiApiKey();
    if (key != null && key.isNotEmpty) _gemini.configure(key);
  }

  double get _totalDailyKwh => _appliances.where((a) => a.isSelected).fold(0, (s, a) => s + a.dailyKwh);
  double get _totalMonthlyKwh => _totalDailyKwh * 30;
  double get _estimatedBill => MeralcoRates.calculateMonthlyBill(_totalMonthlyKwh);
  double get _totalWatts => _appliances.where((a) => a.isSelected).fold(0, (s, a) => s + a.wattage);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Text('🔋 ', style: TextStyle(fontSize: 22)), Text('Energy Audit')]),
        bottom: TabBar(controller: _tabCtrl, isScrollable: true, tabs: const [
          Tab(text: '⚡ Calculator'), Tab(text: '💡 Makatipid Tips'), Tab(text: '🔌 Generator'), Tab(text: '☀️ Solar ROI'),
        ]),
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        _buildCalculator(),
        _buildTips(),
        _buildGenerator(),
        _buildSolar(),
      ]),
    );
  }

  Widget _buildCalculator() {
    final selected = _appliances.where((a) => a.isSelected).toList();
    return Column(children: [
      // Summary bar
      Container(padding: const EdgeInsets.all(16), color: AppColors.surfaceLight, child: Row(children: [
        _summaryItem('Daily', '${_totalDailyKwh.toStringAsFixed(2)} kWh'),
        _summaryItem('Monthly', '${_totalMonthlyKwh.toStringAsFixed(1)} kWh'),
        _summaryItem('Est. Bill', '₱${_estimatedBill.toStringAsFixed(0)}'),
      ])),
      // Appliance grid
      Expanded(child: GridView.builder(
        padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.85),
        itemCount: _appliances.length, itemBuilder: (_, i) => _applianceTile(_appliances[i]),
      )),
      // Selected appliance sliders
      if (selected.isNotEmpty) Container(
        height: 140, padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView(scrollDirection: Axis.horizontal, children: selected.map((a) => _sliderCard(a)).toList()),
      ),
    ]);
  }

  Widget _summaryItem(String label, String value) => Expanded(child: Column(children: [
    Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
    Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
  ]));

  Widget _applianceTile(Appliance a) => GestureDetector(
    onTap: () => setState(() { a.isSelected = !a.isSelected; if (!a.isSelected) a.hoursPerDay = 0; else a.hoursPerDay = 4; }),
    child: AnimatedContainer(duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: a.isSelected ? AppColors.primary.withAlpha(20) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: a.isSelected ? AppColors.primary : AppColors.border, width: a.isSelected ? 2 : 1),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(a.icon, color: a.isSelected ? AppColors.primary : AppColors.textMuted, size: 28),
        const SizedBox(height: 6),
        Text(a.name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: a.isSelected ? AppColors.textPrimary : AppColors.textMuted), textAlign: TextAlign.center, maxLines: 2),
        Text('${a.defaultWattage}W', style: TextStyle(fontSize: 9, color: a.isSelected ? AppColors.primary : AppColors.textMuted)),
        if (a.isSelected) Text('${a.dailyKwh.toStringAsFixed(2)} kWh/day', style: const TextStyle(fontSize: 8, color: AppColors.warning)),
      ]),
    ),
  );

  Widget _sliderCard(Appliance a) => Container(width: 160, margin: const EdgeInsets.only(right: 8, bottom: 8),
    padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(a.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1),
      Text('${a.wattage}W × ${a.hoursPerDay.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      Slider(value: a.hoursPerDay, min: 0, max: 24, divisions: 48, label: '${a.hoursPerDay.toStringAsFixed(1)}h',
        onChanged: (v) => setState(() => a.hoursPerDay = v)),
      Text('₱${(a.monthlyKwh * MeralcoRates.ratePerKwh).toStringAsFixed(0)}/mo', style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _buildTips() {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary.withAlpha(25), AppColors.accent.withAlpha(15)]),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withAlpha(60))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.auto_awesome, color: AppColors.primary, size: 20), SizedBox(width: 8), Text('Makatipid Tips', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))]),
          const SizedBox(height: 8),
          Text(_gemini.isConfigured ? 'AI-powered personalized tips gamit ang Gemini' : 'Pre-built energy saving tips (set Gemini API key sa Settings para sa personalized tips)', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _loadingTips ? null : _generateTips,
            icon: _loadingTips ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome, size: 16),
            label: Text(_loadingTips ? 'Generating...' : 'Generate Tips'),
          )),
        ]),
      ),
      const SizedBox(height: 16),
      if (_aiTips.isNotEmpty) ...[
        Text('💡 Personalized Tips', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Text(_aiTips, style: const TextStyle(fontSize: 13, height: 1.6, color: AppColors.textPrimary))),
      ],
      // Gemini key input
      const SizedBox(height: 20),
      Text('🔑 Gemini API Key', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      TextField(decoration: const InputDecoration(hintText: 'Paste your Gemini API key here', prefixIcon: Icon(Icons.key, size: 18)),
        obscureText: true,
        onSubmitted: (v) async { _gemini.configure(v); await widget.storage.saveGeminiApiKey(v);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ API key saved!'))); setState(() {}); }),
    ]));
  }

  Future<void> _generateTips() async {
    setState(() => _loadingTips = true);
    final profile = _appliances.where((a) => a.isSelected).map((a) => {'name': a.name, 'wattage': a.wattage, 'hoursPerDay': a.hoursPerDay}).toList();
    if (profile.isEmpty) {
      setState(() { _aiTips = 'Pumili muna ng appliances sa Calculator tab! 👆'; _loadingTips = false; });
      return;
    }
    final tips = await _gemini.generateTips(applianceProfile: profile, totalDailyKwh: _totalDailyKwh, estimatedMonthlyBill: _estimatedBill);
    setState(() { _aiTips = tips; _loadingTips = false; });
  }

  Widget _buildGenerator() {
    final essentials = _appliances.where((a) => a.isSelected).toList();
    final totalW = _totalWatts;
    final recommendedKva = (totalW * 1.25 / 1000).ceilToDouble(); // 25% headroom
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('🔌 Generator Sizing Tool', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text('Select your essential appliances sa Calculator tab, then check here kung anong size ng generator ang kailangan mo.', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          _genRow('Selected Appliances', '${essentials.length} items'),
          _genRow('Total Wattage', '${totalW.toStringAsFixed(0)}W'),
          _genRow('With 25% Headroom', '${(totalW * 1.25).toStringAsFixed(0)}W'),
          const Divider(color: AppColors.border),
          _genRow('Recommended Generator', '${recommendedKva.toStringAsFixed(1)} kVA', highlight: true),
        ]),
      ),
      const SizedBox(height: 16),
      Text('📋 Common Generator Sizes', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      _genOption('2 kVA', '₱15,000 - ₱25,000', 'Fan, lights, phone charging', recommendedKva <= 2),
      _genOption('3.5 kVA', '₱25,000 - ₱40,000', '+ Ref, TV, laptop', recommendedKva > 2 && recommendedKva <= 3.5),
      _genOption('5 kVA', '₱40,000 - ₱60,000', '+ 1 aircon, washing machine', recommendedKva > 3.5 && recommendedKva <= 5),
      _genOption('7.5+ kVA', '₱60,000 - ₱100,000', 'Full house backup', recommendedKva > 5),
    ]));
  }

  Widget _genRow(String l, String v, {bool highlight = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      Text(v, style: TextStyle(fontSize: highlight ? 18 : 14, fontWeight: highlight ? FontWeight.w700 : FontWeight.w600, color: highlight ? AppColors.primary : AppColors.textPrimary)),
    ]),
  );

  Widget _genOption(String size, String price, String desc, bool recommended) => Container(
    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: recommended ? AppColors.primary.withAlpha(15) : AppColors.surface, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: recommended ? AppColors.primary : AppColors.border, width: recommended ? 2 : 1)),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text(size, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), if (recommended) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)), child: const Text('RECOMMENDED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.background)))]),
        Text(price, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
        Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ]),
    ]),
  );

  Widget _buildSolar() {
    final annualBill = _monthlyBillInput * 12;
    final systemKw = _monthlyBillInput / (MeralcoRates.ratePerKwh * 30) * 24 / 4.5; // 4.5 peak sun hours PH
    final systemCost = systemKw * 55000; // ~₱55k per kW installed
    final annualSavings = annualBill * 0.7; // 70% offset
    final paybackYears = systemCost / annualSavings;

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('☀️ Solar ROI Calculator', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text('Compute ang payback period ng solar installation base sa monthly bill mo.', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 16),
      Text('Monthly Meralco Bill', style: Theme.of(context).textTheme.titleMedium),
      Slider(value: _monthlyBillInput, min: 500, max: 20000, divisions: 39, label: '₱${_monthlyBillInput.toStringAsFixed(0)}',
        onChanged: (v) => setState(() => _monthlyBillInput = v)),
      Center(child: Text('₱${_monthlyBillInput.toStringAsFixed(0)} / month', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary))),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          _genRow('System Size Needed', '${systemKw.toStringAsFixed(1)} kW'),
          _genRow('Estimated Cost', '₱${systemCost.toStringAsFixed(0)}'),
          _genRow('Annual Savings', '₱${annualSavings.toStringAsFixed(0)}'),
          const Divider(color: AppColors.border),
          _genRow('Payback Period', '${paybackYears.toStringAsFixed(1)} years', highlight: true),
        ]),
      ),
      const SizedBox(height: 16),
      // Simple savings chart
      SizedBox(height: 200, child: LineChart(LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30,
            getTitlesWidget: (v, _) => Text('Yr ${v.toInt()}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)))),
        ),
        lineBarsData: [
          LineChartBarData(spots: List.generate(11, (i) => FlSpot(i.toDouble(), (annualSavings * i - systemCost) / 1000)),
            isCurved: true, color: AppColors.primary, barWidth: 3, dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: AppColors.primary.withAlpha(30))),
          LineChartBarData(spots: List.generate(11, (i) => FlSpot(i.toDouble(), 0)),
            color: AppColors.textMuted, barWidth: 1, dashArray: [5, 5], dotData: const FlDotData(show: false)),
        ],
      ))),
      const Center(child: Text('Cumulative Net Savings (₱ thousands)', style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
    ]));
  }
}
