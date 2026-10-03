import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/content/professional_references/data/professional_reference.dart';
import 'package:me_mobile/features/content/professional_references/data/professional_reference_repository.dart';

import '../../../helpers/fake_dio_adapter.dart';
import '../../../helpers/memory_token_storage.dart';

const _referenceJson = {
  'id': 1,
  'name': 'Jeanne',
  'role': 'CTO',
  'company': 'Acme',
  'email': 'jeanne@example.com',
  'phone': null,
  'relationship': 'Ancienne manageuse',
  'project': {
    'id': 4,
    'slug': 'mon-projet',
    'title': {'fr': 'Mon projet', 'en': 'My project'},
  },
  'project_id': 4,
  'is_public': true,
  'visible_fields': ['name', 'role', 'company'],
  'notes': 'Contacter avant de citer.',
};

void main() {
  test('ProfessionalReference.fromJson parse le projet lié et les champs visibles', () {
    final reference = ProfessionalReference.fromJson(_referenceJson);
    expect(reference.project!.title.fr, 'Mon projet');
    expect(reference.visibleFields, ['name', 'role', 'company']);
    expect(reference.isPublic, isTrue);
  });

  test('sans projet lié ni champs visibles : tout reste vide proprement', () {
    final json = Map<String, dynamic>.from(_referenceJson)
      ..['project'] = null
      ..['project_id'] = null
      ..['visible_fields'] = null;
    final reference = ProfessionalReference.fromJson(json);
    expect(reference.project, isNull);
    expect(reference.visibleFields, isEmpty);
  });

  late FakeDioAdapter adapter;
  late ProfessionalReferenceRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = ProfessionalReferenceRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('list envoie is_public en 1/0', () async {
    adapter.whenRequest(
      'GET',
      '/v1/professional-references',
      statusCode: 200,
      body: {
        'data': [_referenceJson],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 1},
      },
    );

    await repository.list(page: 1, isPublic: true);

    expect(adapter.requests.single.queryParameters['is_public'], 1);
  });

  test('save envoie visible_fields et project_id', () async {
    adapter.whenRequest('POST', '/v1/professional-references', statusCode: 200, body: _referenceJson);

    await repository.save(
      name: 'Jeanne',
      role: 'CTO',
      company: 'Acme',
      email: 'jeanne@example.com',
      phone: null,
      relationship: 'Ancienne manageuse',
      projectId: 4,
      isPublic: true,
      visibleFields: const ['name', 'role', 'company'],
      notes: 'Contacter avant de citer.',
    );

    final body = adapter.requests.single.data as Map;
    expect(body['visible_fields'], ['name', 'role', 'company']);
    expect(body['project_id'], 4);
  });
}
