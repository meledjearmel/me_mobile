import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../core/api/paginated.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import '../../../../core/utils/date_only.dart';
import 'education.dart';

final educationRepositoryProvider = Provider<EducationRepository>(
  (ref) => EducationRepository(ref.watch(apiClientProvider)),
);

/// `GET|POST|PUT|DELETE /v1/educations` (§4.3).
class EducationRepository {
  const EducationRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Education>> list({required int page, String search = '', String? status}) async {
    final json = await _api.get(
      '/v1/educations',
      query: {'page': page, 'per_page': 25, 'search': search, 'status': status},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Education.fromJson(item));
  }

  Future<Education> get(int id) async =>
      Education.fromJson(await _api.get('/v1/educations/$id') as Map<String, dynamic>);

  Future<Education> save({
    int? id,
    required String institution,
    required Translated degree,
    required Translated field,
    required DateTime startDate,
    required DateTime? endDate,
    required Translated description,
    required int sortOrder,
    required PublicationStatus status,
  }) async {
    final data = {
      'institution': institution,
      'degree': degree.toJson(),
      'field': field.toJson(),
      'start_date': formatDateOnly(startDate),
      'end_date': endDate == null ? null : formatDateOnly(endDate),
      'description': description.toJson(),
      'sort_order': sortOrder,
      'status': status.wireValue,
    };
    final json = id == null
        ? await _api.post('/v1/educations', data: data)
        : await _api.put('/v1/educations/$id', data: data);
    return Education.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/educations/$id');
}
