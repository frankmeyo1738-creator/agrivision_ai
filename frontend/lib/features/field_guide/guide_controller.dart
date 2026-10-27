import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'library.dart';
import 'storage.dart';
import 'news.dart';

class GuideController extends ChangeNotifier {
  GuideController({
    GuideStore? store,
    Future<FieldLibrary> Function()? loader,
    Future<List<NewsHeadline>> Function()? fetchNews,
    DateTime Function()? now,
  }) : _store = store ?? LocalGuideStore(),
       _loader = loader ?? FieldLibrary.load,
       _fetchNews = fetchNews ?? ExtensionNewsSource().fetch,
       _now = now ?? DateTime.now;
  final GuideStore _store;
  final Future<FieldLibrary> Function() _loader;
  final Future<List<NewsHeadline>> Function() _fetchNews;
  final DateTime Function() _now;
  FieldLibrary? library;
  bool loading = false, failed = false, storageReady = false;
  bool newsEnabled = false, refreshing = false;
  String? storageError, newsError;
  Set<String> saved = {}, pending = {};
  List<NewsHeadline> headlines = [];
  DateTime? checkedAt, attemptedAt;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  Future<void>? _started;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() =>
      _started ??= Future.wait([loadLibrary(), _restore()]).then((_) {});

  Future<void> loadLibrary() async {
    if (loading) return;
    loading = true;
    failed = false;
    _emit();
    try {
      library = await _loader();
    } catch (e) {
      failed = true;
      debugPrint('Field guide load: ${e.runtimeType}');
    } finally {
      loading = false;
      _emit();
    }
  }

  Future<void> _restore() async {
    try {
      final raw = await _store.read('bookmarks');
      if (raw != null) {
        try {
          saved = Set<String>.from(jsonDecode(raw) as List);
        } catch (e) {
          storageError =
              'Saved reading could not be restored. Your articles are still available.';
        }
      }
      newsEnabled = await _store.read('news_consent') == 'true';
      attemptedAt = DateTime.tryParse(
        await _store.read('news_attempted_at') ?? '',
      );
      final cache = await _store.read('news_cache');
      if (cache != null) {
        try {
          if (cache.length > 10000) {
            throw const FormatException('Oversized cache');
          }
          final j = jsonDecode(cache) as Map<String, dynamic>;
          checkedAt = DateTime.tryParse(j['checked_at'] as String? ?? '');
          headlines = (j['items'] as List)
              .take(8)
              .map(
                (j) =>
                    NewsHeadline.fromJson(Map<String, dynamic>.from(j as Map)),
              )
              .whereType<NewsHeadline>()
              .toList();
          if (headlines.isEmpty) checkedAt = null;
        } catch (e) {
          headlines = [];
          checkedAt = null;
          newsError =
              'Saved headlines could not be restored. You can refresh when connected.';
        }
      }
      storageReady = true;
    } catch (e) {
      // Never block the bundled articles or model because preferences fail.
      newsEnabled = false;
      storageError =
          'Local saves are unavailable. You can still read every guide.';
      debugPrint('Field guide preferences: ${e.runtimeType}');
    }
    _emit();
  }

  Future<void> toggleSaved(String id) async {
    if (!storageReady || pending.contains(id) || library?.byId(id) == null) {
      return;
    }
    pending.add(id);
    _emit();
    _writes = _writes.then((_) async {
      final next = Set<String>.from(saved);
      next.contains(id) ? next.remove(id) : next.add(id);
      try {
        await _store.write('bookmarks', jsonEncode(next.toList()));
        saved = next;
        storageError = null;
      } catch (e) {
        storageError = 'We couldn’t save this change. Please try again.';
        debugPrint('Bookmark write: ${e.runtimeType}');
      } finally {
        pending.remove(id);
        _emit();
      }
    });
    await _writes;
  }

  Future<void> setNewsEnabled(bool enabled) async {
    if (!storageReady || refreshing) return;
    try {
      await _store.write('news_consent', '$enabled');
      newsEnabled = enabled;
      newsError = null;
      _emit();
    } catch (e) {
      storageError = 'Your news preference could not be saved.';
      _emit();
      return;
    }
    if (enabled) await refreshNews();
  }

  Future<void> enteredExplore() async {
    if (!newsEnabled || !storageReady || refreshing) return;
    final last = attemptedAt ?? checkedAt;
    if (last == null || _now().difference(last) >= const Duration(hours: 24)) {
      await refreshNews();
    }
  }

  Future<void> refreshNews() async {
    if (!newsEnabled || !storageReady || refreshing || _disposed) return;
    refreshing = true;
    newsError = null;
    attemptedAt = _now();
    _emit();
    try {
      await _store.write(
        'news_attempted_at',
        attemptedAt!.toUtc().toIso8601String(),
      );
      if (_disposed) return;
      final fresh = await _fetchNews();
      if (fresh.isEmpty ||
          fresh.length > 8 ||
          fresh.any((n) => !safeNewsUrl(Uri.parse(n.url)))) {
        throw const FormatException('Invalid news');
      }
      final date = _now();
      await _store.write(
        'news_cache',
        jsonEncode({
          'checked_at': date.toUtc().toIso8601String(),
          'items': fresh.map((n) => n.toJson()).toList(),
        }),
      );
      if (!_disposed) {
        headlines = fresh;
        checkedAt = date;
      }
    } catch (e) {
      newsError =
          'Headlines couldn’t refresh. Saved headlines and the full field guide still work offline.';
      debugPrint('Extension news: ${e.runtimeType}');
    } finally {
      refreshing = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
