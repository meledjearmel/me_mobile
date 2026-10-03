import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/models/publication_status.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/content/skills/data/skill.dart';
import 'package:me_mobile/features/content/skills/data/skill_repository.dart';

import '../../../helpers/fake_dio_adapter.dart';
import '../../../helpers/memory_token_storage.dart';

const _skillJson = {
  'id': 1,
  'domain_id': 2,
  'domain': {'id': 2, 'key': 'web', 'label': {'fr': 'Web', 'en': 'Web'}, 'color': '#3b82f6', 'icon': 'globe', 'sort_order': 1, 'status': 'published'},
  'name': {'fr': 'PHP', 'en': 'PHP'},
  'description': {'fr': '', 'en': ''},
  'details': {'fr': '', 'en': ''},
  'technologies': [
    {'id': 5, 'name': 'Laravel', 'category': 'frameworks', 'icon': null},
    {'id': 6, 'name': 'Symfony', 'category': 'frameworks', 'icon': null},
  ],
  'sort_order': 1,
  'status': 'published',
};

void main() {
  test('Skill.fromJson garde l\'ordre des technologies et le domaine imbriqué', () {
    final skill = Skill.fromJson(_skillJson);
    expect(skill.domain!.label.fr, 'Web');
    expect(skill.technologies.map((t) => t.id), [5, 6]);
  });

  late FakeDioAdapter adapter;
  late SkillRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = SkillRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('list envoie domain_id et status', () async {
    adapter.whenRequest(
      'GET',
      '/v1/skills',
      statusCode: 200,
      body: {
        'data': [_skillJson],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 1},
      },
    );

    await repository.list(page: 1, domainId: 2, status: 'published');

    final query = adapter.requests.single.queryParameters;
    expect(query['domain_id'], 2);
    expect(query['status'], 'published');
  });

  test('save envoie les technologies dans l\'ordre donné', () async {
    adapter.whenRequest('POST', '/v1/skills', statusCode: 200, body: _skillJson);

    await repository.save(
      domainId: 2,
      name: const Translated(fr: 'PHP', en: 'PHP'),
      description: const Translated(),
      details: const Translated(),
      technologies: [6, 5],
      sortOrder: 1,
      status: PublicationStatus.published,
    );

    final body = adapter.requests.single.data as Map;
    expect(body['technologies'], [6, 5]);
    expect(body['domain_id'], 2);
  });
}
