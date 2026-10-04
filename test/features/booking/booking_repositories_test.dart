import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/booking/data/appointment_type.dart';
import 'package:me_mobile/features/booking/data/appointment_type_repository.dart';
import 'package:me_mobile/features/booking/data/availability.dart';
import 'package:me_mobile/features/booking/data/availability_repository.dart';
import 'package:me_mobile/features/inbox/data/appointment.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _typeJson = {
  'id': 2,
  'name': {'fr': 'Appel découverte', 'en': 'Discovery call'},
  'description': [],
  'duration_minutes': 30,
  'locations': ['video', 'phone'],
  'is_active': false,
  'sort_order': 1,
};

const _availabilityJson = {
  'rules': [
    {
      'id': 1,
      'days': ['wednesday', 'monday'],
      'start': '09:00',
      'end': '12:00',
    },
  ],
  'blocked_periods': [
    {'id': 5, 'label': 'Congés', 'from': '2026-12-20', 'to': '2027-01-02'},
  ],
};

void main() {
  late FakeDioAdapter adapter;
  late ApiClient api;

  setUp(() {
    adapter = FakeDioAdapter();
    api = ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter);
  });

  group('Types de rendez-vous', () {
    test('fromJson lit la durée, les lieux et l\'état', () {
      final type = AppointmentType.fromJson(_typeJson);

      expect(type.name.fr, 'Appel découverte');
      expect(type.description.isEmpty, isTrue);
      expect(type.durationMinutes, 30);
      expect(type.locations, [AppointmentLocation.video, AppointmentLocation.phone]);
      expect(type.isActive, isFalse);
    });

    test('save sans id crée en POST, avec id modifie en PUT', () async {
      final repository = AppointmentTypeRepository(api);
      adapter.whenRequest('POST', '/v1/appointment-types', statusCode: 201, body: _typeJson);
      adapter.whenRequest('PUT', '/v1/appointment-types/2', statusCode: 200, body: _typeJson);

      Future<void> save(int? id) => repository.save(
        id: id,
        name: const Translated(fr: 'Appel', en: 'Call'),
        description: const Translated(),
        durationMinutes: 45,
        locations: const [AppointmentLocation.inPerson, AppointmentLocation.whatsapp],
        isActive: true,
        sortOrder: 0,
      );

      await save(null);
      await save(2);

      expect(adapter.requests.map((r) => r.method), ['POST', 'PUT']);
      final body = adapter.requests.last.data as Map;
      expect(body['duration_minutes'], 45);
      expect(body['locations'], ['in_person', 'whatsapp']);
      expect(body['name'], {'fr': 'Appel', 'en': 'Call'});
      expect(body['is_active'], isTrue);
    });
  });

  group('Disponibilités', () {
    test('fromJson trie les jours et lit les périodes bloquées', () {
      final availability = Availability.fromJson(_availabilityJson);

      final rule = availability.rules.single;
      expect(rule.days, [Weekday.monday, Weekday.wednesday]);
      expect(rule.daysLabel, 'Lun, Mer');
      expect(rule.start, '09:00');
      final period = availability.blockedPeriods.single;
      expect(period.label, 'Congés');
      expect(period.to, DateTime(2027, 1, 2));
    });

    test('addRule envoie les jours et les heures HH:mm', () async {
      final repository = AvailabilityRepository(api);
      adapter.whenRequest('POST', '/v1/availability/rules', statusCode: 201, body: _availabilityJson);

      final result = await repository.addRule(days: const [Weekday.friday], start: '14:00', end: '18:30');

      expect(adapter.requests.single.data, {
        'days': ['friday'],
        'start': '14:00',
        'end': '18:30',
      });
      expect(result.rules, hasLength(1));
    });

    test('addBlockedPeriod envoie les dates au format Y-m-d', () async {
      final repository = AvailabilityRepository(api);
      adapter.whenRequest('POST', '/v1/availability/blocked-periods', statusCode: 201, body: _availabilityJson);

      await repository.addBlockedPeriod(from: DateTime(2026, 12, 20), to: DateTime(2027, 1, 2, 23, 59));

      expect(adapter.requests.single.data, {'from': '2026-12-20', 'to': '2027-01-02', 'label': null});
    });

    test('delete retire la plage ou la période', () async {
      final repository = AvailabilityRepository(api);
      adapter.whenRequest('DELETE', '/v1/availability/5', statusCode: 204);

      await repository.delete(5);

      expect(adapter.requests.single.path, '/v1/availability/5');
    });
  });
}
