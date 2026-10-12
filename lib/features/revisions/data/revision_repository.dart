import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import 'revision.dart';

final revisionRepositoryProvider = Provider<RevisionRepository>(
  (ref) => RevisionRepository(ref.watch(apiClientProvider)),
);

/// `GET /v1/revisions`, `GET /v1/revisions/{id}`, `POST .../apply|reject`.
/// 409 si la révision a déjà été traitée : [ApiException] porte le message.
class RevisionRepository {
  const RevisionRepository(this._api);

  final ApiClient _api;

  /// Les 100 plus récentes du statut demandé.
  Future<List<Revision>> list(RevisionStatus status) async {
    final json = await _api.get('/v1/revisions', query: {'status': status.wireValue}) as Map<String, dynamic>;
    return [
      for (final item in json['data'] as List<dynamic>? ?? const [])
        if (item is Map<String, dynamic>) Revision.fromJson(item),
    ];
  }

  Future<Revision> get(int id) async {
    final json = await _api.get('/v1/revisions/$id') as Map<String, dynamic>;
    return Revision.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<RevisionStatus> apply(int id) => _decide(id, 'apply');

  Future<RevisionStatus> reject(int id) => _decide(id, 'reject');

  Future<RevisionStatus> _decide(int id, String action) async {
    final json = await _api.post('/v1/revisions/$id/$action') as Map<String, dynamic>;
    return RevisionStatus.fromWire((json['data'] as Map<String, dynamic>?)?['status'] as String?);
  }
}
