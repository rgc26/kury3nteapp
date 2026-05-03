import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'services/storage_service.dart';
import 'screens/brownout_map_screen.dart';
import 'screens/fuel_tracker_screen.dart';
import 'screens/energy_audit_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/bayanihan_screen.dart';
import 'screens/dashboard_screen.dart';

class AppShell extends StatefulWidget {
  final StorageService storage;
  
  const AppShell({super.key, required this.storage});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
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
      BrownoutMapScreen(storage: widget.storage),
      FuelTrackerScreen(storage: widget.storage),
      EnergyAuditScreen(storage: widget.storage),
      AlertsScreen(storage: widget.storage),
      BayanihanScreen(storage: widget.storage),
    ];
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        child: IndexedStack(
          key: ValueKey(_currentIndex),
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
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
