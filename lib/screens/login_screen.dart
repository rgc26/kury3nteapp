import 'package:flutter/material.dart';
import 'dart:js' as js;
import '../theme/app_colors.dart';
import '../services/firebase_service.dart';

import '../services/storage_service.dart';

class LoginScreen extends StatefulWidget {
  final FirebaseService firebaseService;
  final StorageService storage;

  const LoginScreen({
    super.key, 
    required this.firebaseService,
    required this.storage,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await widget.firebaseService.signInWithGoogle();
      // The auth state listener in main.dart/app.dart will automatically handle the navigation
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Show download warning on visit if not already dismissed and not already in standalone mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowDownloadWarning();
    });
  }

  void _checkAndShowDownloadWarning() {
    // 1. Check if already running as a PWA (standalone)
    final isStandalone = js.context.callMethod('eval', [
      "window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true"
    ]) == true;

    // 2. Check if user already dismissed it
    final isDismissed = widget.storage.isPwaPromptDismissed();

    if (!isStandalone && !isDismissed) {
      _showDownloadWarning();
    }
  }

  void _showDownloadWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_to_home_screen, color: AppColors.primary),
            SizedBox(width: 12),
            Text('Experience Kuryente ⚡', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'For faster access to the brownout map and live community alerts, we recommend adding Kuryente to your home screen.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await widget.storage.setPwaPromptDismissed(true);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Don\'t show again', style: TextStyle(color: Colors.white24, fontSize: 10)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (js.context.hasProperty('installPWA')) {
                js.context.callMethod('installPWA');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Use "Add to Home Screen" in your browser menu! 📲')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add to Home Screen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo or Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flash_on,
                  size: 80,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),
              
              // App Title
              Text(
                'Kuryente ⚡',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              
              // Subtitle
              Text(
                'Crowdsourced brownout map and energy tracker. Report outages, earn Bayani points, and stay informed.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 48),

              // Sign in button
              if (_isLoading)
                const CircularProgressIndicator(color: AppColors.primary)
              else
                ElevatedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
