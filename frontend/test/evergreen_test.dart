// Presentation fixtures only. The production application uses real native ONNX.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:agrivision_ai/core/models/analysis.dart';
import 'package:agrivision_ai/core/services/agrivision_api.dart';
import 'package:agrivision_ai/core/services/leaf_picker.dart';
import 'package:agrivision_ai/features/analysis_controller.dart';
import 'package:agrivision_ai/features/evergreen/evergreen.dart';
import 'package:agrivision_ai/features/evergreen/theme.dart';
import 'package:agrivision_ai/features/evergreen/scan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';
import 'package:agrivision_ai/features/field_guide/guide_controller.dart';
import 'field_guide_support.dart';

class EvergreenApi extends TestApi implements OnDeviceAgriVisionApi {}

class EvergreenPicker extends TestPicker implements CameraLeafPicker {
  int captures = 0, picks = 0;
  @override
  Future<SelectedLeaf?> capture() async {
    captures++;
    return pick();
  }

  @override
  Future<SelectedLeaf?> pick() async {
    picks++;
    return super.pick();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final directory = Platform.environment['EVERGREEN_FONT_DIR'];
    if (directory == null) return;
    final roboto = FontLoader('Roboto');
    for (final name in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]) {
      roboto.addFont(
        Future.value(
          ByteData.sublistView(File('$directory/$name').readAsBytesSync()),
        ),
      );
    }
    await roboto.load();
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
  late EvergreenApi api;
  late EvergreenPicker picker;
  late AnalysisController controller;
  late GuideController guide;
  final visual = GlobalKey();
  setUp(() {
    api = EvergreenApi()
      ..healthResponse = const BackendHealth(
        modelLoaded: true,
        classLabels: multiCropClasses,
      );
    picker = EvergreenPicker();
    controller = AnalysisController(api: api, picker: picker);
    guide = GuideController(
      store: MemoryGuideStore(),
      loader: () async => testLibrary(),
    );
  });
  tearDown(() {
    controller.dispose();
    guide.dispose();
  });
  Future<void> mount(
    WidgetTester t, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool dark = false,
    bool ready = true,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    if (ready) await controller.refreshHealth();
    await guide.start();
    await t.runAsync(
      () => rootBundle.loadString('assets/models/model_manifest.json'),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: dark ? EvergreenTheme.dark : EvergreenTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: RepaintBoundary(
          key: visual,
          child: EvergreenWorkspace(controller: controller, guide: guide),
        ),
      ),
    );
    await t.runAsync(() async {
      await rootBundle.loadString('assets/models/model_manifest.json');
      await Future<void>.delayed(const Duration(milliseconds: 1));
    });
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> tab(WidgetTester t, String s) => tap(t, find.text(s).last);
  Future<void> image(WidgetTester t) async {
    await tab(t, 'Scan');
    await tap(t, find.byKey(const ValueKey('choose-image')));
  }

