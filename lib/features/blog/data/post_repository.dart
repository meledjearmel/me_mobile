import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/multipart.dart';
import '../../../core/api/paginated.dart';
import '../../../core/models/publication_status.dart';
import '../../../core/models/translated.dart';
import 'post.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) => PostRepository(ref.watch(apiClientProvider)));

/// Tags déjà utilisés, pour l'autocomplétion.
final postTagsProvider = FutureProvider.autoDispose<List<String>>((ref) => ref.watch(postRepositoryProvider).tags());

/// `GET|POST|PUT|DELETE /v1/posts`, `GET /v1/posts/tags`, `DELETE /v1/posts/{id}/cover`.
///
/// L'app gère les articles (titre, résumé, tags, couverture, statut) mais
/// n'édite pas leur corps HTML : un article modifié renvoie son corps tel quel
/// (ou avec sa traduction anglaise), un nouvel article part d'un premier jet,
/// éventuellement rédigé par l'IA et illustré, à terminer dans l'admin web.
class PostRepository {
  const PostRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Post>> list({required int page, String search = '', String? status, bool? isFeatured}) async {
    final json = await _api.get(
      '/v1/posts',
      query: {'page': page, 'per_page': 25, 'search': search, 'status': status, 'is_featured': isFeatured},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Post.fromJson(item));
  }

  Future<Post> get(int id) async => Post.fromJson(await _api.get('/v1/posts/$id') as Map<String, dynamic>);

  Future<List<String>> tags() async {
    final json = await _api.get('/v1/posts/tags') as Map<String, dynamic>;
    return [for (final tag in json['data'] as List<dynamic>? ?? const []) '$tag'];
  }

  /// `id == null` : création (`POST`), sinon `_method=PUT` (§3.4). Toujours en
  /// multipart, pour pouvoir joindre une [cover] (5 Mo maximum).
  Future<Post> save({
    int? id,
    required Translated title,
    required String slug,
    required Translated excerpt,
    required Translated body,
    required bool isFeatured,
    required PublicationStatus status,
    required DateTime? publishedAt,
    required List<String> tags,
    String? series,
    int? seriesPosition,
    MultipartFile? cover,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = buildFormData({
      'title': title,
      'slug': slug,
      'excerpt': excerpt,
      'body': body,
      'is_featured': isFeatured,
      'status': status.wireValue,
      'published_at': publishedAt?.toUtc().toIso8601String(),
      'tags': tags,
      // Toujours envoyée : vide, l'article sort de sa série ; inconnue, elle est créée.
      'series': series,
      'series_position': series == null ? null : seriesPosition,
      if (cover != null) 'cover': cover,
    }, method: id == null ? null : 'PUT');
    final json = await _api.upload(id == null ? '/v1/posts' : '/v1/posts/$id', form, onProgress: onProgress);
    return Post.fromJson(json as Map<String, dynamic>);
  }

  Future<Post> deleteCover(int id) async =>
      Post.fromJson(await _api.delete('/v1/posts/$id/cover') as Map<String, dynamic>);

  Future<void> delete(int id) => _api.delete('/v1/posts/$id');

  static const _aiTimeout = Duration(seconds: 90);

  /// `POST /v1/posts/images` : envoie une image (5 Mo maximum) et renvoie son
  /// adresse publique, à insérer dans le HTML (`<img src="…">`).
  Future<String> uploadImage(MultipartFile image) async {
    final json = await _api.upload('/v1/posts/images', FormData.fromMap({'image': image})) as Map<String, dynamic>;
    return json['url'] as String;
  }

  /// `POST /v1/ai/write-post` : rédige le passage à insérer après [context]
  /// (ou réécrit [selection]) selon [instruction]. Renvoie du HTML.
  Future<String> writeWithAi({
    required String instruction,
    required String locale,
    String? selection,
    String? context,
    String? title,
    String? excerpt,
  }) async {
    String? clip(String? value, int max) {
      final text = value?.trim() ?? '';
      // Le contexte utile est la fin du texte, juste avant le curseur.
      return text.isEmpty ? null : (text.length > max ? text.substring(text.length - max) : text);
    }

    final json = await _api.post(
      '/v1/ai/write-post',
      data: {
        'instruction': instruction.trim(),
        'locale': locale,
        'selection': clip(selection, 6000),
        'context': clip(context, 6000),
        'title': clip(title, 255),
        'excerpt': clip(excerpt, 300),
      },
      receiveTimeout: _aiTimeout,
    ) as Map<String, dynamic>;
    return json['text'] as String;
  }

  /// `POST /v1/ai/translate-html`, bloc par bloc (6 000 caractères au plus par
  /// appel) : traduit un corps d'article entier en gardant ses balises.
  Future<String> translateHtml({
    required String html,
    required String sourceLocale,
    required String targetLocale,
    void Function(int done, int total)? onProgress,
  }) async {
    final chunks = splitHtmlBlocks(html, maxLength: 6000);
    final translated = StringBuffer();
    for (final (index, chunk) in chunks.indexed) {
      onProgress?.call(index, chunks.length);
      final json = await _api.post(
        '/v1/ai/translate-html',
        data: {'html': chunk, 'source_locale': sourceLocale, 'target_locale': targetLocale},
        receiveTimeout: _aiTimeout,
      ) as Map<String, dynamic>;
      translated.write(json['text'] as String);
    }
    onProgress?.call(chunks.length, chunks.length);
    return translated.toString();
  }
}
