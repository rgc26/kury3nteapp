import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/firebase_service.dart';

class NotificationsScreen extends StatelessWidget {
  final FirebaseService _firebaseService = FirebaseService();

  NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () {
              // Mark all as read logic could go here
            },
          )
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _firebaseService.getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: AppColors.textMuted.withAlpha(50)),
                  const SizedBox(height: 16),
                  const Text('No notifications yet', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final n = notifications[index];
              return _notificationCard(context, n);
            },
          );
        },
      ),
    );
  }

  Widget _notificationCard(BuildContext context, AppNotification n) {
    IconData icon;
    Color color;

    switch (n.type) {
      case 'interested':
        icon = Icons.person_add;
        color = AppColors.primary;
        break;
      case 'salamat':
        icon = Icons.favorite;
        color = AppColors.success;
        break;
      case 'comment':
        icon = Icons.comment;
        color = AppColors.secondary;
        break;
      default:
        icon = Icons.notifications;
        color = AppColors.textMuted;
    }

    return Card(
      elevation: n.isRead ? 0 : 2,
      color: n.isRead ? AppColors.surface : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: n.isRead ? AppColors.border : color.withAlpha(50), width: 1),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(20),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n.message, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(_timeAgo(n.createdAt), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
        onTap: () {
          _firebaseService.markNotificationAsRead(n.id);
          // Navigate to related content if needed
        },
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
