import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../core/api/paginated.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import 'domain.dart';

final domainRepositoryProvider = Provider<DomainRepository>((ref) => DomainRepository(ref.watch(apiClientProvider)));

/// `GET|POST|PUT|DELETE /v1/domains` (§4.3).
class DomainRepository {
  const DomainRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Domain>> list({required int page, String search = '', String? status}) async {
    final json = await _api.get(
      '/v1/domains',
      query: {'page': page, 'per_page': 25, 'search': search, 'status': status},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Domain.fromJson(item));
  }

  Future<Domain> get(int id) async => Domain.fromJson(await _api.get('/v1/domains/$id') as Map<String, dynamic>);

  Future<Domain> save({
    int? id,
    required String key,
    required Translated label,
    required String color,
    required String icon,
    required int sortOrder,
    required PublicationStatus status,
  }) async {
    final data = {
      'key': key,
      'label': label.toJson(),
      'color': color,
      'icon': icon,
      'sort_order': sortOrder,
      'status': status.wireValue,
    };
    final json = id == null
        ? await _api.post('/v1/domains', data: data)
        : await _api.put('/v1/domains/$id', data: data);
    return Domain.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/domains/$id');
}
