import 'package:flutter/material.dart';

import '../core/theme/theme_config.dart';
import '../presentation/scan_dashboard_page.dart';

class NutriSnapApp extends StatelessWidget {
  const NutriSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriSnap',
      debugShowCheckedModeBanner: false,
      theme: ThemeConfig.light(),
      home: const ScanDashboardPage(),
    );
  }
}
