// Конфиг по образцу FlutterFire: класс со статическими членами — норма здесь.
// ignore_for_file: avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase-конфиг приложения. Значения — client-конфиг из GoogleService-Info.plist
/// (не секрет, шьётся в приложение). Пока настроен только iOS; Android/Web
/// добавим, когда появятся их google-services.json / web-конфиг.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web push ещё не настроен.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Push настроен пока только для iOS (платформа: $defaultTargetPlatform).',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA80kN-ECqWbXjo0sDRT0akDwMPtYZPVOE',
    appId: '1:106775699003:ios:cc1f7e1af23f8a14a8461e',
    messagingSenderId: '106775699003',
    projectId: 'aloria-6d40f',
    storageBucket: 'aloria-6d40f.firebasestorage.app',
    iosBundleId: 'com.example.aloria',
  );
}
