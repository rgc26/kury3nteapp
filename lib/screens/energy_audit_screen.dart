import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
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
  bool _isScanning = false;
  double _monthlyBillInput = 3000;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>>? _lastTipProfile;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _appliances = getDefaultAppliances();
    // Gemini key is now loaded from .env automatically in the service constructor
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabCtrl.dispose();
    super.dispose();
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
        bottom: TabBar(controller: _tabCtrl, isScrollable: false, tabs: const [
          Tab(text: '⚡ Calculator'), Tab(text: '🔌 Generator'), Tab(text: '☀️ Solar ROI'),
        ]),
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        _buildCalculator(),
        _buildGenerator(),
        _buildSolar(),
      ]),
    );
  }

  Widget _buildCalculator() {
    final selected = _appliances.where((a) => a.isSelected).toList();
    
    // Smooth instant filtering
    final List<Appliance> displayedAppliances = _searchQuery.isEmpty
        ? _appliances.where((a) => !a.isSelected).take(5).toList() // Top 5 popular
        : _appliances.where((a) => a.name.toLowerCase().contains(_searchQuery.toLowerCase()) && !a.isSelected).toList();

    return Container(
      color: AppColors.background,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          // 1. Summary Section (Horizontal Drawer Cards)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 100,
              child: Row(
                children: [
                  _drawerSummaryCard('DAILY', '${_totalDailyKwh.toStringAsFixed(2)}', 'kWh'),
                  const SizedBox(width: 8),
                  _drawerSummaryCard('MONTHLY', '${_totalMonthlyKwh.toStringAsFixed(1)}', 'kWh'),
                  const SizedBox(width: 8),
                  _drawerSummaryCard('EST. BILL', '₱${_estimatedBill.toStringAsFixed(0)}', '/mo', highlight: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          
          // 2. Search & Scan
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1B16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Hanapin ang appliance...',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_isScanning)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  else
                    IconButton(
                      icon: const Icon(Icons.camera_alt, color: AppColors.primary, size: 20),
                      onPressed: _scanAppliance,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 3. Makatipid Tips (AI) - MOVED TO TOP
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildAiTipsCard(),
          ),
          const SizedBox(height: 32),
          
          // 4. Pumili ng Appliance (Responsive Grid)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Pumili ng Appliance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Outfit')),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: displayedAppliances.length + 1,
            itemBuilder: (context, index) {
              if (index == displayedAppliances.length) return _addApplianceTile();
              return _applianceTile(displayedAppliances[index]);
            },
          ),
          const SizedBox(height: 36),
          
          // 4. Selected Usage (Editable Details)
          if (selected.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Selected Usage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Outfit')),
                  Text('${selected.length} items', style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: selected.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _usageCardItem(selected[index]),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _drawerSummaryCard(String label, String value, String unit, {bool highlight = false}) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1B16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: highlight ? AppColors.primary : AppColors.border.withOpacity(0.4), width: highlight ? 2 : 1),
        boxShadow: highlight ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 4))] : [],
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: highlight ? AppColors.primary : Colors.white, fontFamily: 'Outfit')),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1.2)),
      ]),
    ),
  );

  Widget _applianceTile(Appliance a) => GestureDetector(
    onTap: () {
      if (_appliances.any((app) => app.name.toLowerCase() == a.name.toLowerCase() && app.isSelected)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This appliance is already added.')));
        return;
      }
      setState(() { a.isSelected = true; a.hoursPerDay = 1; });
    },
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1B16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.4)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(a.icon, color: AppColors.textMuted, size: 30),
        const SizedBox(height: 8),
        Text(a.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        Text('${a.defaultWattage}W', style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
      ]),
    ),
  );

  Widget _addApplianceTile() => GestureDetector(
    onTap: _showAddApplianceModal,
    child: Container(
      width: 105,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.primary.withOpacity(0.4), style: BorderStyle.solid, width: 1.5),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.add, color: Colors.black, size: 20),
        ),
        const SizedBox(height: 10),
        const Text('Add New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary)),
      ]),
    ),
  );

  Widget _usageCardItem(Appliance a) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1F1B16),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border.withOpacity(0.4)),
    ),
    child: Column(
      children: [
        Row(children: [
          Icon(a.icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, fontFamily: 'Outfit')),
            Row(children: [
              const Icon(Icons.edit, size: 10, color: AppColors.textMuted),
              const SizedBox(width: 4),
              SizedBox(
                width: 45,
                child: TextField(
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none),
                  onChanged: (v) => setState(() => a.wattage = int.tryParse(v) ?? a.defaultWattage),
                  controller: TextEditingController(text: '${a.wattage}')..selection = TextSelection.fromPosition(TextPosition(offset: '${a.wattage}'.length)),
                ),
              ),
              const Text('W', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₱${(a.monthlyKwh * MeralcoRates.ratePerKwh).toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 14, fontFamily: 'Outfit')),
            const Text('per month', style: TextStyle(fontSize: 8, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.white24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() { a.isSelected = false; a.hoursPerDay = 0; }),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Text('Hours/Day', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w800)),
          const Spacer(),
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _roundBtn(Icons.remove, () => setState(() => a.hoursPerDay = (a.hoursPerDay - 1).clamp(0, 24))),
              SizedBox(
                width: 30,
                child: TextField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, fontFamily: 'Outfit'),
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none),
                  onChanged: (v) => setState(() => a.hoursPerDay = double.tryParse(v) ?? a.hoursPerDay),
                  controller: TextEditingController(text: a.hoursPerDay.toInt().toString())..selection = TextSelection.fromPosition(TextPosition(offset: a.hoursPerDay.toInt().toString().length)),
                ),
              ),
              _roundBtn(Icons.add, () => setState(() => a.hoursPerDay = (a.hoursPerDay + 1).clamp(0, 24))),
            ]),
          ),
        ]),
      ],
    ),
  );

  Widget _roundBtn(IconData icon, VoidCallback tap) => GestureDetector(
    onTap: tap,
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border.withOpacity(0.5))),
      child: Icon(icon, size: 14, color: Colors.white),
    ),
  );

  void _showAddApplianceModal() {
    String name = '';
    int wattage = 0;
    IconData icon = Icons.devices_other;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1612),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Text('Add Custom Appliance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Outfit')),
              const SizedBox(height: 20),
              TextField(
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Gaming Monitor, Microwave',
                  prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) {
                  name = v;
                  final lower = v.toLowerCase();
                  IconData suggested = Icons.devices_other;
                  if (lower.contains('aircon') || lower.contains('ac')) suggested = Icons.ac_unit;
                  else if (lower.contains('tv') || lower.contains('monitor')) suggested = Icons.tv;
                  else if (lower.contains('fan')) suggested = Icons.wind_power;
                  else if (lower.contains('ref') || lower.contains('fridge')) suggested = Icons.kitchen;
                  else if (lower.contains('wash') || lower.contains('dryer')) suggested = Icons.local_laundry_service;
                  else if (lower.contains('cook') || lower.contains('rice') || lower.contains('oven')) suggested = Icons.rice_bowl;
                  else if (lower.contains('comp') || lower.contains('pc') || lower.contains('laptop')) suggested = Icons.computer;
                  else if (lower.contains('light') || lower.contains('bulb')) suggested = Icons.lightbulb;
                  else if (lower.contains('iron')) suggested = Icons.iron;
                  
                  setModalState(() => icon = suggested);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Wattage',
                  suffixText: 'Watts',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) => wattage = int.tryParse(v) ?? 0,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (name.trim().isEmpty || wattage <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid name and wattage.')));
                      return;
                    }
                    if (_appliances.any((a) => a.name.toLowerCase() == name.trim().toLowerCase())) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('An appliance with this name already exists.')));
                      return;
                    }
                    setState(() {
                      _appliances.add(Appliance(name: name.trim(), icon: icon, wattage: wattage, defaultWattage: wattage, isSelected: true, hoursPerDay: 1));
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Add to List', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiTipsCard() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF1F1B16),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.success.withOpacity(0.35), width: 1.5),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.auto_awesome, color: AppColors.success, size: 20),
        ),
        title: const Text('Makatipid Tips (AI)', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.success, fontSize: 16, fontFamily: 'Outfit')),
        onExpansionChanged: (expanded) {
          if (expanded) {
            final currentProfile = _appliances.where((a) => a.isSelected).map((a) => {'name': a.name, 'wattage': a.wattage, 'hoursPerDay': a.hoursPerDay}).toList();
            bool profileChanged = _lastTipProfile == null || _lastTipProfile!.length != currentProfile.length;
            if (!profileChanged && _lastTipProfile != null) {
              for (int i = 0; i < currentProfile.length; i++) {
                if (currentProfile[i]['name'] != _lastTipProfile![i]['name'] || 
                    currentProfile[i]['wattage'] != _lastTipProfile![i]['wattage'] || 
                    currentProfile[i]['hoursPerDay'] != _lastTipProfile![i]['hoursPerDay']) {
                  profileChanged = true; break;
                }
              }
            }
            if (profileChanged || _aiTips.isEmpty) {
              _lastTipProfile = currentProfile;
              _generateTips();
            }
          }
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: _loadingTips 
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.success, strokeWidth: 3)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_aiTips.isNotEmpty)
                      ..._aiTips.split('\n').where((s) => s.trim().isNotEmpty).map((tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(margin: const EdgeInsets.only(top: 4), width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(tip.replaceAll(RegExp(r'^[-*•]\s*'), ''), style: const TextStyle(fontSize: 13.5, height: 1.6, fontWeight: FontWeight.w500, color: Colors.white))),
                          ],
                        ),
                      ))
                    else
                      const Center(child: Text('Pumili ng appliances para makakuha ng tips!', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600))),
                  ],
                ),
          ),
        ],
      ),
    ),
  );

  Widget _tipItem(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [Icon(icon, size: 16, color: AppColors.success), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontSize: 12)))]),
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
    try {
      final profile = _appliances.where((a) => a.isSelected).map((a) => {'name': a.name, 'wattage': a.wattage, 'hoursPerDay': a.hoursPerDay}).toList();
      if (profile.isEmpty) {
        setState(() { _aiTips = 'Pumili muna ng appliances sa Calculator tab! 👆'; _loadingTips = false; });
        return;
      }
      
      final tips = await _gemini.generateTips(
        applianceProfile: profile, 
        totalDailyKwh: _totalDailyKwh, 
        estimatedMonthlyBill: _estimatedBill
      );
      
      setState(() { _aiTips = tips; _loadingTips = false; });
    } catch (e) {
      debugPrint('AI Tip Generation Error: $e');
      setState(() {
        _aiTips = 'Unable to generate AI tips right now. Please check your API key or use the manual calculator.';
        _loadingTips = false;
      });
    }
  }

  Widget _buildGenerator() {
    final essentials = _appliances.where((a) => a.isSelected).toList();
    final totalW = _totalWatts;
    final recommendedKva = (totalW * 1.25 / 1000).ceilToDouble();
    return Container(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _genStatCard('Items', essentials.length.toString()),
              const SizedBox(width: 12),
              _genStatCard('Total Load', '${totalW.toStringAsFixed(0)}W'),
              const SizedBox(width: 12),
              _genStatCard('Peak Load', '${(totalW * 1.25).toStringAsFixed(0)}W', suffix: '+25%'),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF261E15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 20)],
            ),
            child: Column(
              children: [
                const Text('RECOMMENDED CAPACITY', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text('${recommendedKva.toStringAsFixed(1)} kVA', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, fontFamily: 'Outfit')),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Market Standards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
          const SizedBox(height: 16),
          _marketStandardCard('2.0 kVA', '₱15k - ₱25k', ['Fan', 'Lights', 'Charge'], Icons.bolt, recommendedKva <= 2),
          const SizedBox(height: 12),
          _marketStandardCard('3.5 kVA', '₱25k - ₱40k', ['Ref', 'TV', 'Laptop'], Icons.power, recommendedKva > 2 && recommendedKva <= 3.5),
          const SizedBox(height: 12),
          _marketStandardCard('5.0 kVA', '₱40k - ₱60k', ['Aircon', 'Wash'], Icons.settings_input_component, recommendedKva > 3.5 && recommendedKva <= 5),
          const SizedBox(height: 32),
          const Text('Select your essential appliances sa Calculator tab to calculate the capacity needed.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _genStatCard(String label, String value, {String? suffix}) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF261E15), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border.withOpacity(0.5))),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        Text(label + (suffix ?? ''), style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
      ]),
    ),
  );

  Widget _marketStandardCard(String size, String price, List<String> chips, IconData icon, bool recommended) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF261E15),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: recommended ? AppColors.primary : AppColors.border.withOpacity(0.5), width: recommended ? 2 : 1),
    ),
    child: Row(children: [
      Icon(icon, color: recommended ? AppColors.primary : AppColors.textMuted, size: 32),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(size, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (recommended) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)), child: const Text('RECOMMENDED', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900))),
        ]),
        Text(price, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 4, children: chips.map((c) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(4)), child: Text(c, style: const TextStyle(fontSize: 9)))).toList()),
      ])),
    ]),
  );

  Widget _buildSolar() {
    final systemKw = _monthlyBillInput / (MeralcoRates.ratePerKwh * 30) * 24 / 4.5;
    final systemCost = systemKw * 55000;
    final annualSavings = (_monthlyBillInput * 12) * 0.7;
    final paybackYears = systemCost / annualSavings;
    return Container(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: Text('AVERAGE MONTHLY MERALCO BILL', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2))),
          const SizedBox(height: 8),
          Center(child: Text('₱${_monthlyBillInput.toStringAsFixed(0)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'Outfit'))),
          Slider(value: _monthlyBillInput, min: 500, max: 20000, activeColor: AppColors.primary, onChanged: (v) => setState(() => _monthlyBillInput = v)),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: [
              _solarStatCard('System Size', '${systemKw.toStringAsFixed(1)} kW', Icons.solar_power),
              _solarStatCard('Panels', '${(systemKw * 1000 / 450).ceil()} pcs', Icons.grid_view),
              _solarStatCard('Est. Cost', '₱${(systemCost / 1000).toStringAsFixed(0)}k', Icons.payments),
              _solarStatCard('Ann. Savings', '₱${(annualSavings / 1000).toStringAsFixed(0)}k', Icons.trending_down),
            ],
          ),
          const SizedBox(height: 24),
          _solarHeroCard(paybackYears),
          const SizedBox(height: 32),
          const Text('Savings Growth', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: LineChart(_solarChartData(annualSavings, systemCost))),
          const SizedBox(height: 24),
          _buildAssumptionsCard(),
        ],
      ),
    );
  }

  Widget _solarStatCard(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFF261E15), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border.withOpacity(0.5))),
    child: Row(children: [
      Icon(icon, color: AppColors.primary, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
      ])),
    ]),
  );

  Widget _solarHeroCard(double years) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFF261E15),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.primary, width: 2),
      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 20)],
    ),
    child: Column(children: [
      const Text('INVESTMENT RECOVERY', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      const SizedBox(height: 8),
      Text('${years.toStringAsFixed(1)} Years', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.primary)),
    ]),
  );

  LineChartData _solarChartData(double annualSavings, double systemCost) => LineChartData(
    gridData: const FlGridData(show: false),
    borderData: FlBorderData(show: false),
    titlesData: const FlTitlesData(show: false),
    lineBarsData: [
      LineChartBarData(
        spots: List.generate(11, (i) => FlSpot(i.toDouble(), (annualSavings * i - systemCost) / 1000)),
        isCurved: true,
        color: AppColors.primary,
        barWidth: 4,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.4), AppColors.primary.withOpacity(0)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
      ),
    ],
  );

  Widget _buildAssumptionsCard() => Container(
    decoration: BoxDecoration(color: const Color(0xFF261E15), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border.withOpacity(0.5))),
    child: ExpansionTile(
      title: const Text('Audit Assumptions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _assumptionItem('Peak Sun Hours', '4.5 hrs/day (PH average)'),
            _assumptionItem('System Efficiency', '85% (Performance Ratio)'),
            _assumptionItem('Panel Rating', '450W Mono-PERC'),
            _assumptionItem('Grid Export', '70% Self-consumption'),
          ]),
        ),
      ],
    ),
  );

  Widget _assumptionItem(String l, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );

  Future<void> _scanAppliance() async {
    // Check if Gemini is configured first
    if (!_gemini.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ AI not configured. Check your Gemini API key.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    
    if (photo == null) return;

    setState(() => _isScanning = true);
    
    final bytes = await photo.readAsBytes();
    debugPrint('Scan: Captured image with ${bytes.length} bytes');
    final result = await _gemini.analyzeApplianceImage(bytes);
    
    setState(() => _isScanning = false);

    if (result.containsKey('data')) {
      _showScanResultModal(result['data']);
    } else {
      final errorMsg = result['error'] ?? 'Unknown error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ $errorMsg'),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 6),
      ));
    }
  }

  void _showScanResultModal(Map<String, dynamic> data) {
    IconData iconData;
    switch (data['icon_key']) {
      case 'ac': iconData = Icons.ac_unit; break;
      case 'tv': iconData = Icons.tv; break;
      case 'ref': iconData = Icons.kitchen; break;
      case 'fan': iconData = Icons.wind_power; break;
      case 'wash': iconData = Icons.local_laundry_service; break;
      case 'cook': iconData = Icons.rice_bowl; break;
      case 'pc': iconData = Icons.computer; break;
      default: iconData = Icons.devices_other;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1612),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('AI Identification Result', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Outfit')),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Icon(iconData, color: AppColors.primary, size: 40),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('${data['wattage']} Watts', style: const TextStyle(color: AppColors.textMuted)),
                ])),
              ]),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final int watts = (data['wattage'] is int) 
                      ? data['wattage'] 
                      : int.tryParse(data['wattage'].toString()) ?? 100;
                  setState(() {
                    _appliances.add(Appliance(
                      name: data['name'] ?? 'Unknown Appliance',
                      icon: iconData,
                      wattage: watts,
                      defaultWattage: watts,
                      isSelected: true,
                      hoursPerDay: 1,
                    ));
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ ${data['name']} added to calculator!')),
                  );
                },
                child: const Text('Add to Calculator'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
