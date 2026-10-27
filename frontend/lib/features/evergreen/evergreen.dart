import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../analysis_controller.dart';
import 'components.dart';
import 'home.dart';
import 'scan.dart';
import '../field_guide/field_guide.dart';
import '../field_guide/guide_controller.dart';
import '../field_guide/library.dart';

class EvergreenWorkspace extends StatefulWidget {
  const EvergreenWorkspace({super.key, required this.controller, this.guide});
  final AnalysisController controller;
  final GuideController? guide;
  @override
  State<EvergreenWorkspace> createState() => _EvergreenWorkspaceState();
}

class _EvergreenWorkspaceState extends State<EvergreenWorkspace> {
  int page = 0;
  late final GuideController guide;
  Map<String, dynamic>? metadata;
  bool loadingGuides = false;
  bool guideFailed = false;
  final scroll = ScrollController();
  Object? lastOutcome;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_revealOutcome);
    _loadGuides();
    guide = widget.guide ?? GuideController();
    guide.start();
  }

  void _revealOutcome() {
    final outcome =
        widget.controller.prediction ?? widget.controller.cropMismatch;
    if (identical(lastOutcome, outcome)) return;
    lastOutcome = outcome;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || page != 1 || !scroll.hasClients) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        scroll.jumpTo(0);
      } else {
        scroll.animateTo(
          0,
          duration: evergreenMotion(context),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _loadGuides() async {
    if (loadingGuides) return;
    loadingGuides = true;
    try {
      final data =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/models/model_manifest.json',
                ),
              )
              as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          metadata = data;
          guideFailed = false;
        });
      }
    } catch (e) {
      debugPrint('AgriVision: bundled guide load failed (${e.runtimeType}).');
      if (mounted) {
        setState(() => guideFailed = true);
      }
    } finally {
      loadingGuides = false;
    }
  }

  void select(int value) {
    if (value == page) return;
    if (!MediaQuery.disableAnimationsOf(context)) {
      HapticFeedback.selectionClick();
    }
    FocusScope.of(context).unfocus();
    setState(() => page = value);
    if (value == 2) guide.enteredExplore();
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void openCrop(String crop) {
    final article = guide.library?.crop(crop);
    if (article == null) {
      select(2);
      return;
    }
    openArticle(article);
  }

  void openArticle(GuideArticle article, {String? scanContext}) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (route) => GuideArticlePage(
          article: article,
          guide: guide,
          metadata: metadata,
          scanContext: scanContext,
          scan:
              article.isProfile &&
                  widget.controller.supportedCrops.contains(article.crops.first)
              ? () {
                  widget.controller.selectCrop(article.crops.first);
                  Navigator.pop(route);
                  select(1);
                }
              : null,
        ),
      ),
    );
  }

  void openResultGuide(String label) {
    final article = guide.library?.forPrediction(label);
    if (article == null) {
      select(2);
      return;
    }
    openArticle(article, scanContext: label);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_revealOutcome);
    scroll.dispose();
    if (widget.guide == null) guide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Theme.of(
                context,
              ).scaffoldBackgroundColor,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarContrastEnforced: false,
            ),
        child: PopScope(
          canPop: page == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) select(0);
          },
          child: Scaffold(
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: NavigationBar(
                    selectedIndex: page,
                    onDestinationSelected: select,
                    animationDuration: evergreenMotion(context),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.document_scanner_outlined),
                        selectedIcon: Icon(Icons.document_scanner_rounded),
                        label: 'Scan',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.eco_outlined),
                        selectedIcon: Icon(Icons.eco_rounded),
                        label: 'Explore',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                controller: scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  MediaQuery.sizeOf(context).width < 360 ? 20 : 24,
                  16,
                  MediaQuery.sizeOf(context).width < 360 ? 20 : 24,
                  32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.spa_outlined,
                              color: Theme.of(context).colorScheme.primary,
                              size: 21,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'AgriVision AI',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        AnimatedSwitcher(
                          duration: evergreenMotion(context),
                          child: KeyedSubtree(
                            key: ValueKey(page),
                            child: switch (page) {
                              0 => EvergreenHome(
                                controller: widget.controller,
                                scan: () => select(1),
                                openCrop: openCrop,
                              ),
                              1 => EvergreenScan(
                                controller: widget.controller,
                                openGuide: openResultGuide,
                              ),
                              _ => FieldGuideExplore(
                                guide: guide,
                                metadata: metadata,
                                metadataFailed: guideFailed,
                                openArticle: openArticle,
                                retryMetadata: _loadGuides,
                              ),
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
