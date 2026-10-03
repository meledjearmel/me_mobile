import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/inbox/data/contact.dart';
import 'package:me_mobile/features/inbox/data/contact_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _contactJson = {
  'id': 1,
  'name': 'Jeanne',
  'email': 'jeanne@example.com',
  'subject': 'Une question',
  'message': 'Bonjour…',
  'status': 'new',
  'created_at': '2026-09-27T10:00:00Z',
};

void main() {
  late FakeDioAdapter adapter;
  late ContactRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = ContactRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('list envoie la page, la recherche et le filtre de statut', () async {
    adapter.whenRequest(
      'GET',
      '/v1/contacts',
      statusCode: 200,
      body: {
        'data': [_contactJson],
        'meta': {'current_page': 1, 'last_page': 2, 'per_page': 25, 'total': 30},
      },
    );

    final page = await repository.list(page: 1, search: 'Jeanne', status: 'new');

    expect(page.items.single.name, 'Jeanne');
    expect(page.hasMore, isTrue);
    final query = adapter.requests.single.queryParameters;
    expect(query['search'], 'Jeanne');
    expect(query['status'], 'new');
    expect(query['per_page'], 25);
  });

  test('updateStatus envoie {status} en PUT', () async {
    adapter.whenRequest('PUT', '/v1/contacts/1', statusCode: 200, body: {..._contactJson, 'status': 'replied'});

    final updated = await repository.updateStatus(1, ContactStatus.replied);

    expect(updated.status, ContactStatus.replied);
    expect((adapter.requests.single.data as Map)['status'], 'replied');
  });

  test('delete appelle DELETE /v1/contacts/{id}', () async {
    adapter.whenRequest('DELETE', '/v1/contacts/1', statusCode: 204);

    await repository.delete(1);

    expect(adapter.requests.single.method, 'DELETE');
  });
}
