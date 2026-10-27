import 'package:flutter/material.dart';

import '../core/models/analysis.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/ui.dart';
import 'analysis_controller.dart';

class LeafAnalysis extends StatelessWidget {
  const LeafAnalysis({
    super.key,
    required this.controller,
    this.compact = false,
  });
  final AnalysisController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeading(
        compact ? 'Leaf analysis' : 'One leaf. Clearer insight.',
        'Choose a supported leaf photo to explore its health and recommended care.',
      ),
      const SizedBox(height: 22),
      if (controller.error != null) ...[
        Notice(
          key: const ValueKey('analysis-error'),
          message: controller.error!,
          error: true,
          onDismiss: controller.dismissError,
        ),
        const SizedBox(height: 16),
      ],
      LayoutBuilder(
        builder: (context, constraints) {
          final upload = _UploadCard(controller: controller);
          final result = _PredictionCard(controller: controller);
          if (constraints.maxWidth < 780) {
            return Column(
              children: [upload, const SizedBox(height: 20), result],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: upload),
              const SizedBox(width: 20),
              Expanded(child: result),
            ],
          );
        },
      ),
      if (controller.prediction != null) ...[
        const SizedBox(height: 28),
        _CarePlan(
          prediction: controller.prediction!,
          onDevice: controller.isOnDevice,
        ),
      ],
    ],
  );
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.controller});
  final AnalysisController controller;

  @override
  Widget build(BuildContext context) {
    final image = controller.image;
    final busy = controller.analyzing || controller.choosing;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Eyebrow('01  /  YOUR LEAF'),
              const Spacer(),
              if (image != null)
                IconButton(
                  key: const ValueKey('clear-image'),
                  tooltip: 'Remove selected image',
                  onPressed: busy ? null : controller.clearImage,
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (image == null)
            InkWell(
              key: const ValueKey('upload-drop-area'),
              onTap: busy ? null : controller.chooseImage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 45,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.offWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD6E0CC)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 42,
                      color: AppTheme.emerald,
                    ),
                    SizedBox(height: 18),
                    Text(
                      'Bring your leaf into focus',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      controller.isOnDevice
                          ? 'Tap to choose a leaf photo'
                          : 'Click to choose a photo from your Mac',
                      style: TextStyle(color: AppTheme.muted, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'JPEG, PNG or WebP  ·  Up to 10 MiB',
                      style: TextStyle(color: AppTheme.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: AppTheme.offWhite,
                child: AspectRatio(
                  aspectRatio: 1.6,
                  child: Image.memory(
                    image.bytes,
                    key: ValueKey(image.bytes),
                    fit: BoxFit.contain,
                    cacheWidth: 1000,
                    filterQuality: FilterQuality.medium,
                    semanticLabel: 'Selected leaf image',
                    errorBuilder: (_, _, _) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Preview unavailable. Choose another image.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.image_outlined,
                  size: 18,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        image.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${image.width} × ${image.height}  ·  ${image.sizeLabel}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('choose-image'),
              onPressed: busy ? null : controller.chooseImage,
              icon: controller.choosing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(
                controller.choosing
                    ? 'Opening photo…'
                    : image == null
                    ? 'Choose image'
                    : 'Choose another image',
              ),
            ),
          ),
          if (controller.canCapture) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('capture-image'),
                onPressed: busy ? null : controller.captureImage,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Take a photo'),
              ),
            ),
          ],
          if (controller.isMultiCrop) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('crop-${controller.selectedCrop}'),
              initialValue: controller.selectedCrop,
              decoration: const InputDecoration(labelText: 'Selected crop'),
              items: [
                for (final crop in controller.supportedCrops)
                  DropdownMenuItem(value: crop, child: Text(crop)),
              ],
              onChanged: busy
                  ? null
                  : (crop) {
                      if (crop != null) controller.selectCrop(crop);
                    },
            ),
          ],
          if (controller.isOnDevice && image != null) ...[
            const SizedBox(height: 12),
            CheckboxListTile(
              key: const ValueKey('confirm-tomato'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: controller.tomatoConfirmed,
              onChanged: busy
                  ? null
                  : (value) => controller.confirmTomato(value ?? false),
              title: Text(
                controller.isMultiCrop
                    ? 'This is a ${controller.selectedCrop.toLowerCase()} leaf'
                    : 'This is a tomato leaf',
                style: TextStyle(fontSize: 12),
              ),
              subtitle: const Text(
                'Confirm the selected crop. Selection cannot verify plant identity.',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('analyze-image'),
              onPressed: controller.canAnalyze ? controller.analyze : null,
              icon: controller.analyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.muted,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_outlined, size: 17),
              label: Text(
                controller.analyzing
                    ? 'Analyzing your leaf…'
                    : controller.prediction != null
                    ? 'Analyze again'
                    : 'Analyze leaf',
              ),
            ),
          ),
          const SizedBox(height: 17),
          Text(
            controller.connection == BackendConnection.ready
                ? 'Tip: use a sharp photo of a single leaf in even lighting.'
                : controller.isOnDevice
                ? 'Load the bundled model to enable analysis. No server or internet is needed.'
                : 'Connect to a ready backend to enable analysis. You can select a photo now.',
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 11,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.controller});
  final AnalysisController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.prediction;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('02  /  MODEL ASSESSMENT'),
          const SizedBox(height: 24),
          if (controller.analyzing) ...[
            const SizedBox(height: 45),
            const Center(
              child: Icon(
                Icons.eco_outlined,
                size: 46,
                color: AppTheme.emerald,
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Reading the details…',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Your photo is being analyzed by the local model.',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            const LinearProgressIndicator(
              key: ValueKey('analysis-progress'),
              minHeight: 3,
            ),
            const SizedBox(height: 50),
          ] else if (result == null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 42),
              child: const Column(
                children: [
                  Icon(
                    Icons.energy_savings_leaf_outlined,
                    size: 49,
                    color: Color(0xFFA6B99C),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Your leaf’s story,\nmade clearer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      letterSpacing: -.6,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Choose a photo and run an analysis.\nYour results and care guidance will appear here.',
                    style: TextStyle(
                      color: AppTheme.muted,
                      height: 1.7,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  StatusPill(label: 'Awaiting analysis', color: AppTheme.muted),
                ],
              ),
            ),
          ] else ...[
            const Eyebrow('CLOSEST MATCH', color: AppTheme.emerald),
            const SizedBox(height: 10),
            Text(
              result.shortName,
              key: const ValueKey('predicted-class'),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.eco_outlined,
                      size: 15,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${result.crop} leaf',
                      style: TextStyle(color: AppTheme.muted, fontSize: 12),
                    ),
                  ],
                ),
                Text(
                  '${result.percentage} confidence',
                  style: const TextStyle(
                    color: AppTheme.emerald,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Divider(),
            const SizedBox(height: 14),
            const Eyebrow('TOP THREE PREDICTIONS'),
            const SizedBox(height: 18),
            for (int index = 0; index < result.topThree.length; index++)
              _score(result.topThree[index], index),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 15),
            Text(
              result.information.description,
              style: const TextStyle(fontSize: 13, height: 1.7),
            ),
          ],
          const SizedBox(height: 18),
          Notice(
            message:
                result?.confidenceNote ??
                'Model confidence is not diagnostic certainty. Scores compare the supported crop-condition classes; '
                    'other conditions and non-leaf images may receive misleading scores.',
          ),
        ],
      ),
    );
  }

  Widget _score(ClassScore score, int index) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                score.name,
                style: TextStyle(
                  fontSize: 12,
                  color: index == 0 ? AppTheme.ink : AppTheme.muted,
                  fontWeight: index == 0 ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              score.percentage,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: score.confidence,
            minHeight: 6,
            backgroundColor: AppTheme.offWhite,
            color: index == 0 ? AppTheme.emerald : const Color(0xFFBBCFA6),
            semanticsLabel: '${score.name} confidence percent',
            semanticsValue: (score.confidence * 100).toStringAsFixed(1),
          ),
        ),
      ],
    ),
  );
}