  Future<void> snapshot(WidgetTester t, String name) async {
    if (Platform.environment['EVERGREEN_VISUAL_QA'] != '1') return;
    await t.pump();
    await t.runAsync(() async {
      final b =
          visual.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final i = await b.toImage(pixelRatio: 2),
          d = Directory('../artifacts/phase5_visual')
            ..createSync(recursive: true);
      final bytes = await i.toByteData(format: ui.ImageByteFormat.png);
      File('${d.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      i.dispose();
    });
  }

  testWidgets(
    'welcoming Home, real readiness and three-destination navigation',
    (t) async {
      await mount(t);
      expect(find.text('Grow with\nconfidence.'), findsOneWidget);
      expect(find.text('Ready to scan offline'), findsOneWidget);
      await snapshot(t, 'home_light');
      await tab(t, 'Explore');
      expect(find.text('Know your crops.'), findsOneWidget);
      await snapshot(t, 'explore');
      await tab(t, 'Scan');
      expect(find.text('A closer look.'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'crop guides contain existing recommendations and model details',
    (t) async {
      await mount(t);
      await tab(t, 'Explore');
      await tap(t, find.byKey(const ValueKey('guide-crop-crop-potato')));
      expect(
        find.textContaining('Sweet potato (Ipomoea batatas)'),
        findsOneWidget,
      );
      await tap(t, find.text('Healthy').last);
      expect(find.text('What you can do'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await tap(t, find.text('About the model'));
      expect(find.textContaining('ONNX Runtime Android'), findsOneWidget);
    },
  );
  testWidgets('educational future crops remain outside the classifier scope', (
    t,
  ) async {
    await mount(t);
    await tab(t, 'Explore');
    await tap(t, find.byKey(const ValueKey('guide-crop-crop-cabbage')));
    controller.selectCrop('Collard Greens');
    expect(controller.selectedCrop, 'Tomato');
    expect(
      find.text('Education only. AI cannot diagnose this crop or condition.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'crop selection resets confirmation and uses explicit selected state',
    (t) async {
      await mount(t);
      await image(t);
      controller.confirmTomato(true);
      await t.pumpAndSettle();
      await tap(t, find.text('Maize').last);
      expect(controller.selectedCrop, 'Maize');
      expect(controller.tomatoConfirmed, false);
      expect(controller.canAnalyze, false);
    },
  );
  testWidgets(
    'camera and gallery preserve selected bytes and preview aspect ratio',
    (t) async {
      await mount(t);
      await tab(t, 'Scan');
      await tap(t, find.byKey(const ValueKey('capture-image')));
      expect(picker.captures, 1);
      expect(controller.image!.bytes, testLeaf().bytes);
      expect(find.byType(LeafImagePreview), findsOneWidget);
      expect(
        t.widget<Image>(find.byKey(const ValueKey('leaf-preview'))).fit,
        BoxFit.contain,
      );
      await tap(t, find.byKey(const ValueKey('choose-image')));
      expect(picker.picks, 2);
      await snapshot(t, 'image_review');
    },
  );
  testWidgets('gallery cancel retains the previous photo', (t) async {
    await mount(t);
    await image(t);
    final previous = controller.image;
    picker.selection = null;
    await tap(t, find.byKey(const ValueKey('choose-image')));
    expect(identical(controller.image, previous), true);
    expect(controller.error, isNull);
  });
  testWidgets(
    'analyze availability requires image, crop confirmation and ready model',
    (t) async {
      await mount(t);
      await tab(t, 'Scan');
      expect(find.byKey(const ValueKey('analyze-image')), findsNothing);
      await snapshot(t, 'scan_empty');
      await tap(t, find.byKey(const ValueKey('choose-image')));
      expect(
        t
            .widget<FilledButton>(find.byKey(const ValueKey('analyze-image')))
            .onPressed,
        isNull,
      );
      await tap(t, find.byKey(const ValueKey('confirm-tomato')));
      expect(controller.canAnalyze, true);
    },
  );
  testWidgets(
    'honest loading blocks duplicate requests and permits safe navigation',
    (t) async {
      await mount(t);
      await image(t);
      await tap(t, find.byKey(const ValueKey('confirm-tomato')));
      final pending = Completer<LeafPrediction>();
      api.prediction = () => pending.future;
      await tap(t, find.byKey(const ValueKey('analyze-image')));
      expect(find.byKey(const ValueKey('analysis-progress')), findsOneWidget);
      await snapshot(t, 'loading');
      await controller.analyze();
      expect(api.predictionCalls, 1);
      await tab(t, 'Explore');
      pending.complete(testPrediction());
      await t.pumpAndSettle();
      await tab(t, 'Scan');
      expect(find.text('Healthy'), findsOneWidget);
    },
  );
  testWidgets(
    'healthy result preserves confidence and care, then allows a new scan',
    (t) async {
      await mount(t);
      await image(t);
      controller.confirmTomato(true);
      await controller.analyze();
      await t.pumpAndSettle();
      expect(find.text('Closest healthy match'), findsOneWidget);
      expect(find.text('Model match: 91.0%'), findsOneWidget);
      expect(find.text('Water at the base.'), findsOneWidget);
      await snapshot(t, 'healthy_result');
      await tap(t, find.text('Scan another leaf'));
      expect(controller.image, isNull);
      expect(controller.prediction, isNull);
    },
  );
  testWidgets(
    'successful scan opens its exact local guide without losing the result',
    (t) async {
      await mount(t);
      await image(t);
      controller.confirmTomato(true);
      await controller.analyze();
      await t.pumpAndSettle();
      final original = controller.prediction;
      await tap(t, find.byKey(const ValueKey('result-field-guide')));
      expect(find.text('Solanum lycopersicum'), findsOneWidget);
      expect(
        find.textContaining('Opened from your model match: Tomato Healthy'),
        findsOneWidget,
      );
      await t.pageBack();
      await t.pumpAndSettle();
      expect(identical(controller.prediction, original), true);
      expect(find.text('Model match: 91.0%'), findsOneWidget);
    },
  );
  testWidgets('disease result is qualified and keeps cross-crop scores', (
    t,
  ) async {
    final j = predictionJson();
    j['predicted_class'] = 'Tomato Early Blight';
    j['confidence'] = .945;
    j['top_predictions'] = [
      {'class': 'Tomato Early Blight', 'confidence': .945},
      {'class': 'Tomato Late Blight', 'confidence': .04},
      {'class': 'Potato Late Blight', 'confidence': .01},
    ];
    api.prediction = () async => LeafPrediction.fromJson(j);
    await mount(t);
    await image(t);
    controller.confirmTomato(true);
    await controller.analyze();
    await t.pumpAndSettle();
    expect(find.text('Possible condition'), findsOneWidget);
    expect(find.text('Model match: 94.5%'), findsOneWidget);
    expect(find.text('Potato Late Blight'), findsOneWidget);
    await snapshot(t, 'disease_result');
  });
  testWidgets(
    'mismatch retains genuine output and withholds diagnosis and treatment',
    (t) async {
      await mount(t);
      await image(t);
      controller.selectCrop('Potato');
      controller.confirmTomato(true);
      final result = testPrediction();
      api.prediction = () async => result;
      await controller.analyze();
      await t.pumpAndSettle();
      expect(controller.prediction, isNull);
      expect(identical(controller.cropMismatch, result), true);
      expect(find.text('What you can do'), findsNothing);
      expect(find.byKey(const ValueKey('result-field-guide')), findsNothing);
      expect(
        find.textContaining('We couldn’t confidently match'),
        findsOneWidget,
      );
      await snapshot(t, 'crop_mismatch');
      await tap(t, find.text('See the original model comparison'));
      expect(find.text('Tomato Healthy'), findsOneWidget);
      await tap(t, find.text('Change crop'));
      await tap(t, find.text('Maize').last);
      expect(controller.cropMismatch, isNull);
      expect(controller.tomatoConfirmed, false);
    },
  );
  testWidgets(
    'permission or invalid-image errors produce friendly state, not a result',
    (t) async {
      picker.error = const ImageSelectionException(
        'Camera access denied. Choose a gallery photo.',
      );
      await mount(t);
      await tab(t, 'Scan');
      await tap(t, find.byKey(const ValueKey('capture-image')));
      expect(find.text('Let’s try that again'), findsOneWidget);
      expect(find.textContaining('Camera access denied'), findsOneWidget);
      expect(controller.image, isNull);
      await snapshot(t, 'image_error');
    },
  );
  testWidgets('inference error never creates false success', (t) async {
    api.prediction = () async => throw const ApiException(
      'The local model could not run. Please retry.',
    );
    await mount(t);
    await image(t);
    controller.confirmTomato(true);
    await controller.analyze();
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('predicted-class')), findsNothing);
    expect(
      find.textContaining('The local model could not run'),
      findsOneWidget,
    );
  });
  testWidgets('loading and unavailable models never claim ready', (t) async {
    await mount(t, ready: false);
    expect(find.text('Preparing your leaf model…'), findsOneWidget);
    expect(find.text('Ready to scan offline'), findsNothing);
    api.healthResponse = const BackendHealth(modelLoaded: false);
    await controller.refreshHealth();
    await t.pumpAndSettle();
    expect(find.text('Model needs attention'), findsOneWidget);
    expect(controller.canAnalyze, false);
    await snapshot(t, 'model_unavailable');
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('320px phone with text scaling $scale does not overflow', (
      t,
    ) async {
      await mount(t, size: const Size(320, 640), scale: scale);
      expect(t.takeException(), isNull);
      await tab(t, 'Scan');
      expect(t.takeException(), isNull);
      await tab(t, 'Explore');
      expect(t.takeException(), isNull);
      await snapshot(t, 'small_text_$scale');
    });
  }
  testWidgets(
    'system back returns from Scan to Home without clearing a photo',
    (t) async {
      await mount(t);
      await image(t);
      final original = controller.image;
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Grow with\nconfidence.'), findsOneWidget);
      expect(identical(controller.image, original), true);
    },
  );
  testWidgets('large text result keeps scores and care readable', (t) async {
    await mount(t, size: const Size(320, 640), scale: 2);
    await image(t);
    controller.confirmTomato(true);
    await controller.analyze();
    await t.pumpAndSettle();
    expect(find.text('Model match: 91.0%'), findsOneWidget);
    expect(t.takeException(), isNull);
    await tap(t, find.text('How was this result calculated?'));
    expect(t.takeException(), isNull);
    await snapshot(t, 'result_text_2');
  });
  testWidgets('dark palette renders without overflow', (t) async {
    await mount(t, dark: true);
    expect(t.takeException(), isNull);
    await snapshot(t, 'home_dark');
  });
}
