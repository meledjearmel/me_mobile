import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';

/// Élément mentionnable : projet, article, technologie ou expérience.
@immutable
class Mentionable {
  const Mentionable({required this.kind, required this.id, required this.label, this.hint});

  factory Mentionable.fromJson(Map<String, dynamic> json) => Mentionable(
    kind: json['kind'] as String,
    id: json['id'] as int,
    label: json['label'] as String,
    hint: json['hint'] as String?,
  );

  /// `project`, `post`, `technology` ou `experience`.
  final String kind;
  final int id;
  final String label;
  final String? hint;

  /// Syntaxe comprise par le site : `@[App Station](project:12)`.
  String get markup => '@[${label.replaceAll(']', ')')}]($kind:$id)';

  String get kindLabel => switch (kind) {
    'project' => 'Projet',
    'post' => 'Article',
    'technology' => 'Technologie',
    'experience' => 'Expérience',
    _ => kind,
  };

  IconData get icon => switch (kind) {
    'project' => Icons.work_outline_rounded,
    'post' => Icons.article_outlined,
    'technology' => Icons.memory_rounded,
    'experience' => Icons.timeline_rounded,
    _ => Icons.alternate_email_rounded,
  };
}

final mentionRepositoryProvider = Provider<MentionRepository>((ref) => MentionRepository(ref.watch(apiClientProvider)));

/// `GET /v1/posts/mentions?q=…` : 8 résultats au plus ; `q` vide, les premiers éléments.
class MentionRepository {
  const MentionRepository(this._api);

  final ApiClient _api;

  Future<List<Mentionable>> search(String query) async {
    final json = await _api.get('/v1/posts/mentions', query: {'q': query}) as Map<String, dynamic>;
    return [
      for (final item in json['data'] as List<dynamic>? ?? const [])
        if (item is Map<String, dynamic>) Mentionable.fromJson(item),
    ];
  }
}
