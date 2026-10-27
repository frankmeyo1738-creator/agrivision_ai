import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../evergreen/components.dart';
import '../evergreen/explore.dart' show AboutAgriVision;
import '../evergreen/result.dart' show CareRecommendations;
import 'guide_controller.dart';
import 'library.dart';

String guideDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class GuideArt extends StatelessWidget {
  const GuideArt({
    super.key,
    required this.asset,
    required this.alt,
    this.height,
  });
  final String asset, alt;
  final double? height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: SizedBox(
      width: double.infinity,
      height: height,
      child: SvgPicture.asset(asset, fit: BoxFit.cover, semanticsLabel: alt),
    ),
  );
}

class FieldGuideExplore extends StatefulWidget {
  const FieldGuideExplore({
    super.key,
    required this.guide,
    required this.openArticle,
    required this.metadata,
    required this.retryMetadata,
    this.metadataFailed = false,
  });
  final GuideController guide;
  final ValueChanged<GuideArticle> openArticle;
  final Map<String, dynamic>? metadata;
  final VoidCallback retryMetadata;
  final bool metadataFailed;
  @override
  State<FieldGuideExplore> createState() => _FieldGuideExploreState();
}

class _FieldGuideExploreState extends State<FieldGuideExplore> {
  final search = TextEditingController();
  final searchAnchor = GlobalKey();
  String category = 'All';
  String? crop;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void updateBrowse(VoidCallback change) {
    setState(change);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anchor = searchAnchor.currentContext;
      if (anchor != null) {
        Scrollable.ensureVisible(
          anchor,
          duration: evergreenMotion(context),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    });
  }

