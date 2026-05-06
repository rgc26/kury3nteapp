import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'app.dart';
import 'services/storage_service.dart';
import 'services/firebase_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final storage = StorageService();
  await storage.init();
  
  runApp(KuryenteApp(storage: storage));
}

class KuryenteApp extends StatelessWidget {
  final StorageService storage;
  
  const KuryenteApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    return MaterialApp(
      title: 'Kuryente ⚡',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: StreamBuilder<User?>(
        stream: firebaseService.authStateChanges,
        builder: (context, snapshot) {
          // While checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          // If logged in
          if (snapshot.hasData && snapshot.data != null) {
            return AppShell(storage: storage);
          }
          // If logged out
          return LoginScreen(firebaseService: firebaseService);
        },
      ),
    );
  }
}
