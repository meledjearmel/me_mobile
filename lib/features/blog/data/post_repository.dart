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
/// n'édite pas leur corps HTML : un article modifié renvoie son corps tel quel,
/// un nouvel article part d'un premier jet à terminer dans l'admin web.
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
      if (cover != null) 'cover': cover,
    }, method: id == null ? null : 'PUT');
    final json = await _api.upload(id == null ? '/v1/posts' : '/v1/posts/$id', form, onProgress: onProgress);
    return Post.fromJson(json as Map<String, dynamic>);
  }

  Future<Post> deleteCover(int id) async =>
      Post.fromJson(await _api.delete('/v1/posts/$id/cover') as Map<String, dynamic>);

  Future<void> delete(int id) => _api.delete('/v1/posts/$id');
}
