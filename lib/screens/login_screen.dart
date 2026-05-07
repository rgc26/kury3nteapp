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
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Icon(Icons.install_mobile, color: AppColors.primary, size: 48),
            const SizedBox(height: 16),
            const Text('Experience Kuryentahin ⚡', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            const Text(
              'Install the app for faster access to the live map and real-time community alerts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Add to Home Screen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Maybe Later', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                await widget.storage.setPwaPromptDismissed(true);
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text(
                'Don\'t show this again',
                style: TextStyle(color: Colors.white24, fontSize: 11, decoration: TextDecoration.underline),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenHeight = constraints.maxHeight;
          final double logoSize = screenHeight < 600 ? 100 : 140;

          return SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
              constraints: BoxConstraints(minHeight: screenHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Responsive Logo Image
                  Container(
                    width: logoSize,
                    height: logoSize,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(50),
                          blurRadius: 30,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/kuryentahin.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.flash_on,
                          size: logoSize * 0.6,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight < 600 ? 24 : 32),
                  
                  // App Title & Tagline
                  const Text(
                    'Kuryentahin',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Waze for the Philippine Energy Crisis',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  SizedBox(height: screenHeight < 600 ? 40 : 64),

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
