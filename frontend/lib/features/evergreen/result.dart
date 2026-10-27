import 'package:flutter/material.dart';
import '../../core/models/analysis.dart';
import '../analysis_controller.dart';
import 'components.dart';
import 'scan.dart';
import 'theme.dart';

class EvergreenResult extends StatelessWidget {
  const EvergreenResult({
    super.key,
    required this.controller,
    required this.changeCrop,
    this.openGuide,
  });
  final AnalysisController controller;
  final VoidCallback changeCrop;
  final VoidCallback? openGuide;
  @override
  Widget build(BuildContext context) {
    final result = controller.prediction!;
    final healthy = result.shortName == 'Healthy';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = healthy
        ? Theme.of(context).colorScheme.primary
        : dark
        ? const Color(0xFFE9C080)
        : EvergreenColors.warningText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your ${controller.selectedCrop.toLowerCase()} leaf',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        LeafImagePreview(image: controller.image!, compact: true),
        const SizedBox(height: 24),
        EvergreenPanel(
          color: healthy
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: .5)
              : dark
              ? const Color(0xFF352E22)
              : const Color(0xFFF7EDD9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                healthy ? Icons.spa_outlined : Icons.eco_outlined,
                size: 32,
                color: tone,
              ),
              const SizedBox(height: 16),
              Text(
                healthy ? 'Closest healthy match' : 'Possible condition',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: tone),
              ),
              const SizedBox(height: 8),
              Text(
                result.shortName,
                key: const ValueKey('predicted-class'),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Model match: ${result.percentage}',
                key: const ValueKey('model-match'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium!.copyWith(color: tone),
              ),
              const SizedBox(height: 12),
              const Text('A model comparison, not a confirmed diagnosis.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          readableDescription(result.information.description),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (openGuide != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey("result-field-guide"),
            onPressed: openGuide,
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text("Read the field guide"),
          ),
        ],
        const SizedBox(height: 32),
        Text(
          'The closest matches',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Global scores across supported crops. No crop filtering is applied.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        PredictionScores(scores: result.topThree),
        const SizedBox(height: 32),
        Text(
          'What you can do',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        CareRecommendations(items: result.information.management),
        const SizedBox(height: 24),
        EvergreenPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExpansionTile(
                title: const Text('Looking ahead'),
                children: [
                  CareRecommendations(items: result.information.prevention),
                ],
              ),
              ExpansionTile(
                title: const Text('How was this result calculated?'),
                children: [
                  Text(
                    'MobileNetV3-Small compares your photo with ${controller.classLabels.length} supported crop-condition classes. Scores come from a global softmax comparison, not verified crop identity or diagnostic certainty.',
                  ),
                  const SizedBox(height: 12),
                  Text(result.confidenceNote),
                  const SizedBox(height: 12),
                  const Text(
                    'Training used controlled PlantVillage leaf photographs. Field backgrounds, unsupported species and other conditions may produce confidently wrong results.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Confirm important symptoms with a local agricultural professional.',
                  ),
                ],
              ),
              ExpansionTile(
                title: const Text('Guidance sources'),
                children: [
                  for (final source in result.information.sources)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SelectableText(
                        source,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        PrimaryAction(
          label: 'Scan another leaf',
          onPressed: controller.clearImage,
          icon: Icons.document_scanner_outlined,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: changeCrop,
            child: const Text('Change crop'),
          ),
        ),
      ],
    );
  }
}

class PredictionScores extends StatelessWidget {
  const PredictionScores({super.key, required this.scores});
  final List<ClassScore> scores;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final score in scores)
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      score.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    score.percentage,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Semantics(
                label: '${score.name}, model score ${score.percentage}',
                child: ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      duration: evergreenMotion(context),
                      tween: Tween(begin: 0, end: score.confidence),
                      builder: (_, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 5,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class CareRecommendations extends StatelessWidget {
  const CareRecommendations({super.key, required this.items});
  final List<String> items;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.all(8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  items[i],
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
