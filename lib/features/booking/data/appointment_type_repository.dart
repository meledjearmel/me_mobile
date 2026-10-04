import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import '../../../core/models/translated.dart';
import '../../inbox/data/appointment.dart';
import 'appointment_type.dart';

final appointmentTypeRepositoryProvider = Provider<AppointmentTypeRepository>(
  (ref) => AppointmentTypeRepository(ref.watch(apiClientProvider)),
);

/// `GET|POST|PUT|DELETE /v1/appointment-types`.
class AppointmentTypeRepository {
  const AppointmentTypeRepository(this._api);

  final ApiClient _api;

  Future<Paginated<AppointmentType>> list({required int page, String search = ''}) async {
    final json = await _api.get(
      '/v1/appointment-types',
      query: {'page': page, 'per_page': 25, 'search': search},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => AppointmentType.fromJson(item));
  }

  Future<AppointmentType> get(int id) async =>
      AppointmentType.fromJson(await _api.get('/v1/appointment-types/$id') as Map<String, dynamic>);

  /// `id == null` : création.
  Future<AppointmentType> save({
    int? id,
    required Translated name,
    required Translated description,
    required int durationMinutes,
    required List<AppointmentLocation> locations,
    required bool isActive,
    required int sortOrder,
  }) async {
    final data = {
      'name': name.toJson(),
      'description': description.toJson(),
      'duration_minutes': durationMinutes,
      'locations': [for (final location in locations) location.wireValue],
      'is_active': isActive,
      'sort_order': sortOrder,
    };
    final json = id == null
        ? await _api.post('/v1/appointment-types', data: data)
        : await _api.put('/v1/appointment-types/$id', data: data);
    return AppointmentType.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/appointment-types/$id');
}
