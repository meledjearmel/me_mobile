import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../core/api/paginated.dart';
import 'technology.dart';

final technologyRepositoryProvider = Provider<TechnologyRepository>(
  (ref) => TechnologyRepository(ref.watch(apiClientProvider)),
);

/// `GET|POST|PUT|DELETE /v1/technologies` (§4.3).
class TechnologyRepository {
  const TechnologyRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Technology>> list({required int page, String search = '', String? category}) async {
    final json = await _api.get(
      '/v1/technologies',
      query: {'page': page, 'per_page': 25, 'search': search, 'category': category},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Technology.fromJson(item));
  }

  Future<Technology> get(int id) async =>
      Technology.fromJson(await _api.get('/v1/technologies/$id') as Map<String, dynamic>);

  Future<Technology> save({
    int? id,
    required String name,
    required TechnologyCategory category,
    required String? icon,
  }) async {
    final data = {'name': name, 'category': category.wireValue, 'icon': icon};
    final json = id == null
        ? await _api.post('/v1/technologies', data: data)
        : await _api.put('/v1/technologies/$id', data: data);
    return Technology.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/technologies/$id');
}
