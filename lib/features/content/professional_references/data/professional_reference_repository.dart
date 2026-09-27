import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../core/api/paginated.dart';
import 'professional_reference.dart';

final professionalReferenceRepositoryProvider = Provider<ProfessionalReferenceRepository>(
  (ref) => ProfessionalReferenceRepository(ref.watch(apiClientProvider)),
);

/// `GET|POST|PUT|DELETE /v1/professional-references` (§4.3).
class ProfessionalReferenceRepository {
  const ProfessionalReferenceRepository(this._api);

  final ApiClient _api;

  Future<Paginated<ProfessionalReference>> list({required int page, String search = '', bool? isPublic}) async {
    final json = await _api.get(
      '/v1/professional-references',
      query: {'page': page, 'per_page': 25, 'search': search, 'is_public': isPublic},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => ProfessionalReference.fromJson(item));
  }

  Future<ProfessionalReference> get(int id) async =>
      ProfessionalReference.fromJson(await _api.get('/v1/professional-references/$id') as Map<String, dynamic>);

  Future<ProfessionalReference> save({
    int? id,
    required String name,
    required String? role,
    required String? company,
    required String? email,
    required String? phone,
    required String? relationship,
    required int? projectId,
    required bool isPublic,
    required List<String> visibleFields,
    required String? notes,
  }) async {
    final data = {
      'name': name,
      'role': role,
      'company': company,
      'email': email,
      'phone': phone,
      'relationship': relationship,
      'project_id': projectId,
      'is_public': isPublic,
      'visible_fields': visibleFields,
      'notes': notes,
    };
    final json = id == null
        ? await _api.post('/v1/professional-references', data: data)
        : await _api.put('/v1/professional-references/$id', data: data);
    return ProfessionalReference.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/professional-references/$id');
}
