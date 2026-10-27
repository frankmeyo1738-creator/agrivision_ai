import 'package:flutter/material.dart';
import '../analysis_controller.dart';
import 'crop_art.dart';

// Clarify legacy tomato class-count wording without editing stored care text.
String readableDescription(String original) => original.replaceAll(
  'outside the five classes',
  'outside this crop’s supported conditions',
);

Duration evergreenMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 220);

class EditorialHeading extends StatelessWidget {
  const EditorialHeading(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.displaySmall),
      const SizedBox(height: 12),
      Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class EvergreenPanel extends StatelessWidget {
  const EvergreenPanel({
    super.key,
    required this.child,
    this.color,
    this.padding = 24,
  });
  final Widget child;
  final Color? color;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.buttonKey,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final Key? buttonKey;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      key: buttonKey,
      onPressed: onPressed,
      icon: Icon(icon, size: 21),
      label: Text(label, textAlign: TextAlign.center),
    ),
  );
}

class OfflineStatusIndicator extends StatelessWidget {
  const OfflineStatusIndicator({super.key, required this.controller});
  final AnalysisController controller;
  @override
  Widget build(BuildContext context) {
    final ready = controller.connection == BackendConnection.ready;
    final loading = controller.connection == BackendConnection.checking;
    final color = ready
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready
                ? Icons.check_circle_outline_rounded
                : loading
                ? Icons.hourglass_empty_rounded
                : Icons.info_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              ready
                  ? 'Ready to scan offline'
                  : loading
                  ? 'Preparing your leaf model…'
                  : 'Model needs attention',
              style: Theme.of(
                context,
              ).textTheme.bodySmall!.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class CropSelectionCard extends StatelessWidget {
  const CropSelectionCard({
    super.key,
    required this.crop,
    required this.onTap,
    this.selected = false,
    this.descriptor,
    this.available = true,
  });
  final String crop;
  final VoidCallback? onTap;
  final bool selected, available;
  final String? descriptor;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: onTap != null,
      selected: selected,
      enabled: available,
      label: available ? null : '$crop, coming next, unavailable',
      child: AnimatedContainer(
        duration: evergreenMotion(context),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: .55)
              : scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: available ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Opacity(
                            opacity: available ? 1 : .45,
                            child: CropIllustration(crop, size: 68),
                          ),
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          color: scheme.primary,
                          size: 22,
                        )
                      else if (!available)
                        Icon(
                          Icons.lock_outline_rounded,
                          color: scheme.onSurfaceVariant,
                          size: 18,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(crop, style: Theme.of(context).textTheme.titleMedium),
                  if (descriptor != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      descriptor!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CropGrid extends StatelessWidget {
  const CropGrid({
    super.key,
    required this.crops,
    required this.onSelect,
    this.selected,
    this.descriptors = false,
  });
  final List<String> crops;
  final ValueChanged<String> onSelect;
  final String? selected;
  final bool descriptors;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth > 640 ? 4 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final crop in crops)
            SizedBox(
              width: width,
              child: CropSelectionCard(
                key: ValueKey('crop-$crop'),
                crop: crop,
                selected: crop == selected,
                onTap: () => onSelect(crop),
                descriptor: descriptors
                    ? switch (crop) {
                        'Tomato' => 'Five leaf conditions',
                        'Maize' => 'Four leaf conditions',
                        'Potato' => 'Ordinary potato leaves',
                        _ => 'Two leaf conditions',
                      }
                    : null,
              ),
            ),
        ],
      );
    },
  );
}

class FriendlyErrorView extends StatelessWidget {
  const FriendlyErrorView({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.actionLabel = 'Try again',
  });
  final String title, message, actionLabel;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => EvergreenPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Semantics(liveRegion: true, child: Text(message)),
        if (action != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: action,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(actionLabel),
          ),
        ],
      ],
    ),
  );
}
