import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/push/push_target.dart';
import 'package:me_mobile/features/inbox/data/appointment.dart';
import 'package:me_mobile/features/inbox/data/appointment_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _appointmentJson = {
  'id': 7,
  'appointment_type': {
    'id': 2,
    'name': {'fr': 'Appel découverte', 'en': 'Discovery call'},
    'duration_minutes': 30,
  },
  'name': 'Bob',
  'email': 'bob@example.com',
  'phone': '+225 07 00 00 00',
  'company': 'ACME',
  'location': 'whatsapp',
  'message': 'Parlons de mon projet',
  'starts_at': '2026-10-07T14:00:00Z',
  'ends_at': '2026-10-07T14:30:00Z',
  'timezone': 'Europe/Paris',
  'locale': 'en',
  'status': 'pending',
  'meeting_details': null,
  'decline_reason': null,
  'confirmed_at': null,
  'cancelled_at': null,
  'created_at': '2026-10-04T09:00:00Z',
};

void main() {
  late FakeDioAdapter adapter;
  late AppointmentRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = AppointmentRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('Appointment.fromJson lit le type, le lieu, le statut et les dates', () {
    final appointment = Appointment.fromJson(_appointmentJson);

    expect(appointment.type!.name.fr, 'Appel découverte');
    expect(appointment.type!.durationMinutes, 30);
    expect(appointment.location, AppointmentLocation.whatsapp);
    expect(appointment.status, AppointmentStatus.pending);
    expect(appointment.startsAt.toUtc(), DateTime.utc(2026, 10, 7, 14));
    expect(appointment.endsAt.difference(appointment.startsAt), const Duration(minutes: 30));
    expect(appointment.locale, 'en');
  });

  test('type supprimé, lieu et statut inconnus : valeurs de repli', () {
    final appointment = Appointment.fromJson({
      ..._appointmentJson,
      'appointment_type': null,
      'location': 'autre',
      'status': 'autre',
    });

    expect(appointment.type, isNull);
    expect(appointment.location, AppointmentLocation.video);
    expect(appointment.status, AppointmentStatus.pending);
  });

  test('confirm envoie les détails de la réunion', () async {
    adapter.whenRequest(
      'POST',
      '/v1/appointments/7/confirm',
      statusCode: 200,
      body: {..._appointmentJson, 'status': 'confirmed', 'meeting_details': 'https://meet.jit.si/armel-dev-7'},
    );

    final updated = await repository.confirm(7, meetingDetails: 'Rendez-vous au bureau');

    expect(adapter.requests.single.data, {'meeting_details': 'Rendez-vous au bureau'});
    expect(updated.status, AppointmentStatus.confirmed);
    expect(updated.meetingDetails, 'https://meet.jit.si/armel-dev-7');
  });

  test('confirm sans détails envoie null (lien de visio par défaut)', () async {
    adapter.whenRequest('POST', '/v1/appointments/7/confirm', statusCode: 200, body: _appointmentJson);

    await repository.confirm(7);

    expect(adapter.requests.single.data, {'meeting_details': null});
  });

  test('decline envoie le motif', () async {
    adapter.whenRequest(
      'POST',
      '/v1/appointments/7/decline',
      statusCode: 200,
      body: {..._appointmentJson, 'status': 'declined', 'decline_reason': 'Indisponible'},
    );

    final updated = await repository.decline(7, reason: 'Indisponible');

    expect(adapter.requests.single.data, {'decline_reason': 'Indisponible'});
    expect(updated.status, AppointmentStatus.declined);
  });

  test('list transmet le statut et le lieu filtrés', () async {
    adapter.whenRequest(
      'GET',
      '/v1/appointments',
      statusCode: 200,
      body: {
        'data': [_appointmentJson],
        'links': {'first': null, 'last': null, 'prev': null, 'next': null},
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 1},
      },
    );

    final page = await repository.list(page: 1, status: 'pending', location: 'video');

    expect(page.items.single.name, 'Bob');
    final query = adapter.requests.single.queryParameters;
    expect(query['status'], 'pending');
    expect(query['location'], 'video');
  });

  test('une notification « appointment » ouvre l\'onglet RDV', () {
    final target = PushTarget.fromData({'type': 'appointment', 'id': '7'});

    expect(target!.type, PushResourceType.appointment);
    expect(target.id, 7);
    expect(target.type.inboxTabIndex, 3);
    expect(target.type.location, '/inbox');
  });
}
