import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import 'appointment.dart';

final appointmentRepositoryProvider = Provider<AppointmentRepository>(
  (ref) => AppointmentRepository(ref.watch(apiClientProvider)),
);

/// `GET|DELETE /v1/appointments`, `POST …/confirm|decline` — pas de création :
/// les demandes viennent du site.
class AppointmentRepository {
  const AppointmentRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Appointment>> list({required int page, String search = '', String? status, String? location}) async {
    final json = await _api.get(
      '/v1/appointments',
      query: {'page': page, 'per_page': 25, 'search': search, 'status': status, 'location': location},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Appointment.fromJson(item));
  }

  Future<Appointment> get(int id) async =>
      Appointment.fromJson(await _api.get('/v1/appointments/$id') as Map<String, dynamic>);

  /// Sans [meetingDetails], une visio reprend le lien par défaut des réglages
  /// (ou un lien Jitsi unique).
  Future<Appointment> confirm(int id, {String? meetingDetails}) async => Appointment.fromJson(
    await _api.post('/v1/appointments/$id/confirm', data: {'meeting_details': meetingDetails}) as Map<String, dynamic>,
  );

  /// Le créneau est libéré ; [reason] est transmis au visiteur.
  Future<Appointment> decline(int id, {String? reason}) async => Appointment.fromJson(
    await _api.post('/v1/appointments/$id/decline', data: {'decline_reason': reason}) as Map<String, dynamic>,
  );

  Future<void> delete(int id) => _api.delete('/v1/appointments/$id');
}
