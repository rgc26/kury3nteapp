import 'package:flutter/material.dart';
import 'dart:js' as js;
import 'theme/app_colors.dart';
import 'services/storage_service.dart';
import 'screens/brownout_map_screen.dart';
import 'screens/fuel_tracker_screen.dart';
import 'screens/energy_audit_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/bayanihan_screen.dart';
import 'screens/profile_screen.dart';
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
  
  // Real-time In-App Notification State
  final Set<String> _notifiedOutageIds = {};
  final Map<String, String> _lastFuelStatuses = {};
  bool _isFirstLoad = true;

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
      _initLiveAlerts();
      _showPwaInstallPrompt();
    });
  }

  void _showPwaInstallPrompt() {
    if (!mounted) return;
    
    // Only show on Web and if not already dismissed
    if (widget.storage.isPwaPromptDismissed()) return;

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [Icon(Icons.install_mobile, color: AppColors.primary), SizedBox(width: 10), Text('Install App?', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold))]),
          content: const Text('Para sa mas mabilis na experience at mas accurate na Camera AI, i-install ang Kuryente App sa iyong phone! ⚡'),
          actions: [
            TextButton(
              onPressed: () {
                widget.storage.setPwaPromptDismissed(true);
                Navigator.pop(ctx);
              },
              child: const Text('Maybe Later', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                AppShell.scaffoldKey.currentState?.openDrawer();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Install Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
  }

  /// Monitors live data streams to show in-app alerts (Alternative to Cloud Push)
  void _initLiveAlerts() {
    final firebase = FirebaseService();

    // 1. Monitor Outages
    firebase.getOutagesStream().listen((outages) {
      if (_isFirstLoad) return; // Don't alert for old data on start

      for (var o in outages) {
        // Rule: Alert if it just got verified (nopower) and we haven't shown it
        if (o.status == OutageStatus.nopower && !_notifiedOutageIds.contains(o.id)) {
          _notifiedOutageIds.add(o.id);
          _showLiveAlert(
            title: '🔴 Brownout Confirmed!',
            body: 'Isang brownout ang nakumpirma sa ${o.barangay ?? "iyong lugar"}. Check the map now!',
            icon: Icons.power_off,
            color: AppColors.danger,
            onTap: () => jumpToReport(o),
          );
        }
      }
    });

    // 2. Monitor Fuel
    firebase.getFuelStationsStream().listen((stations) {
      if (_isFirstLoad) {
        // Record initial statuses
        for (var s in stations) { _lastFuelStatuses[s.id] = s.status.name; }
        _isFirstLoad = false;
        return;
      }

      for (var s in stations) {
        final lastStatus = _lastFuelStatuses[s.id];
        if (lastStatus != null && lastStatus != s.status.name) {
          _lastFuelStatuses[s.id] = s.status.name;
          
          // Only alert for major improvements (Unknown -> Available)
          if (s.status.name == 'available') {
            _showLiveAlert(
              title: '⛽ Fuel Update!',
              body: '${s.name} is now AVAILABLE. Check prices on the map!',
              icon: Icons.local_gas_station,
              color: AppColors.success,
              onTap: () => setState(() => _currentIndex = 1),
            );
          }
        }
      }
    });
  }

  void _showLiveAlert({
    required String title,
    required String body,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            onTap?.call();
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withAlpha(100)),
              boxShadow: [
                BoxShadow(color: color.withAlpha(30), blurRadius: 15, spreadRadius: 2),
                const BoxShadow(color: Colors.black45, blurRadius: 10),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withAlpha(40), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white24),
              ],
            ),
          ),
        ),
      ),
    );
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
              TextButton(
                onPressed: () async {
                  final firebaseService = FirebaseService();
                  await firebaseService.signOut();
                  if (ctx.mounted) Navigator.of(ctx).pop();
                }, 
                child: const Text('Understood'),
              ),
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
            StreamBuilder<Map<String, dynamic>>(
              stream: firebaseService.getUserProfileStream(),
              builder: (context, snapshot) {
                final profile = snapshot.data ?? {};
                final points = profile['points'] ?? 0;
                final photoUrl = profile['photoUrl'] as String?;
                
                String rank = 'Newbie Bayani';
                Color rankColor = Colors.black87; // Highly readable on orange
                if (points >= 50) { rank = 'Bronze Bayani'; rankColor = const Color(0xFF5D4037); }
                if (points >= 200) { rank = 'Silver Bayani'; rankColor = const Color(0xFF37474F); }
                if (points >= 500) { rank = 'Gold Bayani'; rankColor = const Color(0xFF3E2723); }
                if (points >= 1000) { rank = 'Legendary Bayani'; rankColor = Colors.white; }

                return UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(color: AppColors.primary),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null ? ClipOval(child: Image.asset('assets/kuryentahin.png')) : null,
                  ),
                  otherAccountsPictures: [
                    Image.asset('assets/kuryentahin.png', height: 40),
                  ],
                  accountName: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(user?.displayName ?? 'Kuryentahin User', 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18)),
                  ),
                  accountEmail: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        const Icon(Icons.stars, color: Colors.black54, size: 14),
                        const SizedBox(width: 4),
                        Text('$points pts • ', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(rank, style: TextStyle(color: rankColor, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                      ]),
                      const SizedBox(height: 2),
                      Text(user?.email ?? '', style: const TextStyle(color: Colors.black54, fontSize: 11)),
                    ],
                  ),
                );
              }
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
              onTap: () {
                Navigator.pop(context);
                // Open Profile Screen
                Navigator.push(context, MaterialPageRoute(builder: (ctx) => ProfileScreen(storage: widget.storage)));
              },
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
    );
  }

}
