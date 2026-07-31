import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/nutrisnap_app.dart';
import 'config/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: FirebaseBootstrap.forPlatform);
  } catch (error) {
    debugPrint('Firebase init: $error');
  }

  runApp(const NutriSnapApp());
}
