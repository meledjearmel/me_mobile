import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../core/api/paginated.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import 'skill.dart';

final skillRepositoryProvider = Provider<SkillRepository>((ref) => SkillRepository(ref.watch(apiClientProvider)));

/// `GET|POST|PUT|DELETE /v1/skills` (§4.3).
class SkillRepository {
  const SkillRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Skill>> list({required int page, String search = '', int? domainId, String? status}) async {
    final json = await _api.get(
      '/v1/skills',
      query: {'page': page, 'per_page': 25, 'search': search, 'domain_id': domainId, 'status': status},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Skill.fromJson(item));
  }

  Future<Skill> get(int id) async => Skill.fromJson(await _api.get('/v1/skills/$id') as Map<String, dynamic>);

  /// [technologies] : ids dans l'ordre choisi, conservé par l'API (§4.3).
  Future<Skill> save({
    int? id,
    required int domainId,
    required Translated name,
    required Translated description,
    required Translated details,
    required List<int> technologies,
    required int sortOrder,
    required PublicationStatus status,
  }) async {
    final data = {
      'domain_id': domainId,
      'name': name.toJson(),
      'description': description.toJson(),
      'details': details.toJson(),
      'technologies': technologies,
      'sort_order': sortOrder,
      'status': status.wireValue,
    };
    final json = id == null ? await _api.post('/v1/skills', data: data) : await _api.put('/v1/skills/$id', data: data);
    return Skill.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/skills/$id');
}
