import 'package:flutter/material.dart';
import '../../core/models/analysis.dart';
import 'components.dart';
import 'crop_art.dart';
import 'home.dart';
import 'result.dart';

class EvergreenExplore extends StatelessWidget {
  const EvergreenExplore({
    super.key,
    required this.metadata,
    required this.openCrop,
    required this.retry,
    this.failed = false,
  });
  final Map<String, dynamic>? metadata;
  final ValueChanged<String> openCrop;
  final VoidCallback retry;
  final bool failed;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const EditorialHeading(
        'Know your crops.',
        'Learn what healthy growth looks like and which conditions AgriVision can recognize.',
      ),
      const SizedBox(height: 28),
      CropGrid(crops: cropLabels, onSelect: openCrop, descriptors: true),
      const SizedBox(height: 32),
      const ComingNext(),
      const SizedBox(height: 32),
      if (metadata == null)
        FriendlyErrorView(
          title: failed
              ? 'Crop guides need attention'
              : 'Crop guides are loading',
          message:
              'The bundled crop library is not available yet. It needs no internet connection.',
          action: retry,
          actionLabel: 'Reload guides',
        )
      else
        AboutAgriVision(metadata: metadata!),
      const SizedBox(height: 24),
      EvergreenPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A better leaf photograph',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose a single leaf from a supported crop. Use natural light, keep your camera steady and let the leaf fill the frame.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Avoid multiple overlapping leaves, roots, fruit, screenshots with borders and heavily edited images. Clear framing helps, but cannot guarantee a correct match.',
            ),
          ],
        ),
      ),
    ],
  );
}

class CropGuide extends StatelessWidget {
  const CropGuide({
    super.key,
    required this.crop,
    required this.metadata,
    required this.scan,
  });
  final String crop;
  final Map<String, dynamic> metadata;
  final VoidCallback? scan;
  @override
  Widget build(BuildContext context) {
    final labels = List<String>.from(
      metadata['labels'] as List,
    ).where((label) => label.startsWith('$crop '));
    final guidance = metadata['guidance'] as Map<String, dynamic>;
    return Scaffold(
      appBar: AppBar(
        title: Text(crop),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: CropIllustration(crop, size: 150)),
                  const SizedBox(height: 24),
                  Text(
                    '$crop, understood.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    crop == 'Potato'
                        ? 'Ordinary potato (Solanum tuberosum) leaves. Sweet potato is a different species and is unsupported.'
                        : 'These are the leaf conditions this version can compare. Other conditions remain unsupported.',
                  ),
                  const SizedBox(height: 24),
                  for (final label in labels)
                    EvergreenPanel(
                      padding: 20,
                      child: ExpansionTile(
                        title: Text(
                          label.substring(crop.length + 1),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        children: [
                          Text(
                            readableDescription(
                              guidance[label]['description'] as String,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'What you can do',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          CareRecommendations(
                            items: List<String>.from(
                              guidance[label]['management'] as List,
                            ),
                          ),
                          Text(
                            'Prevention',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          CareRecommendations(
                            items: List<String>.from(
                              guidance[label]['prevention'] as List,
                            ),
                          ),
                          for (final source
                              in guidance[label]['sources'] as List)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: SelectableText(
                                source as String,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'A leaf photo cannot confirm disease or crop identity. Important symptoms need local agricultural advice.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  PrimaryAction(
                    label: 'Scan a $crop leaf',
                    onPressed: scan,
                    icon: Icons.document_scanner_outlined,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AboutAgriVision extends StatelessWidget {
  const AboutAgriVision({super.key, required this.metadata});
  final Map<String, dynamic> metadata;
  @override
  Widget build(BuildContext context) {
    final evaluation = metadata['evaluation'] as Map<String, dynamic>?;
    return EvergreenPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Intelligence, close to nature.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'AgriVision AI keeps its leaf model and care library on your device. No account, server or internet connection is required to scan.',
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('About the model'),
            children: [
              const Text(
                'MobileNetV3-Small · ONNX Runtime Android · CPU inference',
              ),
              const SizedBox(height: 12),
              Text(
                '${(metadata['labels'] as List).length} classes across Tomato, Maize, Potato and Bell Pepper. Input: 224 × 224 RGB pixels.',
              ),
              const SizedBox(height: 12),
              const Text(
                'EXIF orientation, bilinear resize, center crop and ImageNet normalization preserve the trained preprocessing contract.',
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('Evaluation & its limits'),
            children: [
              if (evaluation != null) ...[
                Text(
                  'Held-out dataset accuracy: ${((evaluation['accuracy'] as num) * 100).toStringAsFixed(2)}%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Macro F1: ${((evaluation['f1_macro'] as num) * 100).toStringAsFixed(2)}% · ${evaluation['test_samples']} held-out images',
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'These are controlled PlantVillage results, not measured real-world field accuracy. Best checkpoint selection used validation data; evaluation used a held-out, grouped test partition.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Potato Healthy has limited coverage: 24 test photographs from six known leaf groups. Backgrounds, lighting, unsupported crops and unfamiliar conditions can yield confidently incorrect scores.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Crop selection does not verify identity. A crop mismatch withholds the diagnosis rather than substituting another class.',
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('Dataset & attribution'),
            children: [
              const Text(
                'PlantVillage original RGB images. Mohanty, Hughes & Salathé (2016), Using Deep Learning for Image-Based Plant Disease Detection.',
              ),
              const SizedBox(height: 12),
              const SelectableText('doi.org/10.3389/fpls.2016.01419'),
              const SizedBox(height: 12),
              const Text(
                'The author-hosted dataset declares CC BY-SA 3.0, but its loader describes this licence as an assumption to verify. Original image redistribution rights remain unresolved. No dataset photographs are bundled in the app’s crop guides.',
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('Privacy & local storage'),
            children: [
              const Text(
                'Bookmarks, headline preferences and a small optional headline cache are stored locally. Selected photos and predictions stay in memory for this session. Camera captures may remain temporarily in the application cache. The model and recommendations are bundled locally.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Crop guides are educational, not a treatment prescription. Follow local agricultural advice and product labels for any management decision.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
