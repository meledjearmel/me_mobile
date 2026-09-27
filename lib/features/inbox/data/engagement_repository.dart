import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import 'engagement.dart';

final engagementRepositoryProvider = Provider<EngagementRepository>(
  (ref) => EngagementRepository(ref.watch(apiClientProvider)),
);

/// `GET|PUT|DELETE /v1/engagements` — pas de création (§4.2).
class EngagementRepository {
  const EngagementRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Engagement>> list({
    required int page,
    String search = '',
    String? type,
    String? status,
  }) async {
    final json = await _api.get(
      '/v1/engagements',
      query: {'page': page, 'per_page': 25, 'search': search, 'type': type, 'status': status},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Engagement.fromJson(item));
  }

  Future<Engagement> get(int id) async =>
      Engagement.fromJson(await _api.get('/v1/engagements/$id') as Map<String, dynamic>);

  Future<Engagement> updateStatus(int id, EngagementStatus status) async => Engagement.fromJson(
        await _api.put('/v1/engagements/$id', data: {'status': status.wireValue}) as Map<String, dynamic>,
      );

  Future<void> delete(int id) => _api.delete('/v1/engagements/$id');
}
