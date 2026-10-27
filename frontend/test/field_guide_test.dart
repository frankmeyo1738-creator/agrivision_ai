import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:agrivision_ai/core/models/analysis.dart';
import 'package:agrivision_ai/features/field_guide/library.dart';
import 'package:agrivision_ai/features/field_guide/guide_controller.dart';
import 'package:agrivision_ai/features/field_guide/news.dart';
import 'package:agrivision_ai/features/field_guide/field_guide.dart';
import 'package:agrivision_ai/features/evergreen/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'field_guide_support.dart';

const rss =
    '<rss><channel><item><title>Corn &amp; its leaves</title><link>https://blog-crop-news.extension.umn.edu/2026/10/corn.html</link><pubDate>Mon, 12 Oct 2026 16:46:57 +0000</pubDate><description><![CDATA[<img src="https://example.com/not-reused.jpg"/>Body is ignored]]></description></item></channel></rss>';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = testLibrary();
  final manifest =
      jsonDecode(File('assets/models/model_manifest.json').readAsStringSync())
          as Map<String, dynamic>;
  test('all 14 exact class routes and six distinct crop identities', () {
    expect(library.scanRoutes.keys.toSet(), multiCropClasses.toSet());
    for (final label in multiCropClasses) {
      final a = library.forPrediction(label)!;
      expect(a.modelClasses, contains(label));
      expect(a.crops, contains(cropForClass(label)));
      expect(a.isProfile, label.endsWith(' Healthy'));
    }
    expect(library.crop('Potato')!.scientificName, 'Solanum tuberosum');
    for (final name in ['Cabbage', 'Collard Greens']) {
      expect(library.crop(name)!.modelClasses, isEmpty);
      expect(library.forPrediction('$name Healthy'), isNull);
    }
    expect(library.articles.where((a) => a.isProfile).length, 6);
    expect(library.articles.length, 16);
  });
  test(
    'local assets, source metadata, unique IDs and related links are complete',
    () {
      for (final a in library.articles) {
        expect(File(a.image['asset'] as String).existsSync(), true);
        expect(a.image['license'], 'CC0-1.0');
        expect(a.image['illustrative_only'], true);
        expect(DateTime.parse(a.reviewed), DateTime(2026, 10, 14));
        for (final id in a.strings('references')) {
          final r = library.references[id]!;
          expect(Uri.parse(r['url'] as String).scheme, 'https');
          expect(r['publisher'], isNotEmpty);
        }
        for (final id in a.strings('related')) {
          expect(library.byId(id), isNotNull);
        }
      }
    },
  );
  test('search includes symptoms, scientific names and AND tokens', () {
    expect(library.search(query: 'solanum tuberosum').single.title, 'Potato');
    expect(library.search(query: 'pustules').single.id, 'maize-common-rust');
    expect(
      library.search(query: 'Maize gray').map((a) => a.id),
      contains('maize-gray-leaf-spot'),
    );
    expect(
      library.search(query: 'SWEET POTATO').map((a) => a.id),
      contains('crop-potato'),
    );
    expect(library.search(query: 'unicorn'), isEmpty);
    expect(library.search(category: 'Pest guide').single.modelClasses, isEmpty);
    expect(
      library.search(category: 'Saved', saved: {'crop-potato'}).single.id,
      'crop-potato',
    );
    expect(library.search(category: 'Disease guide', crop: 'Potato').length, 2);
  });
  test('inconsistent routes and missing source IDs fail closed', () {
    final j = jsonDecode(
      File('assets/field_guide/library.json').readAsStringSync(),
    );
    j['scan_routes']['Potato Healthy'] = 'crop-tomato';
    expect(() => FieldLibrary.parse(jsonEncode(j)), throwsFormatException);
    j['scan_routes']['Potato Healthy'] = 'crop-potato';
    j['articles'][0]['references'] = ['fake-source'];
    expect(() => FieldLibrary.parse(jsonEncode(j)), throwsFormatException);
  });
  test(
    'bookmarks persist through restart and concurrent changes are serialized',
    () async {
      final store = MemoryGuideStore();
      final first = GuideController(store: store, loader: () async => library);
      await first.start();
      await Future.wait([
        first.toggleSaved('crop-potato'),
        first.toggleSaved('early-blight'),
      ]);
      first.dispose();
      final next = GuideController(store: store, loader: () async => library);
      await next.start();
      expect(next.saved, {'crop-potato', 'early-blight'});
      await next.toggleSaved('crop-potato');
      expect(next.saved, {'early-blight'});
      next.dispose();
    },
  );
  test('bookmark write failure never reports a false save', () async {
    final store = MemoryGuideStore();
    final guide = GuideController(store: store, loader: () async => library);
    await guide.start();
    store.fail = true;
    await guide.toggleSaved('crop-potato');
    expect(guide.saved, isEmpty);
    expect(guide.storageError, isNotNull);
    guide.dispose();
  });
  test(
    'storage failures leave the whole library usable and news off',
    () async {
      final guide = GuideController(
        store: MemoryGuideStore()..fail = true,
        loader: () async => library,
      );
      await guide.start();
      expect(guide.library, library);
      expect(guide.storageReady, false);
      expect(guide.newsEnabled, false);
      guide.dispose();
    },
  );
  test(
    'news has no request without consent; daily checks, caching and failed refresh preserve data',
    () async {
      final store = MemoryGuideStore();
      int requests = 0;
      bool fail = false;
      var now = DateTime(2026, 10, 14, 12);
      final guide = GuideController(
        store: store,
        loader: () async => library,
        now: () => now,
        fetchNews: () async {
          requests++;
          if (fail) throw const SocketException('test offline');
          return parseHeadlines(rss);
        },
      );
      await guide.start();
      await guide.enteredExplore();
      await guide.refreshNews();
      expect(requests, 0);
      await guide.setNewsEnabled(true);
      expect(requests, 1);
      expect(guide.headlines.single.title, 'Corn & its leaves');
      await guide.enteredExplore();
      expect(requests, 1);
      now = now.add(const Duration(hours: 25));
      fail = true;
      await guide.enteredExplore();
      expect(requests, 2);
      expect(guide.newsError, isNotNull);
      expect(guide.headlines.length, 1);
      await guide.enteredExplore();
      expect(requests, 2);
      guide.dispose();
      final restored = GuideController(
        store: store,
        loader: () async => library,
      );
      await restored.start();
      expect(restored.headlines.length, 1);
      expect(restored.newsEnabled, true);
      await restored.setNewsEnabled(false);
      expect(restored.headlines.length, 1);
      restored.dispose();
    },
  );
  test(
    'malformed optional cache does not disable bookmarks or the local library',
    () async {
      final store = MemoryGuideStore()..values['news_cache'] = 'broken';
      final g = GuideController(store: store, loader: () async => library);
      await g.start();
      expect(g.storageReady, true);
      expect(g.newsError, isNotNull);
      await g.toggleSaved('crop-potato');
      expect(g.saved, contains('crop-potato'));
      g.dispose();
    },
  );
  test('failed automatic news checks remain bounded after restart', () async {
    final store = MemoryGuideStore()..values['news_consent'] = 'true';
    int calls = 0;
    final now = DateTime(2026, 10, 14);
    Future<List<NewsHeadline>> fetch() async {
      calls++;
      throw const SocketException('test offline');
    }

    final first = GuideController(
      store: store,
      loader: () async => library,
      fetchNews: fetch,
      now: () => now,
    );
    await first.start();
    await first.enteredExplore();
    expect(calls, 1);
    first.dispose();
    final next = GuideController(
      store: store,
      loader: () async => library,
      fetchNews: fetch,
      now: () => now,
    );
    await next.start();
    await next.enteredExplore();
    expect(calls, 1);
    next.dispose();
  });
  test(
    'news refresh is single-flight and disposing does not notify dead widgets',
    () async {
      final pending = Completer<List<NewsHeadline>>();
      int calls = 0;
      final guide = GuideController(
        store: MemoryGuideStore(),
        loader: () async => library,
        fetchNews: () {
          calls++;
          return pending.future;
        },
      );
      await guide.start();
      final request = guide.setNewsEnabled(true);
      await Future<void>.delayed(Duration.zero);
      await guide.refreshNews();
      expect(calls, 1);
      guide.dispose();
      pending.complete(parseHeadlines(rss));
      await request;
    },
  );
  test(
    'RSS excludes external URLs, duplicate entries, bodies, images and DTDs',
    () {
      final parsed = parseHeadlines(rss);
      expect(parsed.single.title, 'Corn & its leaves');
      expect(
        jsonEncode(parsed.map((n) => n.toJson()).toList()),
        isNot(contains('not-reused')),
      );
      expect(
        () => parseHeadlines(
          rss.replaceAll(
            'https://blog-crop-news.extension.umn.edu/2026/10/corn.html',
            'http://example.com/phish',
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => parseHeadlines('<!DOCTYPE rss><rss/>'),
        throwsFormatException,
      );
      expect(
        () => parseHeadlines('x' * (512 * 1024 + 1)),
        throwsFormatException,
      );
      expect(() => parseHeadlines('not xml'), throwsFormatException);
    },
  );
  test(
    'HTTP source sends only fixed feed URL, accepts RSS and rejects failures',
    () async {
      var calls = 0;
      final source = ExtensionNewsSource(
        clientFactory: () => MockClient((r) async {
          calls++;
          expect(r.url, feedUri);
          expect(r.method, 'GET');
          expect(r.body, isEmpty);
          return http.Response(rss, 200);
        }),
      );
      expect((await source.fetch()).length, 1);
      expect(calls, 1);
      final failure = ExtensionNewsSource(
        clientFactory: () =>
            MockClient((_) async => http.Response('unavailable', 503)),
      );
      await expectLater(failure.fetch(), throwsA(isA<HttpException>()));
    },
  );

  setUpAll(() async {
    final directory = Platform.environment['EVERGREEN_FONT_DIR'];
    if (directory == null) return;
    final loader = FontLoader('Roboto');
    for (final file in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(File('$directory/$file').readAsBytesSync()),
        ),
      );
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('$directory/MaterialIcons-Regular.otf').readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
  });
  late GuideController guide;
  setUp(() {
    guide = GuideController(
      store: MemoryGuideStore(),
      loader: () async => library,
    );
  });
  tearDown(() => guide.dispose());
  final visual = GlobalKey();
  Future<void> mount(
    WidgetTester t, {
    double scale = 1,
    Size size = const Size(390, 844),
    bool dark = false,
  }) async {
    await guide.start();
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: dark ? EvergreenTheme.dark : EvergreenTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: RepaintBoundary(key: visual, child: child!),
        ),
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FieldGuideExplore(
                guide: guide,
                metadata: manifest,
                retryMetadata: () {},
                openArticle: (a) => Navigator.push(
                  t.element(find.byType(FieldGuideExplore)),
                  MaterialPageRoute<void>(
                    builder: (_) => GuideArticlePage(
                      article: a,
                      guide: guide,
                      metadata: manifest,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.tap(f);
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    });
    await t.pumpAndSettle();
  }

  Future<void> snapshot(WidgetTester t, String name) async {
    if (Platform.environment['EVERGREEN_VISUAL_QA'] != '1') return;
    await t.pump();
    await t.runAsync(() async {
      final b =
          visual.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final i = await b.toImage(pixelRatio: 2),
          bytes = await i.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('../artifacts/phase5_2_visual')
        ..createSync(recursive: true);
      File(
        '${dir.path}/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      i.dispose();
    });
  }

  testWidgets('Explore search, clear and category empty states', (t) async {
    await mount(t);
    await snapshot(t, 'explore_light');
    await t.ensureVisible(find.byKey(const ValueKey('guide-search')));
    await t.enterText(find.byKey(const ValueKey('guide-search')), 'pustules');
    await t.pumpAndSettle();
    expect(find.text('1 guide found'), findsOneWidget);
    expect(find.text('Maize common rust'), findsOneWidget);
    await tap(t, find.byTooltip('Clear search'));
    await tap(t, find.byKey(const ValueKey('guide-filter-Saved')));
    expect(find.text('Keep something worth returning to.'), findsOneWidget);
    await snapshot(t, 'saved_empty');
    expect(t.takeException(), isNull);
  });
  testWidgets('save action updates Saved filter and survives navigation', (
    t,
  ) async {
    await mount(t);
    expect(guide.storageReady, true);
    expect(
      t
          .widget<IconButton>(
            find.byKey(const ValueKey('bookmark-early-blight')),
          )
          .onPressed,
      isNotNull,
    );
    await tap(t, find.byKey(const ValueKey('bookmark-early-blight')));
    expect(guide.saved, contains('early-blight'));
    await tap(t, find.byKey(const ValueKey('guide-filter-Saved')));
    expect(find.text('Early blight'), findsOneWidget);
    expect(t.getRect(find.text('Your saved reading')).top, lessThan(844));
    await snapshot(t, 'saved_article');
    await tap(t, find.byKey(const ValueKey('guide-article-early-blight')));
    expect(find.byKey(const ValueKey('article-title')), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(guide.saved, contains('early-blight'));
  });
  testWidgets(
    'unsupported crop profiles read offline with no scan action; related pest guide works',
    (t) async {
      await mount(t);
      await tap(
        t,
        find.byKey(const ValueKey('guide-crop-crop-collard-greens')),
      );
      expect(
        find.text('Education only. AI cannot diagnose this crop or condition.'),
        findsOneWidget,
      );
      expect(find.textContaining('Scan collard'), findsNothing);
      await snapshot(t, 'collards');
      await tap(
        t,
        find.byKey(const ValueKey('guide-article-brassica-caterpillars')),
      );
      expect(find.text('Who is chewing the leaves?'), findsOneWidget);
      expect(find.textContaining('does not identify insects'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'disease reader, related reading and source metadata stay available offline',
    (t) async {
      await mount(t);
      await tap(
        t,
        find.byKey(const ValueKey('guide-article-maize-common-rust')),
      );
      expect(find.text('Puccinia sorghi'), findsOneWidget);
      expect(find.textContaining('not confirm disease'), findsOneWidget);
      await snapshot(t, 'rust_article');
      await tap(
        t,
        find.byKey(const ValueKey('guide-article-maize-gray-leaf-spot')),
      );
      expect(find.textContaining('Cercospora zeae-maydis'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets('320px reader and library respect text scaling $scale', (
      t,
    ) async {
      await mount(t, scale: scale, size: const Size(320, 640));
      expect(t.takeException(), isNull);
      await snapshot(t, 'small_$scale');
      await tap(t, find.byKey(const ValueKey('guide-crop-crop-potato')));
      expect(t.takeException(), isNull);
      await snapshot(t, 'reader_small_$scale');
      await t.drag(
        find.byKey(const ValueKey('article-scroll')),
        const Offset(0, -1000),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('dark editorial library renders', (t) async {
    await mount(t, dark: true);
    expect(t.takeException(), isNull);
    await snapshot(t, 'explore_dark');
  });
  testWidgets(
    'guide load failure offers a local retry; storage errors remain honest',
    (t) async {
      guide.dispose();
      guide = GuideController(
        store: MemoryGuideStore()..fail = true,
        loader: () async => throw const FormatException('test'),
      );
      await guide.start();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FieldGuideExplore(
              guide: guide,
              metadata: null,
              retryMetadata: () {},
              openArticle: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Your library needs attention'), findsOneWidget);
      expect(find.text('Open guides again'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
