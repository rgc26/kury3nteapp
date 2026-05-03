import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'app.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final storage = StorageService();
  await storage.init();
  
  runApp(KuryenteApp(storage: storage));
}

class KuryenteApp extends StatelessWidget {
  final StorageService storage;
  
  const KuryenteApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kuryente ⚡',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: AppShell(storage: storage),
    );
  }
}
