import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/ui.dart';
import 'analysis_controller.dart';

class ModelPage extends StatelessWidget {
  const ModelPage({super.key, required this.controller});
  final AnalysisController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeading(
        'Understand the intelligence',
        'A focused classifier, built to make leaf patterns easier to explore.',
      ),
      const SizedBox(height: 24),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('THE MODEL'),
            const SizedBox(height: 16),
            const Text(
              'MobileNetV3-Small',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A compact image classifier trained through transfer learning using PlantVillage '
              'leaf photographs for ${controller.supportedCrops.join(', ')}. ${controller.isOnDevice ? 'Inference runs entirely on this Android device using the bundled model.' : 'Inference runs in the configured Python backend.'}',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 13,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 22),
            const Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                StatusPill(label: '224 × 224 input', color: AppTheme.emerald),
                StatusPill(
                  label: 'ImageNet normalization',
                  color: AppTheme.emerald,
                ),
                StatusPill(label: 'CPU inference', color: AppTheme.emerald),
              ],
            ),
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 20),
            Eyebrow('${controller.classLabels.length} SUPPORTED CLASSES'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in controller.classLabels)
                  Chip(label: Text(label)),
              ],
            ),
            if (controller.testAccuracy != null) ...[
              const SizedBox(height: 14),
              Text(
                'Held-out accuracy: ${(controller.testAccuracy! * 100).toStringAsFixed(2)}% · Macro F1: ${(controller.macroF1! * 100).toStringAsFixed(2)}%',
              ),
              const Text(
                'Controlled PlantVillage test images; Potato Healthy support: 24. Field performance is not established.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Notice(
        message:
            'Confidence is a softmax score among supported classes, not a confirmed diagnosis. '
            'Crop selection and model agreement cannot verify plant identity or recognize every disease. '
            'Controlled PlantVillage photographs differ from real field conditions. '
            'Confirm significant symptoms with a local agricultural professional.',
      ),
      const SizedBox(height: 20),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(
              controller.isOnDevice
                  ? 'ON-DEVICE INFERENCE'
                  : 'BACKEND CONNECTION',
            ),
            const SizedBox(height: 16),
            SelectableText(
              controller.api.baseUrl,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(switch (controller.connection) {
              BackendConnection.ready =>
                controller.isOnDevice
                    ? 'Offline ready · bundled trained model loaded'
                    : 'Online · trained model loaded',
              BackendConnection.modelUnavailable =>
                'Online · model unavailable',
              BackendConnection.offline =>
                controller.isOnDevice
                    ? 'Local model unavailable · retry or reinstall'
                    : 'Offline · check the running server',
              BackendConnection.checking =>
                controller.isOnDevice
                    ? 'Loading on-device model…'
                    : 'Checking backend readiness…',
            }, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: controller.checkingHealth
                  ? null
                  : controller.refreshHealth,
              icon: const Icon(Icons.refresh, size: 17),
              label: Text(
                controller.isOnDevice ? 'Check model' : 'Check connection',
              ),
            ),
            const SizedBox(height: 18),
            Text(
              controller.isOnDevice
                  ? 'The model, labels and guidance ship inside this APK. Photos are processed locally. No MacBook, server, Python or internet connection is required. Camera captures may remain temporarily in the app cache.'
                  : 'Readiness is checked every 15 seconds. Photos are sent only when you choose Analyze leaf. '
                        'The app keeps results in memory for this session and does not write uploaded photos to disk.',
              style: TextStyle(
                color: AppTheme.muted,
                height: 1.7,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
