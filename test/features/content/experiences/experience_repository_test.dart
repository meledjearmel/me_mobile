import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/models/publication_status.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/content/experiences/data/experience.dart';
import 'package:me_mobile/features/content/experiences/data/experience_repository.dart';

import '../../../helpers/fake_dio_adapter.dart';
import '../../../helpers/memory_token_storage.dart';

const _experienceJson = {
  'id': 1,
  'company': 'Acme',
  'role': {'fr': 'Développeur', 'en': 'Developer'},
  'location': 'Abidjan',
  'start_date': '2020-01-01',
  'end_date': null,
  'description': {'fr': '', 'en': ''},
  'sort_order': 1,
  'status': 'published',
  'highlights': [
    {'id': 1, 'text': {'fr': 'Point 1', 'en': 'Point 1'}, 'sort_order': 0},
    {'id': null, 'text': {'fr': 'Point 2', 'en': 'Point 2'}, 'sort_order': 1},
  ],
};

void main() {
  test('Experience.fromJson parse les points marquants, avec ou sans id', () {
    final experience = Experience.fromJson(_experienceJson);
    expect(experience.highlights, hasLength(2));
    expect(experience.highlights.first.id, 1);
    expect(experience.highlights.last.id, isNull);
    expect(experience.endDate, isNull);
  });

  late FakeDioAdapter adapter;
  late ExperienceRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = ExperienceRepository(
      ApiClient(baseUrl: 'https://me.armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('save envoie les points marquants (id présent = mise à jour, absent = création)', () async {
    adapter.whenRequest('POST', '/v1/experiences', statusCode: 200, body: _experienceJson);

    await repository.save(
      company: 'Acme',
      role: const Translated(fr: 'Développeur', en: 'Developer'),
      location: 'Abidjan',
      startDate: DateTime(2020, 1, 1),
      endDate: null,
      description: const Translated(),
      sortOrder: 1,
      status: PublicationStatus.published,
      highlights: const [
        Highlight(id: 1, text: Translated(fr: 'Point 1', en: 'Point 1'), sortOrder: 0),
        Highlight(text: Translated(fr: 'Point 2', en: 'Point 2'), sortOrder: 1),
      ],
    );

    final body = adapter.requests.single.data as Map;
    final highlights = body['highlights'] as List;
    expect(highlights[0]['id'], 1);
    expect(highlights[1]['id'], isNull);
    expect(highlights[1]['text'], {'fr': 'Point 2', 'en': 'Point 2'});
  });

  test('un point retiré de la liste n\'est simplement plus envoyé (suppression via absence, §4.3)', () async {
    adapter.whenRequest('POST', '/v1/experiences', statusCode: 200, body: _experienceJson);

    await repository.save(
      company: 'Acme',
      role: const Translated(fr: 'Développeur', en: 'Developer'),
      location: null,
      startDate: DateTime(2020, 1, 1),
      endDate: null,
      description: const Translated(),
      sortOrder: 1,
      status: PublicationStatus.published,
      highlights: const [],
    );

    final body = adapter.requests.single.data as Map;
    expect(body['highlights'], isEmpty);
  });
}
