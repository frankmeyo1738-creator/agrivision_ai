import 'dart:convert';
import 'package:flutter/services.dart';
import '../../core/models/analysis.dart';

class GuideArticle {
  GuideArticle(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get title => data['title'] as String;
  String get kind => data['kind'] as String;
  String get scientificName => data['scientific_name'] as String;
  String get summary => data['summary'] as String;
  String get reviewed => data['last_reviewed'] as String;
  List<String> strings(String key) => List<String>.from(data[key] as List);
  List<String> get crops => strings('crops');
  List<String> get modelClasses => strings('model_classes');
  List<Map<String, dynamic>> get sections =>
      List<Map<String, dynamic>>.from(data['sections'] as List);
  Map<String, dynamic> get image => data['image'] as Map<String, dynamic>;
  bool get isProfile => kind == 'Crop profile';
  String get searchText => [
    title,
    summary,
    scientificName,
    ...crops,
    ...strings('symptoms'),
    ...modelClasses,
    ...sections.expand((s) => [s['heading'], ...(s['paragraphs'] as List)]),
  ].join(' ').toLowerCase();
}

class FieldLibrary {
  FieldLibrary._(this.articles, this.references, this.scanRoutes);
  final List<GuideArticle> articles;
  final Map<String, Map<String, dynamic>> references;
  final Map<String, String> scanRoutes;
  static Future<FieldLibrary> load() async =>
      parse(await rootBundle.loadString('assets/field_guide/library.json'));
  static FieldLibrary parse(String source) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    if (j['schema_version'] != 1) throw const FormatException('Guide version');
    final articles = (j['articles'] as List)
        .map((a) => GuideArticle(Map<String, dynamic>.from(a as Map)))
        .toList();
    final refs = <String, Map<String, dynamic>>{};
    for (final r in j['references'] as List) {
      final ref = Map<String, dynamic>.from(r as Map);
      if (refs.containsKey(ref['id'])) {
        throw const FormatException('Duplicate source');
      }
      refs[ref['id'] as String] = ref;
    }
    final routes = Map<String, String>.from(j['scan_routes'] as Map);
    final ids = articles.map((a) => a.id).toSet();
    if (ids.length != articles.length ||
        articles.isEmpty ||
        routes.length != multiCropClasses.length ||
        !multiCropClasses.every(routes.containsKey)) {
      throw const FormatException('Guide IDs or scan routes');
    }
    for (final a in articles) {
      DateTime.parse(a.reviewed);
      if (a.title.isEmpty ||
          a.scientificName.isEmpty ||
          a.sections.isEmpty ||
          a.strings('references').isEmpty ||
          !a.strings('related').every((id) => ids.contains(id) && id != a.id) ||
          !a.strings('references').every(refs.containsKey) ||
          !a.sections.every(
            (s) => (s['references'] as List).every(refs.containsKey),
          ) ||
          !(a.image['asset'] as String).startsWith('assets/field_guide/art/') ||
          a.image['license'] != 'CC0-1.0') {
        throw const FormatException('Incomplete guide article');
      }
    }
    for (final route in routes.entries) {
      final matches = articles.where((a) => a.id == route.value);
      if (matches.length != 1 ||
          !matches.first.modelClasses.contains(route.key)) {
        throw const FormatException('Incorrect article route');
      }
    }
    return FieldLibrary._(
      List.unmodifiable(articles),
      Map.unmodifiable(refs),
      Map.unmodifiable(routes),
    );
  }

  GuideArticle? byId(String id) {
    for (final a in articles) {
      if (a.id == id) return a;
    }
    return null;
  }

  GuideArticle? forPrediction(String label) =>
      scanRoutes[label] == null ? null : byId(scanRoutes[label]!);
  GuideArticle? crop(String name) {
    for (final a in articles) {
      if (a.isProfile && a.crops.single == name) return a;
    }
    return null;
  }

  List<GuideArticle> search({
    String query = '',
    String category = 'All',
    String? crop,
    Set<String> saved = const {},
  }) {
    final tokens = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty);
    return articles
        .where(
          (a) =>
              (crop == null || a.crops.contains(crop)) &&
              (category == 'All' ||
                  (category == 'Saved'
                      ? saved.contains(a.id)
                      : a.kind == category)) &&
              tokens.every(a.searchText.contains),
        )
        .toList();
  }
}
