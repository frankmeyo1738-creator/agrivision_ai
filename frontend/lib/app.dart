import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/services/agrivision_api.dart';
import 'core/services/offline_api.dart';
import 'core/services/android_leaf_picker.dart';
import 'core/services/leaf_picker.dart';
import 'core/theme/app_theme.dart';
import 'features/analysis_controller.dart';
import 'features/workspace.dart';
import 'features/evergreen/evergreen.dart';
import 'features/evergreen/theme.dart';

class AgriVisionApp extends StatefulWidget {
  const AgriVisionApp({super.key, this.api, this.picker});

  final AgriVisionApi? api;
  final LeafPicker? picker;

  @override
  State<AgriVisionApp> createState() => _AgriVisionAppState();
}

class _AgriVisionAppState extends State<AgriVisionApp> {
  late final AnalysisController controller;

  @override
  void initState() {
    super.initState();
    controller = AnalysisController(
      api:
          widget.api ??
          (Platform.isAndroid ? OfflineAgriVisionApi() : HttpAgriVisionApi()),
      picker:
          widget.picker ??
          (Platform.isAndroid ? AndroidLeafPicker() : NativeLeafPicker()),
    )..start();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AgriVision AI',
    debugShowCheckedModeBanner: false,
    theme: controller.isOnDevice ? EvergreenTheme.light : AppTheme.light,
    darkTheme: controller.isOnDevice ? EvergreenTheme.dark : null,
    home: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, meta: true): () {
          controller.chooseImage();
        },
      },
      child: Focus(
        autofocus: true,
        child: controller.isOnDevice
            ? EvergreenWorkspace(controller: controller)
            : Workspace(controller: controller),
      ),
    ),
  );
}
