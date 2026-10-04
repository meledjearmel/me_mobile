import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../core/api/paginated.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import 'uses_item.dart';

final usesItemRepositoryProvider = Provider<UsesItemRepository>(
  (ref) => UsesItemRepository(ref.watch(apiClientProvider)),
);

/// `GET|POST|PUT|DELETE /v1/uses-items`, triés par rubrique puis par ordre.
class UsesItemRepository {
  const UsesItemRepository(this._api);

  final ApiClient _api;

  Future<Paginated<UsesItem>> list({required int page, String search = '', String? category, String? status}) async {
    final json = await _api.get(
      '/v1/uses-items',
      query: {'page': page, 'per_page': 50, 'search': search, 'category': category, 'status': status},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => UsesItem.fromJson(item));
  }

  Future<UsesItem> get(int id) async => UsesItem.fromJson(await _api.get('/v1/uses-items/$id') as Map<String, dynamic>);

  /// `id == null` : création.
  Future<UsesItem> save({
    int? id,
    required UsesCategory category,
    required String name,
    required Translated description,
    required String? url,
    required PublicationStatus status,
    required int sortOrder,
  }) async {
    final data = {
      'category': category.wireValue,
      'name': name,
      'description': description.toJson(),
      'url': url,
      'status': status.wireValue,
      'sort_order': sortOrder,
    };
    final json = id == null
        ? await _api.post('/v1/uses-items', data: data)
        : await _api.put('/v1/uses-items/$id', data: data);
    return UsesItem.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/uses-items/$id');
}
