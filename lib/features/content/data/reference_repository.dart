import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import 'refs.dart';

final referenceListRepositoryProvider = Provider<ReferenceListRepository>(
  (ref) => ReferenceListRepository(ref.watch(apiClientProvider)),
);

/// Charge une ressource de référence en entier (§4.4) : `per_page=50` en
/// parcourant toutes les pages, pour remplir un sélecteur de relations.
class ReferenceListRepository {
  const ReferenceListRepository(this._api);

  final ApiClient _api;

  Future<List<T>> fetchAll<T>(String path, T Function(Map<String, dynamic>) fromJson) async {
    final items = <T>[];
    var page = 1;
    while (true) {
      final json = await _api.get(path, query: {'page': page, 'per_page': 50}) as Map<String, dynamic>;
      final result = Paginated.fromJson(json, fromJson);
      items.addAll(result.items);
      if (!result.hasMore) {
        break;
      }
      page++;
    }
    return items;
  }
}

/// Mis en cache : à invalider quand l'utilisateur crée, modifie ou supprime
/// un élément de ces listes (écrans de gestion prévus à l'étape 6).
final domainsRefProvider = FutureProvider<List<DomainRef>>(
  (ref) => ref.watch(referenceListRepositoryProvider).fetchAll('/v1/domains', DomainRef.fromJson),
);

final jobProfilesRefProvider = FutureProvider<List<JobProfileFullRef>>(
  (ref) => ref.watch(referenceListRepositoryProvider).fetchAll('/v1/job-profiles', JobProfileFullRef.fromJson),
);

final technologiesRefProvider = FutureProvider<List<TechnologyRef>>(
  (ref) => ref.watch(referenceListRepositoryProvider).fetchAll('/v1/technologies', TechnologyRef.fromJson),
);

/// Pour le sélecteur de projets liés : l'appelant retire le projet en cours d'édition.
final projectsLiteRefProvider = FutureProvider<List<ProjectLiteRef>>(
  (ref) => ref.watch(referenceListRepositoryProvider).fetchAll('/v1/projects', ProjectLiteRef.fromJson),
);
