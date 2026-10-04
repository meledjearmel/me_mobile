import 'package:flutter/foundation.dart';

import '../../../core/models/publication_status.dart';
import '../../../core/models/translated.dart';

/// Article du blog. Le corps (`body`) est du HTML écrit dans l'éditeur de
/// l'admin web : l'app le lit et le renvoie tel quel, sans l'éditer.
@immutable
class Post {
  const Post({
    required this.id,
    required this.slug,
    required this.title,
    required this.excerpt,
    required this.body,
    required this.readingMinutes,
    required this.isFeatured,
    required this.status,
    required this.publishedAt,
    required this.isLive,
    required this.coverUrl,
    required this.tags,
    required this.updatedAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as int,
    slug: json['slug'] as String,
    title: Translated.fromJson(json['title']),
    excerpt: Translated.fromJson(json['excerpt']),
    body: Translated.fromJson(json['body']),
    readingMinutes: json['reading_minutes'] as int? ?? 0,
    isFeatured: json['is_featured'] as bool? ?? false,
    status: PublicationStatus.fromWire(json['status'] as String?),
    publishedAt: _date(json['published_at']),
    isLive: json['is_live'] as bool? ?? false,
    coverUrl: json['cover_url'] as String?,
    tags: [for (final tag in json['tags'] as List<dynamic>? ?? const []) '$tag'],
    updatedAt: _date(json['updated_at']),
  );

  static DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse(value as String)?.toLocal();

  final int id;
  final String slug;
  final Translated title;
  final Translated excerpt;

  /// HTML, nettoyé par le serveur.
  final Translated body;
  final int readingMinutes;
  final bool isFeatured;
  final PublicationStatus status;

  /// Publié sans date : paraît tout de suite. Une date future programme l'article.
  final DateTime? publishedAt;

  /// Visible sur le site maintenant (publié et date atteinte).
  final bool isLive;
  final String? coverUrl;

  /// Noms des tags, en français.
  final List<String> tags;
  final DateTime? updatedAt;

  /// Publié mais pas encore visible : date de parution à venir.
  bool get isScheduled => status == PublicationStatus.published && !isLive;
}

/// Texte brut d'un corps HTML, pour l'aperçu dans l'app.
String htmlToPlainText(String html) {
  var text = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|h[1-6]|li|blockquote|pre|div)>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  const entities = {'&nbsp;': ' ', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'", '&apos;': "'"};
  entities.forEach((entity, char) => text = text.replaceAll(entity, char));
  text = text.replaceAll('&amp;', '&');
  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// Premier jet saisi dans l'app → HTML : un paragraphe par bloc séparé
/// d'une ligne vide, retours à la ligne simples en `<br>`.
String plainTextToHtml(String text) {
  String escape(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  return text
      .trim()
      .split(RegExp(r'\n\s*\n'))
      .where((block) => block.trim().isNotEmpty)
      .map((block) => '<p>${escape(block.trim()).replaceAll('\n', '<br>')}</p>')
      .join();
}

/// Slug d'URL à partir d'un titre : minuscules, sans accents, tirets.
String slugify(String title) {
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'á': 'a',
    'ã': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'í': 'i',
    'ô': 'o',
    'ö': 'o',
    'ó': 'o',
    'õ': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ú': 'u',
    'ÿ': 'y',
    'ñ': 'n',
    'œ': 'oe',
    'æ': 'ae',
  };
  final lower = title.toLowerCase().split('').map((c) => accents[c] ?? c).join();
  return lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}
