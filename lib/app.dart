import 'package:flutter/material.dart';
import 'dart:js' as js;
import 'theme/app_colors.dart';
import 'services/storage_service.dart';
import 'screens/brownout_map_screen.dart';
import 'screens/fuel_tracker_screen.dart';
import 'screens/energy_audit_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/bayanihan_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'services/firebase_service.dart';
import 'models/outage_report.dart';

class AppShell extends StatefulWidget {
  final StorageService storage;
  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  static final GlobalKey<AppShellState> shellKey = GlobalKey<AppShellState>();
  
  const AppShell({super.key, required this.storage});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  late AnimationController _fabAnimController;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _screens = [
      BrownoutMapScreen(key: BrownoutMapScreen.mapStateKey),
      FuelTrackerScreen(storage: widget.storage),
      EnergyAuditScreen(storage: widget.storage),
      AlertsScreen(storage: widget.storage),
      BayanihanScreen(storage: widget.storage),
      const HistoryScreen(),
    ];
    
    // Check for Device Lock security
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDeviceLock();
    });
  }

  Future<void> _checkDeviceLock() async {
    try {
      final deviceId = await widget.storage.getDeviceId();
      final firebaseService = FirebaseService();
      await firebaseService.registerDevice(deviceId);
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(children: [Icon(Icons.lock, color: AppColors.danger), SizedBox(width: 8), Text('Security Alert')]),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Understood')),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  void jumpToReport(OutageReport report) {
    setState(() => _currentIndex = 0);
    // Give the map screen time to build if it was not in the stack (IndexedStack handles this)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BrownoutMapScreen.mapStateKey.currentState?.moveToLocation(report.location, report);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    final user = firebaseService.currentUser;

    return Scaffold(
      key: AppShell.scaffoldKey,
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(user?.displayName?[0] ?? user?.email?[0] ?? '?', 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
              accountName: Text(user?.displayName ?? 'Kuryente User', style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(user?.email ?? 'No Email'),
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Live Map'),
              onTap: () {
                setState(() => _currentIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: AppColors.primary),
              title: const Text('Report History', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                setState(() => _currentIndex = 5);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(color: AppColors.border),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.install_mobile, color: AppColors.primary),
              title: const Text('Install Kuryente App', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Add to home screen', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                if (js.context.hasProperty('installPWA')) {
                  js.context.callMethod('installPWA');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please refresh the browser to enable the download button! 🔄')),
                  );
                }
              },
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Logout', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                await firebaseService.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, '/login');
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _currentIndex >= 5 ? null : Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Brownout',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_gas_station_outlined),
              activeIcon: Icon(Icons.local_gas_station),
              label: 'Fuel',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bolt_outlined),
              activeIcon: Icon(Icons.bolt),
              label: 'Audit',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Bayanihan',
            ),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0 ? _buildDashboardFab() : null,
    );
  }

  Widget _buildDashboardFab() {
    return FloatingActionButton.small(
      heroTag: 'dashboard_fab',
      backgroundColor: AppColors.surfaceLight,
      foregroundColor: AppColors.primary,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(storage: widget.storage),
          ),
        );
      },
      child: const Icon(Icons.dashboard_outlined, size: 20),
    );
  }
}
