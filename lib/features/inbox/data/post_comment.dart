import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';

enum CommentStatus {
  pending('pending', 'En attente'),
  approved('approved', 'Approuvé'),
  rejected('rejected', 'Rejeté');

  const CommentStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static CommentStatus fromWire(String? value) =>
      values.firstWhere((s) => s.wireValue == value, orElse: () => CommentStatus.pending);
}

/// Commentaire laissé sous un article du blog : affiché sur le site une fois approuvé.
@immutable
class PostComment {
  const PostComment({
    required this.id,
    required this.authorName,
    required this.authorEmail,
    required this.body,
    required this.locale,
    required this.status,
    required this.postId,
    required this.postSlug,
    required this.postTitle,
    required this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    final post = json['post'] is Map<String, dynamic> ? json['post'] as Map<String, dynamic> : null;
    return PostComment(
      id: json['id'] as int,
      authorName: json['author_name'] as String? ?? '',
      authorEmail: json['author_email'] as String?,
      body: json['body'] as String? ?? '',
      locale: json['locale'] as String? ?? 'fr',
      status: CommentStatus.fromWire(json['status'] as String?),
      postId: post?['id'] as int?,
      postSlug: post?['slug'] as String?,
      postTitle: post?['title'] as String?,
      createdAt: json['created_at'] == null ? null : DateTime.tryParse(json['created_at'] as String)?.toLocal(),
    );
  }

  final int id;
  final String authorName;

  /// Jamais affiché sur le site.
  final String? authorEmail;
  final String body;

  /// Langue de la page où le commentaire a été écrit.
  final String locale;
  final CommentStatus status;
  final int? postId;
  final String? postSlug;

  /// Titre français de l'article commenté.
  final String? postTitle;
  final DateTime? createdAt;
}

final postCommentRepositoryProvider = Provider<PostCommentRepository>(
  (ref) => PostCommentRepository(ref.watch(apiClientProvider)),
);

/// `GET /v1/post-comments`, `GET|PUT|DELETE /v1/post-comments/{id}`.
class PostCommentRepository {
  const PostCommentRepository(this._api);

  final ApiClient _api;

  Future<Paginated<PostComment>> list({required int page, String search = '', String? status}) async {
    final json = await _api.get(
      '/v1/post-comments',
      query: {'page': page, 'per_page': 25, 'search': search, 'status': status},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => PostComment.fromJson(item));
  }

  Future<PostComment> get(int id) async =>
      PostComment.fromJson(await _api.get('/v1/post-comments/$id') as Map<String, dynamic>);

  /// `approved` publie le commentaire sous l'article, `rejected` le masque.
  Future<PostComment> moderate(int id, CommentStatus status) async => PostComment.fromJson(
    await _api.put('/v1/post-comments/$id', data: {'status': status.wireValue}) as Map<String, dynamic>,
  );

  /// Vers la corbeille (type `post-comments`).
  Future<void> delete(int id) => _api.delete('/v1/post-comments/$id');
}
