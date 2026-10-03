import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/models/publication_status.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/content/domains/data/domain.dart';
import 'package:me_mobile/features/content/domains/data/domain_repository.dart';

import '../../../helpers/fake_dio_adapter.dart';
import '../../../helpers/memory_token_storage.dart';

const _domainJson = {
  'id': 1,
  'key': 'web',
  'label': {'fr': 'Web', 'en': 'Web'},
  'color': '#3b82f6',
  'icon': 'globe',
  'sort_order': 1,
  'status': 'published',
};

void main() {
  test('Domain.fromJson analyse correctement', () {
    final domain = Domain.fromJson(_domainJson);
    expect(domain.key, 'web');
    expect(domain.status, PublicationStatus.published);
  });

  late FakeDioAdapter adapter;
  late DomainRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = DomainRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('save (création) envoie un POST en JSON, sans _method', () async {
    adapter.whenRequest('POST', '/v1/domains', statusCode: 200, body: _domainJson);

    await repository.save(
      key: 'web',
      label: const Translated(fr: 'Web', en: 'Web'),
      color: '#3b82f6',
      icon: 'globe',
      sortOrder: 1,
      status: PublicationStatus.published,
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect((request.data as Map)['key'], 'web');
    expect((request.data as Map)['label'], {'fr': 'Web', 'en': 'Web'});
  });

  test('save (modification) envoie un vrai PUT (pas de fichier à envoyer)', () async {
    adapter.whenRequest('PUT', '/v1/domains/1', statusCode: 200, body: _domainJson);

    await repository.save(
      id: 1,
      key: 'web',
      label: const Translated(fr: 'Web', en: 'Web'),
      color: '#3b82f6',
      icon: 'globe',
      sortOrder: 1,
      status: PublicationStatus.published,
    );

    expect(adapter.requests.single.method, 'PUT');
  });

  test('list envoie la recherche et le statut', () async {
    adapter.whenRequest(
      'GET',
      '/v1/domains',
      statusCode: 200,
      body: {
        'data': [_domainJson],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 1},
      },
    );

    await repository.list(page: 1, search: 'web', status: 'published');

    final query = adapter.requests.single.queryParameters;
    expect(query['search'], 'web');
    expect(query['status'], 'published');
  });
}