  void reset() => updateBrowse(() {
    search.clear();
    category = 'All';
    crop = null;
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.guide,
    builder: (context, _) {
      final guide = widget.guide, library = guide.library;
      if (library == null) {
        return FriendlyErrorView(
          title: guide.failed
              ? 'Your library needs attention'
              : 'Opening your field guide…',
          message:
              'Every guide is bundled on this device. No connection is needed.',
          action: guide.loading ? null : guide.loadLibrary,
          actionLabel: 'Open guides again',
        );
      }
      final browsing =
          search.text.trim().isEmpty && category == 'All' && crop == null;
      final entries = library
          .search(
            query: search.text,
            category: category,
            crop: crop,
            saved: guide.saved,
          )
          .where((a) => !browsing || !a.isProfile)
          .toList();
      final text = Theme.of(context).textTheme,
          colors = Theme.of(context).colorScheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EditorialHeading(
            'Know your crops.',
            'A field guide for curious growers. Saved on your device, ready wherever you grow.',
          ),
          const SizedBox(height: 24),
          if (browsing) ...[
            Material(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(26),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('guide-featured'),
                onTap: () =>
                    widget.openArticle(library.byId('growing-observation')!),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GuideArt(
                      asset: 'assets/field_guide/art/field.svg',
                      alt:
                          'Original illustration of a young plant over rolling fields',
                      height: 148,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'The Evergreen field guide',
                            style: text.bodySmall!.copyWith(
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Small observations.\nHealthier habits.',
                            style: text.headlineLarge!.copyWith(
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Build a calmer growing routine',
                                  style: text.bodyMedium!.copyWith(
                                    color: colors.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
          KeyedSubtree(
            key: searchAnchor,
            child: TextField(
              key: const ValueKey('guide-search'),
              controller: search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              onChanged: (_) => updateBrowse(() {}),
              decoration: InputDecoration(
                labelText: 'Search the field guide',
                hintText: 'Crop, symptom or scientific name',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () => updateBrowse(search.clear),
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final item in const {
                'All': 'All',
                'Crop profile': 'Crops',
                'Disease guide': 'Diseases',
                'Pest guide': 'Pests',
                'Growing tips': 'Growing',
                'Saved': 'Saved',
              }.entries)
                ChoiceChip(
                  key: ValueKey('guide-filter-${item.key}'),
                  label: Text(item.value),
                  selected: category == item.key,
                  onSelected: (_) => updateBrowse(() => category = item.key),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!browsing || category != 'All')
            ExpansionTile(
              title: Text(crop == null ? 'Filter by crop' : 'Crop: $crop'),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('Any crop'),
                      selected: crop == null,
                      onSelected: (_) => updateBrowse(() => crop = null),
                    ),
                    for (final a in library.articles.where((a) => a.isProfile))
                      ChoiceChip(
                        label: Text(a.title),
                        selected: crop == a.title,
                        onSelected: (_) => updateBrowse(() => crop = a.title),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          if (guide.storageError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(guide.storageError!, style: text.bodySmall),
            ),
          if (browsing) ...[
            const SizedBox(height: 24),
            Text('The crop collection', style: text.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Four crops to scan. Six to understand.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 600 ? 3 : 2;
                final width =
                    (constraints.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    for (final a in library.articles.where((a) => a.isProfile))
                      SizedBox(
                        width: width,
                        child: Material(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(22),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: ValueKey('guide-crop-${a.id}'),
                            onTap: () => widget.openArticle(a),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AspectRatio(
                                  aspectRatio: 1.6,
                                  child: GuideArt(
                                    asset: a.image['asset'] as String,
                                    alt: a.image['alt'] as String,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(a.title, style: text.titleMedium),
                                      const SizedBox(height: 6),
                                      Text(
                                        a.modelClasses.isEmpty
                                            ? 'Education only'
                                            : 'Leaf AI supported',
                                        style: text.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
          ],
          Text(
            browsing
                ? 'Read the leaves'
                : category == 'Saved'
                ? 'Your saved reading'
                : '${entries.length} ${entries.length == 1 ? 'guide' : 'guides'} found',
            style: text.headlineMedium,
          ),
          const SizedBox(height: 8),
          if (browsing)
            Text(
              'Symptoms are clues. Context completes the picture.',
              style: text.bodyMedium,
            ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            EvergreenPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    category == 'Saved'
                        ? Icons.bookmark_outline
                        : Icons.search_off_rounded,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    category == 'Saved'
                        ? 'Keep something worth returning to.'
                        : 'No guides match yet.',
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category == 'Saved'
                        ? 'Save an article with its bookmark button. It stays here for offline reading.'
                        : 'Try a crop name or fewer words. The initial collection is intentionally small.',
                  ),
                  TextButton(
                    onPressed: reset,
                    child: const Text('Browse all guides'),
                  ),
                ],
              ),
            ),
          for (final a in entries)
            ArticleRow(
              article: a,
              guide: guide,
              open: () => widget.openArticle(a),
            ),
          const SizedBox(height: 28),
          EvergreenPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What AI can recognize', style: text.titleLarge),
                const SizedBox(height: 12),
                const Text(
                  'Leaf comparisons for Tomato, Maize, ordinary Potato and Bell Pepper, across the existing fourteen classes. A model score is not a confirmed diagnosis.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cabbage, Collard Greens, insects, pest damage and other conditions are education only. Crop selection does not verify species.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          NewsSection(guide: guide),
          const SizedBox(height: 28),
          if (widget.metadata != null)
            AboutAgriVision(metadata: widget.metadata!)
          else
            FriendlyErrorView(
              title: widget.metadataFailed
                  ? 'Model details unavailable'
                  : 'Opening model details',
              message: 'This does not affect the field guide.',
              action: widget.retryMetadata,
              actionLabel: 'Reload details',
            ),
        ],
      );
    },
  );
}

class BookmarkButton extends StatelessWidget {
  const BookmarkButton({super.key, required this.article, required this.guide});
  final GuideArticle article;
  final GuideController guide;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: guide,
    builder: (_, _) {
      final saved = guide.saved.contains(article.id);
      return IconButton(
        key: ValueKey('bookmark-${article.id}'),
        tooltip: saved ? 'Remove saved article' : 'Save article',
        isSelected: saved,
        selectedIcon: const Icon(Icons.bookmark_rounded),
        icon: const Icon(Icons.bookmark_outline_rounded),
        onPressed: !guide.storageReady || guide.pending.contains(article.id)
            ? null
            : () => guide.toggleSaved(article.id),
      );
    },
  );
}

class ArticleRow extends StatelessWidget {
  const ArticleRow({
    super.key,
    required this.article,
    required this.guide,
    required this.open,
  });
  final GuideArticle article;
  final GuideController guide;
  final VoidCallback open;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              key: ValueKey('guide-article-${article.id}'),
              borderRadius: BorderRadius.circular(16),
              onTap: open,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 62,
                      height: 66,
                      child: GuideArt(
                        asset: article.image['asset'] as String,
                        alt: article.image['alt'] as String,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article.kind,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            article.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            article.isProfile
                                ? article.scientificName
                                : article.crops.join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          BookmarkButton(article: article, guide: guide),
        ],
      ),
      const Divider(height: 1),
    ],
  );
}

class GuideArticlePage extends StatelessWidget {
  const GuideArticlePage({
    super.key,
    required this.article,
    required this.guide,
    this.metadata,
    this.scan,
    this.scanContext,
  });
  final GuideArticle article;
  final GuideController guide;
  final Map<String, dynamic>? metadata;
  final VoidCallback? scan;
  final String? scanContext;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final body = text.bodyLarge!.copyWith(fontSize: 18, height: 1.65);
    final library = guide.library!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Field guide'),
        actions: [
          BookmarkButton(article: article, guide: guide),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: guide,
          builder: (context, _) => SingleChildScrollView(
            key: const ValueKey('article-scroll'),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GuideArt(
                        asset: article.image['asset'] as String,
                        alt: article.image['alt'] as String,
                        height: 190,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Original illustration · not a symptom photograph',
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: 28),
                      Text(article.kind, style: text.bodyMedium),
                      const SizedBox(height: 8),
                      Text(
                        article.title,
                        key: const ValueKey('article-title'),
                        style: text.displaySmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        article.scientificName,
                        style: text.bodyLarge!.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(article.summary, style: body),
                      const SizedBox(height: 24),
                      EvergreenPanel(
                        child: Text(
                          article.modelClasses.isEmpty
                              ? article.crops.every(
                                      (c) =>
                                          c == 'Cabbage' ||
                                          c == 'Collard Greens',
                                    )
                                    ? 'Education only. AI cannot diagnose this crop or condition.'
                                    : 'Education only. AI does not identify pests or assess growing practices.'
                              : 'AI comparison available for ${article.modelClasses.join(', ')}. Other conditions are unsupported; a model match does not confirm disease.',
                          style: text.bodyMedium,
                        ),
                      ),
                      if (scanContext != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Opened from your model match: $scanContext. Reading this guide does not confirm that result.',
                          style: text.bodyMedium,
                        ),
                      ],
                      if (guide.storageError != null) ...[
                        const SizedBox(height: 12),
                        Text(guide.storageError!, style: text.bodySmall),
                      ],
                      if (article.strings('symptoms').isNotEmpty) ...[
                        const SizedBox(height: 32),
                        Text('What to look for', style: text.headlineMedium),
                        const SizedBox(height: 16),
                        for (final symptom in article.strings('symptoms'))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(symptom, style: body),
                          ),
                        _SectionSources(
                          ids: article.strings('references'),
                          library: library,
                        ),
                      ],
                      for (final section in article.sections) ...[
                        const SizedBox(height: 32),
                        Text(
                          section['heading'] as String,
                          style: text.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        for (final p in section['paragraphs'] as List)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(p as String, style: body),
                          ),
                        _SectionSources(
                          ids: List<String>.from(section['references'] as List),
                          library: library,
                        ),
                      ],
                      if (metadata != null &&
                          article.modelClasses.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        Text(
                          'Existing crop care guidance',
                          style: text.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'The same locally bundled guidance used in scan results. Expand a condition to read it.',
                        ),
                        for (final label in article.modelClasses)
                          ExpansionTile(
                            key: ValueKey('guide-care-$label'),
                            title: Text(
                              article.isProfile
                                  ? label.substring(
                                      article.crops.first.length + 1,
                                    )
                                  : label,
                            ),
                            children: [
                              Text(
                                (metadata!['guidance'][label]['description']
                                    as String),
                                style: body,
                              ),
                              const SizedBox(height: 16),
                              Text('What you can do', style: text.titleLarge),
                              CareRecommendations(
                                items: List<String>.from(
                                  metadata!['guidance'][label]['management']
                                      as List,
                                ),
                              ),
                              Text('Prevention', style: text.titleLarge),
                              CareRecommendations(
                                items: List<String>.from(
                                  metadata!['guidance'][label]['prevention']
                                      as List,
                                ),
                              ),
                            ],
                          ),
                      ],
                      const SizedBox(height: 32),
                      Text(
                        'Sources & source check',
                        style: text.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Source check: ${guideDate(DateTime.parse(article.reviewed))}\n${article.data['review_type']}.',
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'References describe US growing conditions. Adapt advice to local climate and seek local agricultural guidance. Source links need internet; this article does not.',
                      ),
                      for (final id in article.strings('references'))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                library.references[id]!['publisher'] as String,
                                style: text.bodySmall,
                              ),
                              TextButton(
                                onPressed: () => openPublisher(
                                  context,
                                  library.references[id]!['title'] as String,
                                  library.references[id]!['url'] as String,
                                ),
                                child: Text(
                                  library.references[id]!['title'] as String,
                                ),
                              ),
                              SelectableText(
                                library.references[id]!['url'] as String,
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ExpansionTile(
                        title: const Text('Illustration & reuse rights'),
                        children: [
                          Text(
                            '${article.image['creator']} · ${article.image['license']}. ${article.image['source']}. Stylized artwork is decorative, not an identification reference.',
                            style: text.bodySmall,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text('Continue exploring', style: text.headlineMedium),
                      const SizedBox(height: 12),
                      for (final id in article.strings('related'))
                        ArticleRow(
                          article: library.byId(id)!,
                          guide: guide,
                          open: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => GuideArticlePage(
                                article: library.byId(id)!,
                                guide: guide,
                                metadata: metadata,
                              ),
                            ),
                          ),
                        ),
                      if (scan != null &&
                          article.isProfile &&
                          article.modelClasses.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        PrimaryAction(
                          label: 'Scan ${article.crops.first.toLowerCase()}',
                          onPressed: scan,
                          icon: Icons.document_scanner_outlined,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionSources extends StatelessWidget {
  const _SectionSources({required this.ids, required this.library});
  final List<String> ids;
  final FieldLibrary library;
  @override
  Widget build(BuildContext context) => ids.isEmpty
      ? const SizedBox.shrink()
      : Text(
          'Source: ${ids.map((id) => library.references[id]!['title']).join(' · ')}',
          style: Theme.of(context).textTheme.bodySmall,
        );
}

Future<void> openPublisher(
  BuildContext context,
  String title,
  String url,
) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheet) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(sheet).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text(
              'Open ${uri.host} in your browser. The publisher’s article requires internet and may describe regional conditions. Your leaf photos are not sent.',
            ),
            const SizedBox(height: 16),
            PrimaryAction(
              label: 'Open publisher website',
              icon: Icons.open_in_new_rounded,
              onPressed: () async {
                var opened = false;
                try {
                  opened = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                } catch (e) {
                  debugPrint('Publisher link: ${e.runtimeType}');
                }
                if (!sheet.mounted) return;
                if (opened) {
                  Navigator.pop(sheet);
                } else {
                  ScaffoldMessenger.of(sheet).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Couldn’t open the browser. You can copy the source link.',
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            SelectableText(url, style: Theme.of(sheet).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class NewsSection extends StatelessWidget {
  const NewsSection({super.key, required this.guide});
  final GuideController guide;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('From the wider field', style: text.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Optional headlines from UMN Extension Crop News · Minnesota, United States. Topics may extend beyond AgriVision’s supported crops.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (!guide.newsEnabled)
          EvergreenPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.rss_feed_rounded),
                const SizedBox(height: 12),
                Text('A living feed, on your terms.', style: text.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Enable online headline updates when you want them. We save the latest titles for offline browsing and check at most once a day when you open Explore. No background downloads or publisher photos.',
                ),
                const SizedBox(height: 16),
                PrimaryAction(
                  label: 'Enable headline updates',
                  icon: Icons.refresh_rounded,
                  onPressed: guide.storageReady
                      ? () => guide.setNewsEnabled(true)
                      : null,
                ),
              ],
            ),
          )
        else ...[
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                key: const ValueKey('news-refresh'),
                onPressed: guide.refreshing ? null : guide.refreshNews,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  guide.refreshing
                      ? 'Checking headlines…'
                      : 'Refresh headlines',
                ),
              ),
              TextButton(
                onPressed: guide.refreshing
                    ? null
                    : () => guide.setNewsEnabled(false),
                child: const Text('Turn updates off'),
              ),
            ],
          ),
          Text(
            guide.checkedAt == null
                ? 'No saved headlines yet.'
                : 'Saved headlines · checked ${guideDate(guide.checkedAt!.toLocal())}',
            style: text.bodySmall,
          ),
          if (guide.newsError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(guide.newsError!, style: text.bodyMedium),
            ),
          for (final n in guide.headlines)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => openPublisher(context, n.title, n.url),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UMN Extension · ${guideDate(n.published)}',
                          style: text.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(n.title, style: text.titleMedium),
                        const SizedBox(height: 12),
                        Text(
                          'Read at the publisher ↗ · internet needed',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (guide.headlines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Headlines are publisher metadata, not locally reviewed agricultural guidance. Full news articles and their images are not cached.',
              style: text.bodySmall,
            ),
          ],
        ],
      ],
    );
  }
}
