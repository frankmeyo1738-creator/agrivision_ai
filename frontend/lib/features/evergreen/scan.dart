import 'package:flutter/material.dart';
import '../../core/models/analysis.dart';
import '../analysis_controller.dart';
import 'components.dart';
import 'crop_art.dart';
import 'result.dart';

class EvergreenScan extends StatelessWidget {
  const EvergreenScan({super.key, required this.controller, this.openGuide});
  final AnalysisController controller;
  final ValueChanged<String>? openGuide;
  @override
  Widget build(BuildContext context) {
    if (controller.prediction != null) {
      return EvergreenResult(
        controller: controller,
        changeCrop: () => _changeCrop(context),
        openGuide: openGuide == null
            ? null
            : () => openGuide!(controller.prediction!.className),
      );
    }
    if (controller.cropMismatch != null) {
      return _Mismatch(
        controller: controller,
        changeCrop: () => _changeCrop(context),
      );
    }
    final busy = controller.analyzing || controller.choosing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EditorialHeading(
          'A closer look.',
          'A clear photograph is the beginning of a useful result.',
        ),
        const SizedBox(height: 28),
        Text(
          '1. Choose your crop',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        CropGrid(
          crops: controller.supportedCrops,
          selected: controller.selectedCrop,
          onSelect: controller.selectCrop,
        ),
        if (controller.selectedCrop == 'Potato') ...[
          const SizedBox(height: 12),
          Text(
            'Ordinary potato leaves only. Sweet potato is a different, unsupported crop.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 28),
        Text('2. Your leaf', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (controller.image == null)
          EvergreenPanel(
            child: Column(
              children: [
                CropIllustration(controller.selectedCrop, size: 104),
                const SizedBox(height: 16),
                Text(
                  'Let’s start with one leaf.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'For best results, photograph one leaf in natural light.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep it in focus, with as little background as possible.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          LeafImagePreview(image: controller.image!),
          const SizedBox(height: 12),
          Text(
            controller.image!.name,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        if (controller.canCapture) ...[
          PrimaryAction(
            label: 'Take a photo',
            icon: Icons.camera_alt_outlined,
            buttonKey: const ValueKey('capture-image'),
            onPressed: busy ? null : controller.captureImage,
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('choose-image'),
            onPressed: busy ? null : controller.chooseImage,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              controller.choosing
                  ? 'Opening your photos…'
                  : controller.image == null
                  ? 'Choose from gallery'
                  : 'Replace photo',
            ),
          ),
        ),
        if (controller.image != null) ...[
          const SizedBox(height: 16),
          CheckboxListTile(
            key: const ValueKey('confirm-tomato'),
            value: controller.tomatoConfirmed,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: busy
                ? null
                : (value) => controller.confirmTomato(value ?? false),
            title: Text(
              'This is a ${controller.selectedCrop.toLowerCase()} leaf',
            ),
            subtitle: const Text(
              'Your selection does not verify plant identity.',
            ),
          ),
          const SizedBox(height: 16),
          PrimaryAction(
            label: controller.analyzing
                ? 'Examining your leaf…'
                : 'Analyze leaf',
            icon: Icons.auto_awesome_outlined,
            buttonKey: const ValueKey('analyze-image'),
            onPressed: controller.canAnalyze ? controller.analyze : null,
          ),
          if (!controller.tomatoConfirmed && !busy) ...[
            const SizedBox(height: 8),
            Text(
              'Confirm your crop above to begin.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          TextButton.icon(
            onPressed: busy ? null : controller.clearImage,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Remove photo'),
          ),
        ],
        if (controller.analyzing) ...[
          const SizedBox(height: 20),
          const AnalysisLoadingView(),
        ],
        if (controller.error != null) ...[
          const SizedBox(height: 20),
          FriendlyErrorView(
            title: 'Let’s try that again',
            message: controller.error!,
            action: controller.dismissError,
            actionLabel: 'Dismiss',
          ),
        ],
        if (controller.connection != BackendConnection.ready) ...[
          const SizedBox(height: 16),
          OfflineStatusIndicator(controller: controller),
          if (controller.connection != BackendConnection.checking)
            TextButton(
              onPressed: controller.refreshHealth,
              child: const Text('Check local model'),
            ),
        ],
        const SizedBox(height: 20),
        Text(
          'JPEG, PNG or WebP · up to 10 MiB and 20 megapixels. Your photo stays on this device.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _changeCrop(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose your crop',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            CropGrid(
              crops: controller.supportedCrops,
              selected: controller.selectedCrop,
              onSelect: (crop) {
                controller.selectCrop(crop);
                Navigator.pop(sheet);
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(sheet),
              child: const Text('Keep current crop'),
            ),
          ],
        ),
      ),
    ),
  );
}

class LeafImagePreview extends StatelessWidget {
  const LeafImagePreview({
    super.key,
    required this.image,
    this.compact = false,
  });
  final SelectedLeaf image;
  final bool compact;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: SizedBox(
          width: double.infinity,
          height: compact
              ? 160
              : (constraints.maxWidth * image.height / image.width).clamp(
                  160.0,
                  420.0,
                ),
          child: Image.memory(
            image.bytes,
            key: const ValueKey('leaf-preview'),
            fit: BoxFit.contain,
            cacheWidth: image.width > 900 ? 900 : image.width,
            semanticLabel: 'Selected leaf photograph',
            errorBuilder: (_, _, _) => const Center(
              child: Text('Preview unavailable. Choose another photo.'),
            ),
          ),
        ),
      ),
    ),
  );
}

class AnalysisLoadingView extends StatelessWidget {
  const AnalysisLoadingView({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: EvergreenPanel(
      key: const ValueKey('analysis-progress'),
      child: Column(
        children: [
          if (MediaQuery.disableAnimationsOf(context))
            const Icon(Icons.hourglass_empty_rounded, size: 32)
          else
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          const SizedBox(height: 16),
          Text(
            'Examining your leaf…',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Comparing with the model’s leaf examples, entirely on your device.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You can explore while we work. Your result will wait here.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _Mismatch extends StatelessWidget {
  const _Mismatch({required this.controller, required this.changeCrop});
  final AnalysisController controller;
  final VoidCallback changeCrop;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const EditorialHeading(
        'Let’s take\nanother look.',
        'We couldn’t confidently match this photo to your selected crop.',
      ),
      const SizedBox(height: 24),
      LeafImagePreview(image: controller.image!, compact: true),
      const SizedBox(height: 20),
      EvergreenPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.compare_arrows_rounded,
              size: 30,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'You selected ${controller.selectedCrop}.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'The model found a closer match among another crop’s examples. Check your selection or try a clearer photograph.',
            ),
            const SizedBox(height: 12),
            Text(
              'No diagnosis or treatment guidance is shown. Crop selection does not verify identity.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            ExpansionTile(
              title: const Text('See the original model comparison'),
              children: [
                PredictionScores(scores: controller.cropMismatch!.topThree),
                const SizedBox(height: 12),
                Text(controller.cropMismatch!.confidenceNote),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      PrimaryAction(
        label: 'Change crop',
        onPressed: changeCrop,
        icon: Icons.eco_outlined,
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: controller.clearImage,
          child: const Text('Try another photo'),
        ),
      ),
    ],
  );
}
