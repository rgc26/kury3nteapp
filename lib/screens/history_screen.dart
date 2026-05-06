import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../services/firebase_service.dart';
import '../models/outage_report.dart';
import '../app.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => AppShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Report History 📜'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Barangay (e.g. Brgy 73)',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<OutageReport>>(
              stream: _firebaseService.getOutageHistoryStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final allReports = snapshot.data ?? [];
                
                // Sort by date descending in UI as well to handle mixed types in Firestore
                allReports.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));

                final filtered = allReports.where((r) {
                  final matchesSearch = r.barangay?.toLowerCase().contains(_searchQuery) ?? true;
                  return matchesSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No historical reports found.', style: TextStyle(color: AppColors.textMuted)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final report = filtered[index];
                    final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(report.reportedAt);
                    
                    Color statusColor;
                    IconData statusIcon;
                    if (report.status == OutageStatus.restored) {
                      statusColor = AppColors.success;
                      statusIcon = Icons.check_circle_outline;
                    } else if (report.status == OutageStatus.nopower) {
                      statusColor = AppColors.danger;
                      statusIcon = Icons.flash_off;
                    } else {
                      statusColor = AppColors.warning;
                      statusIcon = Icons.help_outline;
                    }

                    return Card(
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), 
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withAlpha(40),
                          child: Icon(statusIcon, color: statusColor, size: 20),
                        ),
                        title: Text(report.barangay ?? 'Unknown Area', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dateStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            if (report.notes != null && report.notes!.isNotEmpty) 
                              Text('\"${report.notes}\"', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withAlpha(40), borderRadius: BorderRadius.circular(8)),
                          child: Text(report.status.name.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
