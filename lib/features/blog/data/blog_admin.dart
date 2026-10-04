import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import '../../../core/models/translated.dart';

/// Tag du blog : nom bilingue (l'anglais est traduit par IA à la création,
/// corrigeable ici) et nombre d'articles qui le portent.
@immutable
class PostTag {
  const PostTag({required this.id, required this.slug, required this.name, required this.postsCount});

  factory PostTag.fromJson(Map<String, dynamic> json) => PostTag(
    id: json['id'] as int,
    slug: json['slug'] as String,
    name: Translated.fromJson(json['name']),
    postsCount: json['posts_count'] as int? ?? 0,
  );

  final int id;
  final String slug;
  final Translated name;
  final int postsCount;
}

enum SubscriberStatus {
  active('active', 'Actif'),
  pending('pending', 'En attente'),
  unsubscribed('unsubscribed', 'Désabonné');

  const SubscriberStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static SubscriberStatus fromWire(String? value) =>
      values.firstWhere((s) => s.wireValue == value, orElse: () => SubscriberStatus.pending);
}

/// Abonné à la newsletter du blog : inscription confirmée par e-mail.
@immutable
class Subscriber {
  const Subscriber({
    required this.id,
    required this.email,
    required this.locale,
    required this.status,
    required this.confirmedAt,
    required this.unsubscribedAt,
    required this.createdAt,
  });

  factory Subscriber.fromJson(Map<String, dynamic> json) => Subscriber(
    id: json['id'] as int,
    email: json['email'] as String,
    locale: json['locale'] as String? ?? 'fr',
    status: SubscriberStatus.fromWire(json['status'] as String?),
    confirmedAt: _date(json['confirmed_at']),
    unsubscribedAt: _date(json['unsubscribed_at']),
    createdAt: _date(json['created_at']),
  );

  static DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse(value as String)?.toLocal();

  final int id;
  final String email;

  /// Langue des e-mails envoyés : `fr` ou `en`.
  final String locale;
  final SubscriberStatus status;
  final DateTime? confirmedAt;
  final DateTime? unsubscribedAt;
  final DateTime? createdAt;
}

/// Compteurs par statut, renvoyés avec la liste des abonnés (`summary`).
@immutable
class SubscriberSummary {
  const SubscriberSummary({this.active = 0, this.pending = 0, this.unsubscribed = 0});

  factory SubscriberSummary.fromJson(Map<String, dynamic>? json) => SubscriberSummary(
    active: json?['active'] as int? ?? 0,
    pending: json?['pending'] as int? ?? 0,
    unsubscribed: json?['unsubscribed'] as int? ?? 0,
  );

  final int active;
  final int pending;
  final int unsubscribed;
}

final blogAdminRepositoryProvider = Provider<BlogAdminRepository>(
  (ref) => BlogAdminRepository(ref.watch(apiClientProvider)),
);

final subscriberSummaryProvider = FutureProvider.autoDispose<SubscriberSummary>(
  (ref) => ref.watch(blogAdminRepositoryProvider).subscriberSummary(),
);

/// `GET|PUT|DELETE /v1/post-tags` (les tags se créent avec les articles) et
/// `GET|DELETE /v1/subscribers`.
class BlogAdminRepository {
  const BlogAdminRepository(this._api);

  final ApiClient _api;

  Future<Paginated<PostTag>> tags({required int page, String search = ''}) async {
    final json = await _api.get(
      '/v1/post-tags',
      query: {'page': page, 'per_page': 50, 'search': search},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => PostTag.fromJson(item));
  }

  /// Les deux langues sont exigées (40 caractères chacune).
  Future<PostTag> updateTag(int id, Translated name) async =>
      PostTag.fromJson(await _api.put('/v1/post-tags/$id', data: {'name': name.toJson()}) as Map<String, dynamic>);

  /// Définitif : le tag est retiré des articles qui le portent.
  Future<void> deleteTag(int id) => _api.delete('/v1/post-tags/$id');

  Future<Paginated<Subscriber>> subscribers({
    required int page,
    String search = '',
    String? status,
    String? locale,
  }) async {
    final json = await _api.get(
      '/v1/subscribers',
      query: {'page': page, 'per_page': 50, 'search': search, 'status': status, 'locale': locale},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Subscriber.fromJson(item));
  }

  Future<SubscriberSummary> subscriberSummary() async {
    final json = await _api.get('/v1/subscribers', query: {'page': 1, 'per_page': 10}) as Map<String, dynamic>;
    return SubscriberSummary.fromJson(json['summary'] as Map<String, dynamic>?);
  }

  /// Définitif : l'adresse pourra se réinscrire depuis le blog.
  Future<void> deleteSubscriber(int id) => _api.delete('/v1/subscribers/$id');
}
