import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/trash/data/trash_item.dart';
import 'package:me_mobile/features/trash/data/trash_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _trashItemJson = {
  'id': 3,
  'type': 'projects',
  'label': 'Projet',
  'title': 'Mon projet',
  'deleted_at': '2026-09-27T10:00:00Z',
};

void main() {
  test('TrashItem.fromJson analyse correctement', () {
    final item = TrashItem.fromJson(_trashItemJson);
    expect(item.type, 'projects');
    expect(item.label, 'Projet');
    expect(item.deletedAt, isNotNull);
  });

  test('les 19 types de l\'API sont bien listés (§4.5)', () {
    final wireValues = trashTypes.map((t) => t.$1).toSet();
    expect(wireValues, {
      'domains',
      'music-genres',
      'tracks',
      'technologies',
      'technology-categories',
      'job-profiles',
      'skills',
      'educations',
      'experiences',
      'projects',
      'professional-references',
      'testimonials',
      'contacts',
      'engagements',
      'appointments',
      'appointment-types',
      'posts',
      'uses-items',
      'certifications',
    });
  });

  late FakeDioAdapter adapter;
  late TrashRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = TrashRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('list envoie le type comme filtre', () async {
    adapter.whenRequest(
      'GET',
      '/v1/trash',
      statusCode: 200,
      body: {
        'data': [_trashItemJson],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 1},
      },
    );

    await repository.list(page: 1, type: 'projects');

    expect(adapter.requests.single.queryParameters['type'], 'projects');
  });

  test('restore appelle PATCH /v1/trash/{type}/{id}', () async {
    adapter.whenRequest('PATCH', '/v1/trash/projects/3', statusCode: 204);

    await repository.restore('projects', 3);

    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.path, '/v1/trash/projects/3');
  });

  test('destroy appelle DELETE /v1/trash/{type}/{id}', () async {
    adapter.whenRequest('DELETE', '/v1/trash/projects/3', statusCode: 204);

    await repository.destroy('projects', 3);

    expect(adapter.requests.single.method, 'DELETE');
  });
}
