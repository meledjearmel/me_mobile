import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import 'trash_item.dart';

final trashRepositoryProvider = Provider<TrashRepository>((ref) => TrashRepository(ref.watch(apiClientProvider)));

/// `GET /trash`, `PATCH|DELETE /trash/{type}/{id}` (§4.5) : fusionne toutes
/// les ressources supprimées en une seule liste, triée par date de
/// suppression décroissante.
class TrashRepository {
  const TrashRepository(this._api);

  final ApiClient _api;

  Future<Paginated<TrashItem>> list({required int page, String search = '', String? type}) async {
    final json = await _api.get(
      '/v1/trash',
      query: {'page': page, 'per_page': 25, 'search': search, 'type': type},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => TrashItem.fromJson(item));
  }

  /// Restaure l'élément : il redevient visible dans sa liste normale.
  Future<void> restore(String type, int id) => _api.patch('/v1/trash/$type/$id');

  /// Suppression définitive, irréversible.
  Future<void> destroy(String type, int id) => _api.delete('/v1/trash/$type/$id');
}
