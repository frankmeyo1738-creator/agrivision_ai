import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

const feedHost = 'blog-crop-news.extension.umn.edu';
final feedUri = Uri.https(feedHost, '/feeds/posts/default', {
  'alt': 'rss',
  'max-results': '8',
});

class NewsHeadline {
  const NewsHeadline({
    required this.title,
    required this.url,
    required this.published,
  });
  final String title, url;
  final DateTime published;
  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'published': published.toUtc().toIso8601String(),
  };
  static NewsHeadline? fromJson(Map<String, dynamic> j) {
    final url = Uri.tryParse(j['url'] as String? ?? '');
    final title = (j['title'] as String? ?? '').trim();
    final date = DateTime.tryParse(j['published'] as String? ?? '');
    if (url == null ||
        !safeNewsUrl(url) ||
        title.isEmpty ||
        title.length > 300 ||
        date == null) {
      return null;
    }
    return NewsHeadline(title: title, url: url.toString(), published: date);
  }
}

bool safeNewsUrl(Uri u) =>
    u.scheme == 'https' &&
    u.host == feedHost &&
    u.userInfo.isEmpty &&
    !u.hasPort &&
    RegExp(r'^/\d{4}/\d{2}/[^/]+\.html$').hasMatch(u.path);

/// RSS metadata only. HTML article bodies, scripts and publisher images are ignored.
List<NewsHeadline> parseHeadlines(String source) {
  if (utf8.encode(source).length > 512 * 1024 ||
      RegExp(r'<!DOCTYPE|<!ENTITY', caseSensitive: false).hasMatch(source)) {
    throw const FormatException('Unacceptable feed');
  }
  final document = XmlDocument.parse(source);
  if (document.rootElement.name.local != 'rss') {
    throw const FormatException('Not RSS');
  }
  final result = <NewsHeadline>[], seen = <String>{};
  for (final item in document.findAllElements('item').take(40)) {
    final title = item.getElement('title')?.innerText.trim() ?? '';
    final url = Uri.tryParse(item.getElement('link')?.innerText.trim() ?? '');
    DateTime? date;
    try {
      final rawDate = item.getElement('pubDate')?.innerText ?? '';
      // Blogger's RFC 822 feed uses +0000; HttpDate expects GMT.
      date = HttpDate.parse(rawDate.replaceFirst(RegExp(r' \+0000$'), ' GMT'));
    } on FormatException {
      continue;
    }
    if (title.isEmpty ||
        title.length > 300 ||
        title.contains('<') ||
        url == null ||
        !safeNewsUrl(url) ||
        !seen.add(url.toString())) {
      continue;
    }
    result.add(
      NewsHeadline(title: title, url: url.toString(), published: date),
    );
    if (result.length == 8) break;
  }
  if (result.isEmpty) throw const FormatException('No usable headlines');
  result.sort((a, b) => b.published.compareTo(a.published));
  return result;
}

class ExtensionNewsSource {
  ExtensionNewsSource({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;
  final http.Client Function() _clientFactory;
  Future<List<NewsHeadline>> fetch() async {
    final client = _clientFactory();
    try {
      return await (() async {
        final request = http.Request('GET', feedUri)..followRedirects = false;
        final response = await client.send(request);
        if (response.statusCode != 200) {
          throw const HttpException('Feed unavailable');
        }
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 512 * 1024) {
            throw const FormatException('Feed too large');
          }
          bytes.addAll(chunk);
        }
        return parseHeadlines(utf8.decode(bytes));
      })().timeout(const Duration(seconds: 10));
    } finally {
      client.close();
    }
  }
}
