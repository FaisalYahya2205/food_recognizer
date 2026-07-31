import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase config for NutriSnap (`com.dicoding.nutrisnap`).
class FirebaseBootstrap {
  static FirebaseOptions get forPlatform {
    if (kIsWeb) return _web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _android,
      TargetPlatform.iOS => _ios,
      TargetPlatform.macOS => _macos,
      _ => throw UnsupportedError('Platform belum dikonfigurasi.'),
    };
  }

  static const _android = FirebaseOptions(
    apiKey: 'AIzaSyA42HIRGEqLJ9tzw8P9fcDRpT_QWjpbMbE',
    appId: '1:1097844958640:android:fc8c4448ec94a37f42a275',
    messagingSenderId: '1097844958640',
    projectId: 'food-recognizer-56804',
    storageBucket: 'food-recognizer-56804.firebasestorage.app',
  );

  static const _ios = FirebaseOptions(
    apiKey: 'AIzaSyAuQU9C0lXDzZkpY4KW0IXyYy-8xs6q7Fs',
    appId: '1:1097844958640:ios:fb441a4f3e4389e142a275',
    messagingSenderId: '1097844958640',
    projectId: 'food-recognizer-56804',
    storageBucket: 'food-recognizer-56804.firebasestorage.app',
    iosBundleId: 'com.dicoding.nutrisnap',
  );

  static const _macos = FirebaseOptions(
    apiKey: 'AIzaSyAuQU9C0lXDzZkpY4KW0IXyYy-8xs6q7Fs',
    appId: '1:1097844958640:ios:fb441a4f3e4389e142a275',
    messagingSenderId: '1097844958640',
    projectId: 'food-recognizer-56804',
    storageBucket: 'food-recognizer-56804.firebasestorage.app',
    iosBundleId: 'com.dicoding.nutrisnap',
  );

  static const _web = FirebaseOptions(
    apiKey: '',
    appId: '1:1234567890:web:placeholder',
    messagingSenderId: '1097844958640',
    projectId: 'food-recognizer-56804',
    authDomain: 'food-recognizer-56804.firebaseapp.com',
    storageBucket: 'food-recognizer-56804.firebasestorage.app',
  );
}
