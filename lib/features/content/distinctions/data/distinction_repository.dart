import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../core/api/paginated.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import '../../../../core/utils/date_only.dart';
import 'distinction.dart';

final distinctionRepositoryProvider = Provider<DistinctionRepository>(
  (ref) => DistinctionRepository(ref.watch(apiClientProvider)),
);

/// `GET|POST|PUT|DELETE /v1/distinctions`.
class DistinctionRepository {
  const DistinctionRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Distinction>> list({required int page, String search = '', String? status}) async {
    final json = await _api.get(
      '/v1/distinctions',
      query: {'page': page, 'per_page': 50, 'search': search, 'status': status},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Distinction.fromJson(item));
  }

  Future<Distinction> get(int id) async =>
      Distinction.fromJson(await _api.get('/v1/distinctions/$id') as Map<String, dynamic>);

  /// `id == null` : création (`POST`), sinon `PUT`. [contextType] `null`
  /// détache la distinction de son contexte.
  Future<Distinction> save({
    int? id,
    required Translated title,
    required String issuer,
    required Translated description,
    required DateTime awardedOn,
    required String? url,
    required DistinctionContextType? contextType,
    required int? contextId,
    required PublicationStatus status,
    required int sortOrder,
  }) async {
    final data = {
      'title': title.toJson(),
      'issuer': issuer,
      'description': description.toJson(),
      'awarded_on': formatDateOnly(awardedOn),
      'url': url,
      'context_type': contextType?.wireValue,
      'context_id': contextType == null ? null : contextId,
      'status': status.wireValue,
      'sort_order': sortOrder,
    };
    final json = id == null
        ? await _api.post('/v1/distinctions', data: data)
        : await _api.put('/v1/distinctions/$id', data: data);
    return Distinction.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/distinctions/$id');
}
