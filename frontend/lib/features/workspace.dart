import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/ui.dart';
import 'analysis_controller.dart';
import 'leaf_analysis.dart';
import 'model_page.dart';

class Workspace extends StatefulWidget {
  const Workspace({super.key, required this.controller});
  final AnalysisController controller;

  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  int page = 0;
  final scroll = ScrollController();
  static const titles = ['Overview', 'Leaf analysis', 'About the model'];
  static const icons = [
    Icons.space_dashboard_outlined,
    Icons.document_scanner_outlined,
    Icons.hub_outlined,
  ];

  void selectPage(int value) {
    setState(() => page = value);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1040;
        return Scaffold(
          bottomNavigationBar: widget.controller.isOnDevice && !desktop
              ? NavigationBar(
                  selectedIndex: page,
                  onDestinationSelected: selectPage,
                  destinations: List.generate(
                    3,
                    (index) => NavigationDestination(
                      icon: Icon(icons[index]),
                      label: ['Overview', 'Analyze', 'Model'][index],
                    ),
                  ),
                )
              : null,
          body: SafeArea(
            child: Row(
              children: [
                if (desktop) _sidebar(),
                Expanded(
                  child: Column(
                    children: [
                      _header(desktop),
                      if (!desktop && !widget.controller.isOnDevice)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(
                              3,
                              (index) => ChoiceChip(
                                label: Text(titles[index]),
                                selected: page == index,
                                onSelected: (_) => selectPage(index),
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Scrollbar(
                          controller: scroll,
                          child: SingleChildScrollView(
                            controller: scroll,
                            padding: EdgeInsets.fromLTRB(
                              desktop ? 34 : 20,
                              8,
                              desktop ? 34 : 20,
                              28,
                            ),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1280,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget.controller.connectionMessage !=
                                        null) ...[
                                      Notice(
                                        message: widget
                                            .controller
                                            .connectionMessage!,
                                        error: true,
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                    if (widget.controller.isOnDevice) ...[
                                      Notice(
                                        message: widget.controller.isMultiCrop
                                            ? 'TOMATO, MAIZE, POTATO AND BELL PEPPER LEAVES ONLY · 14 supported crop-condition classes. Crop selection does not verify identity. Other crops and conditions are unsupported.'
                                            : 'TOMATO LEAVES ONLY · Supports healthy, early blight, late blight, bacterial spot and leaf mold. Other crops and conditions are unsupported.',
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                    if (page == 0) _overview(),
                                    if (page == 1)
                                      LeafAnalysis(
                                        controller: widget.controller,
                                      ),
                                    if (page == 2)
                                      ModelPage(controller: widget.controller),
                                    const SizedBox(height: 30),
                                    const Divider(),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'AGRIVISION AI  /  Built for better crop understanding',
                                      style: TextStyle(
                                        color: AppTheme.muted,
                                        fontSize: 10,
                                        letterSpacing: .5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _header(bool desktop) => Padding(
    padding: EdgeInsets.fromLTRB(desktop ? 34 : 20, 24, desktop ? 34 : 20, 24),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 20,
      runSpacing: 12,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!desktop) ...[
              const Icon(Icons.eco, color: AppTheme.forest, size: 24),
              const SizedBox(width: 10),
            ],
            Text(
              desktop ? 'WORKSPACE' : 'AGRIVISION AI',
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1.8,
                color: AppTheme.muted,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('/', style: TextStyle(color: AppTheme.line)),
            ),
            Flexible(
              child: Text(
                titles[page],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: _connectionPill()),
            const SizedBox(width: 10),
            IconButton(
              tooltip: widget.controller.isOnDevice
                  ? 'Check on-device model'
                  : 'Check backend connection',
              onPressed: widget.controller.checkingHealth
                  ? null
                  : widget.controller.refreshHealth,
              icon: widget.controller.checkingHealth
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 20),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _connectionPill() => switch (widget.controller.connection) {
    BackendConnection.ready => StatusPill(
      label: widget.controller.isOnDevice
          ? 'Offline · model ready'
          : 'Model ready',
      color: AppTheme.emerald,
    ),
    BackendConnection.checking => StatusPill(
      label: widget.controller.isOnDevice ? 'Loading model' : 'Connecting',
      color: AppTheme.muted,
    ),
    BackendConnection.modelUnavailable => const StatusPill(
      label: 'Model unavailable',
      color: Color(0xFF9B7027),
    ),
    BackendConnection.offline => StatusPill(
      label: widget.controller.isOnDevice
          ? 'Local model unavailable'
          : 'Backend offline',
      color: Color(0xFFAE4438),
    ),
  };

  Widget _sidebar() => Container(
    width: 224,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: AppTheme.line)),
    ),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.forest,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.eco, color: Color(0xFFD0E5B7), size: 26),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AgriVision',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.6,
                    ),
                  ),
                  Text(
                    'INTELLIGENCE IN GROWTH',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 7,
                      color: AppTheme.muted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 44),
        const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Eyebrow('YOUR WORKSPACE'),
        ),
        const SizedBox(height: 14),
        for (int index = 0; index < 3; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              selected: page == index,
              selectedTileColor: AppTheme.pale,
              selectedColor: AppTheme.forest,
              textColor: AppTheme.muted,
              iconColor: AppTheme.muted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              leading: Icon(icons[index], size: 21),
              title: Text(
                titles[index],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              minLeadingWidth: 20,
              onTap: () => selectPage(index),
            ),
          ),
        const Spacer(),
        if (MediaQuery.sizeOf(context).height >= 720)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.offWhite,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.laptop_mac_outlined,
                  color: AppTheme.emerald,
                  size: 22,
                ),
                SizedBox(height: 12),
                Text(
                  'Local by design',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                SizedBox(height: 6),
                Text(
                  'Your photos stay in this session and the configured backend.',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        Text(
          widget.controller.isMultiCrop
              ? 'MULTI-CROP WORKSPACE'
              : 'TOMATO CROP WORKSPACE',
          style: TextStyle(
            color: AppTheme.muted,
            fontSize: 8,
            letterSpacing: 1.4,
          ),
        ),
      ],
    ),
  );

  Widget _overview() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeading(
        'Your crop intelligence workspace',
        'A closer look at your leaves. A more informed next step.',
      ),
      const SizedBox(height: 24),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.forest, Color(0xFF2C5940)],
            begin: Alignment.centerLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: LayoutBuilder(
          builder: (context, size) => Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow(
                      'SMALL DETAILS. HEALTHIER HARVESTS.',
                      color: Color(0xFFC3D9AF),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'A healthier harvest\nstarts with one leaf.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 35,
                        fontWeight: FontWeight.w500,
                        height: 1.16,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Explore ${widget.controller.supportedCrops.join(', ')} leaf health with a trained AI model and practical care guidance.',
                      style: TextStyle(
                        color: Color(0xFFD0DECD),
                        fontSize: 13,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 25),
                    FilledButton.icon(
                      onPressed: () => selectPage(1),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD5E7B7),
                        foregroundColor: AppTheme.forest,
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 17),
                      label: const Text('Analyze a leaf'),
                    ),
                  ],
                ),
              ),
              if (size.maxWidth > 650)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(
                    Icons.spa_outlined,
                    size: 180,
                    color: Color(0xFFB4CDA1),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 22),
      LayoutBuilder(
        builder: (context, constraints) {
          final tiles = [
            _metric(
              'MODEL STATUS',
              widget.controller.connection == BackendConnection.ready
                  ? 'Ready to analyze'
                  : 'Check connection',
              widget.controller.isOnDevice
                  ? 'Fully on-device · no server needed'
                  : 'Live backend readiness',
              Icons.sensors,
            ),
            _metric(
              'SUPPORTED CLASSES',
              '${widget.controller.classLabels.length} crop-condition classes',
              widget.controller.supportedCrops.join(' · '),
              Icons.eco_outlined,
            ),
            _metric(
              'THIS SESSION',
              '${widget.controller.completedAnalyses} analyses',
              widget.controller.isOnDevice
                  ? 'Completed on-device predictions'
                  : 'Completed API predictions',
              Icons.insights_outlined,
            ),
          ];
          if (constraints.maxWidth < 720) {
            return Column(
              children: [
                for (final tile in tiles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: tile,
                  ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        },
      ),
      const SizedBox(height: 28),
      LeafAnalysis(controller: widget.controller, compact: true),
    ],
  );

  Widget _metric(String label, String value, String note, IconData icon) =>
      SurfaceCard(
        padding: 20,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppTheme.pale,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 23, color: AppTheme.emerald),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(label),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    note,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
