import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'api_providers.dart';

final contentStatusRepositoryProvider = Provider<ContentStatusRepository>(
  (ref) => ContentStatusRepository(ref.watch(apiClientProvider)),
);

/// `PATCH /v1/status/{type}/{id}` : change seulement le statut d'un contenu,
/// sans renvoyer tout le formulaire. Publier est refusé (422) tant que
/// l'anglais obligatoire manque.
class ContentStatusRepository {
  const ContentStatusRepository(this._api);

  final ApiClient _api;

  /// [type] : `project`, `post`, `experience`, `education`, `certification`,
  /// `distinction`, `uses_item`, `skill` ou `service`. Renvoie le statut enregistré.
  Future<String> update(String type, int id, String status) async {
    final json = await _api.patch('/v1/status/$type/$id', data: {'status': status}) as Map<String, dynamic>;
    return (json['data'] as Map<String, dynamic>)['status'] as String;
  }
}