class _CarePlan extends StatelessWidget {
  const _CarePlan({required this.prediction, required this.onDevice});
  final bool onDevice;
  final LeafPrediction prediction;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeading(
        'An informed next step',
        onDevice
            ? 'Practical care guidance bundled locally on your device.'
            : 'Practical guidance provided by the backend for this assessment.',
      ),
      const SizedBox(height: 18),
      LayoutBuilder(
        builder: (context, constraints) {
          final management = _guidance(
            'Disease management',
            Icons.healing_outlined,
            prediction.information.management,
          );
          final prevention = _guidance(
            'Prevention & good practice',
            Icons.shield_outlined,
            prediction.information.prevention,
          );
          if (constraints.maxWidth < 780) {
            return Column(
              children: [management, const SizedBox(height: 16), prevention],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: management),
              const SizedBox(width: 20),
              Expanded(child: prevention),
            ],
          );
        },
      ),
      if (prediction.information.sources.isNotEmpty) ...[
        const SizedBox(height: 20),
        ExpansionTile(
          title: const Text(
            'Guidance sources',
            style: TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
          leading: const Icon(
            Icons.menu_book_outlined,
            size: 18,
            color: AppTheme.muted,
          ),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 16),
          children: [
            for (final source in prediction.information.sources)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SelectableText(
                    source,
                    style: const TextStyle(
                      color: AppTheme.emerald,
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ],
  );

  Widget _guidance(String title, IconData icon, List<String> items) =>
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.emerald, size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (items.isEmpty)
              const Text(
                'No additional guidance was supplied.',
                style: TextStyle(color: AppTheme.muted),
              ),
            for (int i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 23,
                      height: 23,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.pale,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: AppTheme.emerald,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        items[i],
                        style: const TextStyle(fontSize: 12, height: 1.7),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}
