import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';

/// Dépôt GitHub de la dernière synchronisation.
@immutable
class GitHubRepository {
  const GitHubRepository({
    required this.fullName,
    required this.name,
    required this.description,
    required this.language,
    required this.stars,
    required this.isPrivate,
    required this.isArchived,
    required this.isContribution,
  });

  factory GitHubRepository.fromJson(Map<String, dynamic> json) => GitHubRepository(
    fullName: json['full_name'] as String,
    name: json['name'] as String? ?? json['full_name'] as String,
    description: json['description'] as String?,
    language: json['language'] as String?,
    stars: json['stars'] as int? ?? 0,
    isPrivate: json['private'] as bool? ?? false,
    isArchived: json['archived'] as bool? ?? false,
    isContribution: json['contribution'] as bool? ?? false,
  );

  /// « propriétaire/nom », l'identifiant envoyé à l'API.
  final String fullName;
  final String name;
  final String? description;
  final String? language;
  final int stars;

  /// Un dépôt privé choisi s'affiche sur le site sans lien.
  final bool isPrivate;
  final bool isArchived;

  /// Dépôt d'un autre compte auquel j'ai contribué.
  final bool isContribution;
}

/// Dépôt travaillé un jour donné.
@immutable
class ContributionRepository {
  const ContributionRepository({required this.fullName, required this.isPrivate, required this.count});

  factory ContributionRepository.fromJson(Map<String, dynamic> json) => ContributionRepository(
    fullName: json['full_name'] as String,
    isPrivate: json['private'] as bool? ?? false,
    count: json['count'] as int? ?? 0,
  );

  final String fullName;
  final bool isPrivate;
  final int count;
}

/// Jour du calendrier de contributions.
@immutable
class ContributionDay {
  const ContributionDay({required this.date, required this.count, required this.level, this.repositories = const []});

  factory ContributionDay.fromJson(Map<String, dynamic> json) => ContributionDay(
    date: DateTime.parse(json['date'] as String),
    count: json['count'] as int? ?? 0,
    level: (json['level'] as int? ?? 0).clamp(0, 4),
    repositories: [
      for (final item in json['repositories'] as List<dynamic>? ?? const [])
        if (item is Map<String, dynamic>) ContributionRepository.fromJson(item),
    ],
  );

  /// Jour local à minuit (`AAAA-MM-JJ`).
  final DateTime date;
  final int count;

  /// Intensité de 0 à 4.
  final int level;
  final List<ContributionRepository> repositories;
}

/// `GET|PUT /v1/github`, `POST /v1/github/sync` : dépôts présentés sur la page À propos.
@immutable
class GitHubSelection {
  const GitHubSelection({
    required this.available,
    required this.selected,
    this.calendar,
    required this.syncedAt,
    required this.hasToken,
  });

  factory GitHubSelection.fromJson(Map<String, dynamic> json) => GitHubSelection(
    available: [
      for (final item in json['available'] is List ? json['available'] as List<dynamic> : const [])
        if (item is Map<String, dynamic>) GitHubRepository.fromJson(item),
    ],
    selected: [for (final name in json['selected'] as List<dynamic>? ?? const []) '$name'],
    calendar: json['calendar'] is List
        ? [
            for (final item in json['calendar'] as List<dynamic>)
              if (item is Map<String, dynamic>) ContributionDay.fromJson(item),
          ]
        : null,
    syncedAt: json['synced_at'] == null ? null : DateTime.tryParse(json['synced_at'] as String)?.toLocal(),
    hasToken: json['has_token'] as bool? ?? false,
  );

  /// 12 dépôts au plus dans la sélection.
  static const maxSelected = 12;

  final List<GitHubRepository> available;

  /// Noms complets choisis, dans l'ordre d'affichage. Vide : choix automatique
  /// parmi mes dépôts publics.
  final List<String> selected;

  /// Contributions jour par jour, du plus ancien au plus récent (~365 jours).
  /// `null` sans jeton GitHub.
  final List<ContributionDay>? calendar;
  final DateTime? syncedAt;

  /// Un jeton GitHub est configuré : contributions et dépôts privés disponibles.
  final bool hasToken;
}

final gitHubRepositoryProvider = Provider<GitHubApi>((ref) => GitHubApi(ref.watch(apiClientProvider)));

class GitHubApi {
  const GitHubApi(this._api);

  final ApiClient _api;

  Future<GitHubSelection> get() async => GitHubSelection.fromJson(await _api.get('/v1/github') as Map<String, dynamic>);

  /// Liste vide : retour au choix automatique.
  Future<GitHubSelection> select(List<String> repositories) async => GitHubSelection.fromJson(
    await _api.put('/v1/github', data: {'repositories': repositories}) as Map<String, dynamic>,
  );

  /// 503 si GitHub n'a pas répondu : la dernière version est conservée.
  Future<GitHubSelection> sync() async =>
      GitHubSelection.fromJson(await _api.post('/v1/github/sync') as Map<String, dynamic>);
}
