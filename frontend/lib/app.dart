import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

/// Phase 1 shell. The upload and prediction screens are planned for Phase 2.
class AgriVisionApp extends StatelessWidget {
  const AgriVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriVision AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.eco_outlined, size: 48, color: AppTheme.forest),
                SizedBox(height: 16),
                Text('AgriVision AI', style: TextStyle(fontSize: 28)),
                SizedBox(height: 8),
                Text('Intelligent crop disease detection and management'),
                SizedBox(height: 24),
                Text(
                  'Phase 1 · Project foundation',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
