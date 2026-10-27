import 'package:flutter/material.dart';
import '../../core/models/analysis.dart';
import '../analysis_controller.dart';
import 'components.dart';
import 'crop_art.dart';
import 'theme.dart';

class EvergreenHome extends StatelessWidget {
  const EvergreenHome({
    super.key,
    required this.controller,
    required this.scan,
    required this.openCrop,
  });
  final AnalysisController controller;
  final VoidCallback scan;
  final ValueChanged<String> openCrop;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const EditorialHeading(
        'Grow with\nconfidence.',
        'Understand your crops, one leaf at a time.',
      ),
      const SizedBox(height: 28),
      CustomPaint(
        painter: _HeroShape(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
          child: Stack(
            children: [
              const Positioned(
                right: -12,
                top: 0,
                bottom: 0,
                width: 130,
                child: BotanicalAccent(),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    widthFactor: .65,
                    child: Text(
                      'A little attention.\nA healthier harvest.',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium!.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      key: const ValueKey('home-scan'),
                      onPressed: scan,
                      style: FilledButton.styleFrom(
                        backgroundColor: EvergreenColors.soft,
                        foregroundColor: EvergreenColors.deep,
                      ),
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: const Text('Scan a leaf'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Private. Offline. Ready when you are.',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: const Color(0xFFE4EFE2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      OfflineStatusIndicator(controller: controller),
      if (controller.connection != BackendConnection.ready &&
          controller.connection != BackendConnection.checking) ...[
        const SizedBox(height: 16),
        FriendlyErrorView(
          title: 'Let’s get your model ready',
          message:
              controller.connectionMessage ??
              'The local model is unavailable. Retry or reinstall the application.',
          action: controller.refreshHealth,
          actionLabel: 'Check model',
        ),
      ],
      const SizedBox(height: 40),
      Text('Your crops', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Text('Choose a crop to explore its health.'),
      const SizedBox(height: 20),
      CropGrid(crops: cropLabels, onSelect: openCrop, descriptors: true),
      const SizedBox(height: 32),
      const ComingNext(),
      const SizedBox(height: 24),
      Text(
        'One leaf, thoughtfully understood.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class ComingNext extends StatelessWidget {
  const ComingNext({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Coming next', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(
        'Collard Greens & Cabbage',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 4),
      Text(
        'Planned additions. Their models are not trained, and scanning is unavailable.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final crop in ['Collard Greens', 'Cabbage'])
            Semantics(
              label: '$crop unavailable, planned support',
              child: Chip(
                avatar: const Icon(Icons.lock_outline_rounded, size: 16),
                label: Text(crop),
              ),
            ),
        ],
      ),
    ],
  );
}

class _HeroShape extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 36)
      ..quadraticBezierTo(0, 12, 24, 12)
      ..cubicTo(size.width * .42, 20, size.width * .64, -8, size.width - 28, 0)
      ..quadraticBezierTo(size.width, 0, size.width, 28)
      ..lineTo(size.width, size.height - 28)
      ..quadraticBezierTo(size.width, size.height, size.width - 28, size.height)
      ..lineTo(28, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - 28)
      ..close();
    canvas.drawPath(path, Paint()..color = EvergreenColors.forest);
  }

  @override
  bool shouldRepaint(_HeroShape old) => false;
}
