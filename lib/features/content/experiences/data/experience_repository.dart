import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../core/api/paginated.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import '../../../../core/utils/date_only.dart';
import 'experience.dart';

final experienceRepositoryProvider = Provider<ExperienceRepository>(
  (ref) => ExperienceRepository(ref.watch(apiClientProvider)),
);

/// `GET|POST|PUT|DELETE /v1/experiences` (§4.3).
class ExperienceRepository {
  const ExperienceRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Experience>> list({required int page, String search = '', String? status}) async {
    final json = await _api.get(
      '/v1/experiences',
      query: {'page': page, 'per_page': 25, 'search': search, 'status': status},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Experience.fromJson(item));
  }

  Future<Experience> get(int id) async =>
      Experience.fromJson(await _api.get('/v1/experiences/$id') as Map<String, dynamic>);

  /// [highlights] : ceux avec un `id` sont mis à jour, sans `id` créés, les
  /// points absents de la liste sont supprimés (§4.3).
  Future<Experience> save({
    int? id,
    required String company,
    required Translated role,
    required String? location,
    required DateTime startDate,
    required DateTime? endDate,
    required Translated description,
    required int sortOrder,
    required PublicationStatus status,
    required List<Highlight> highlights,
  }) async {
    final data = {
      'company': company,
      'role': role.toJson(),
      'location': location,
      'start_date': formatDateOnly(startDate),
      'end_date': endDate == null ? null : formatDateOnly(endDate),
      'description': description.toJson(),
      'sort_order': sortOrder,
      'status': status.wireValue,
      'highlights': [for (final h in highlights) h.toJson()],
    };
    final json = id == null
        ? await _api.post('/v1/experiences', data: data)
        : await _api.put('/v1/experiences/$id', data: data);
    return Experience.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/experiences/$id');
}
