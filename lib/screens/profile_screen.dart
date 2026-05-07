import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  final StorageService storage;
  const ProfileScreen({super.key, required this.storage});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _firebase = FirebaseService();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _changePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => _isUploading = true);
      
      final bytes = await image.readAsBytes();
      final url = await _firebase.uploadToCloudinary(bytes);

      if (url != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated! 📸'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _firebase.currentUser;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('My Bayani Profile'),
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _firebase.getUserProfileStream(),
        builder: (context, snapshot) {
          final profile = snapshot.data ?? {};
          final points = profile['points'] ?? 0;
          final photoUrl = profile['photoUrl'] as String?;

          String rank = 'Newbie Bayani';
          Color rankColor = Colors.grey;
          if (points >= 50) { rank = 'Bronze Bayani'; rankColor = Colors.orange; }
          if (points >= 200) { rank = 'Silver Bayani'; rankColor = Colors.blueGrey; }
          if (points >= 500) { rank = 'Gold Bayani'; rankColor = Colors.amber; }
          if (points >= 1000) { rank = 'Legendary Bayani'; rankColor = AppColors.primary; }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // PROFILE HEADER
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 3),
                          boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(50), blurRadius: 20)],
                        ),
                        child: CircleAvatar(
                          backgroundColor: AppColors.surfaceLighter,
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null ? Text(user?.displayName?[0] ?? '?', style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold)) : null,
                        ),
                      ),
                      if (_isUploading)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploading ? null : _changePhoto,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.black, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(user?.displayName ?? 'Kuryente User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(user?.email ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
                
                const SizedBox(height: 32),

                // STATS CARDS
                Row(
                  children: [
                    Expanded(child: _statCard('POINTS', '$points', Icons.stars, Colors.amber)),
                    const SizedBox(width: 16),
                    Expanded(child: _statCard('RANK', rank.split(' ')[0], Icons.emoji_events, rankColor)),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // ACHIEVEMENT SECTION
                _buildAchievementSection(points),

                const SizedBox(height: 40),
                
                OutlinedButton.icon(
                  onPressed: () async {
                    await _firebase.signOut();
                    if (mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLighter,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAchievementSection(int points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('BAYANIHAN PROGRESS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: (points % 500) / 500,
          backgroundColor: Colors.white10,
          color: AppColors.primary,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Text('Next Rank: ${points < 50 ? "Bronze" : points < 200 ? "Silver" : "Gold"}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}
