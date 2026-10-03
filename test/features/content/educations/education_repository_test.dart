import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/models/publication_status.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/content/educations/data/education.dart';
import 'package:me_mobile/features/content/educations/data/education_repository.dart';

import '../../../helpers/fake_dio_adapter.dart';
import '../../../helpers/memory_token_storage.dart';

const _educationJson = {
  'id': 1,
  'institution': 'Université X',
  'degree': {'fr': 'Master', 'en': 'Master'},
  'field': {'fr': 'Informatique', 'en': 'Computer Science'},
  'start_date': '2018-09-01',
  'end_date': '2020-06-30',
  'description': {'fr': '', 'en': ''},
  'sort_order': 1,
  'status': 'published',
};

void main() {
  test('Education.fromJson parse des dates simples YYYY-MM-DD', () {
    final education = Education.fromJson(_educationJson);
    expect(education.startDate, DateTime(2018, 9, 1));
    expect(education.endDate, DateTime(2020, 6, 30));
  });

  test('end_date absent (en cours) devient null', () {
    final json = Map<String, dynamic>.from(_educationJson)..['end_date'] = null;
    expect(Education.fromJson(json).endDate, isNull);
  });

  late FakeDioAdapter adapter;
  late EducationRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = EducationRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('save formate les dates en YYYY-MM-DD et envoie null si en cours', () async {
    adapter.whenRequest('POST', '/v1/educations', statusCode: 200, body: _educationJson);

    await repository.save(
      institution: 'Université X',
      degree: const Translated(fr: 'Master', en: 'Master'),
      field: const Translated(fr: 'Informatique', en: 'Computer Science'),
      startDate: DateTime(2018, 9, 1),
      endDate: null,
      description: const Translated(),
      sortOrder: 1,
      status: PublicationStatus.published,
    );

    final body = adapter.requests.single.data as Map;
    expect(body['start_date'], '2018-09-01');
    expect(body['end_date'], isNull);
  });
}
