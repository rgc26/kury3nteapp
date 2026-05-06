import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA0A9UT9YieVXf1h-lzPcq5djsjoGYSwJQ',
    appId: '1:237461278663:web:be1c0869ef58ca9dea53e2',
    messagingSenderId: '237461278663',
    projectId: 'kuryenteapp',
    authDomain: 'kuryenteapp.firebaseapp.com',
    storageBucket: 'kuryenteapp.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA0A9UT9YieVXf1h-lzPcq5djsjoGYSwJQ',
    appId: '1:237461278663:android:be1c0869ef58ca9dea53e2', // Dummy, web is focus
    messagingSenderId: '237461278663',
    projectId: 'kuryenteapp',
    storageBucket: 'kuryenteapp.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA0A9UT9YieVXf1h-lzPcq5djsjoGYSwJQ',
    appId: '1:237461278663:ios:be1c0869ef58ca9dea53e2', // Dummy, web is focus
    messagingSenderId: '237461278663',
    projectId: 'kuryenteapp',
    storageBucket: 'kuryenteapp.firebasestorage.app',
    iosBundleId: 'com.example.kury3nteapp',
  );
}
