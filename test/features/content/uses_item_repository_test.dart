import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/models/publication_status.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/content/uses/data/uses_item.dart';
import 'package:me_mobile/features/content/uses/data/uses_item_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _itemJson = {
  'id': 4,
  'category': 'hardware',
  'name': 'MacBook Pro',
  'description': {'fr': 'Mon poste', 'en': 'My machine'},
  'url': 'https://apple.com',
  'status': 'draft',
  'sort_order': 1,
};

void main() {
  late FakeDioAdapter adapter;
  late UsesItemRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = UsesItemRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('UsesItem.fromJson lit la rubrique, le lien et le statut', () {
    final item = UsesItem.fromJson(_itemJson);

    expect(item.category, UsesCategory.hardware);
    expect(item.description.en, 'My machine');
    expect(item.url, 'https://apple.com');
    expect(item.status, PublicationStatus.draft);
  });

  test('save crée en POST puis modifie en PUT, avec la rubrique', () async {
    adapter.whenRequest('POST', '/v1/uses-items', statusCode: 201, body: _itemJson);
    adapter.whenRequest('PUT', '/v1/uses-items/4', statusCode: 200, body: _itemJson);

    Future<void> save(int? id) => repository.save(
      id: id,
      category: UsesCategory.services,
      name: 'Hetzner',
      description: const Translated(fr: 'Hébergement'),
      url: null,
      status: PublicationStatus.published,
      sortOrder: 0,
    );

    await save(null);
    await save(4);

    expect(adapter.requests.map((r) => r.method), ['POST', 'PUT']);
    final body = adapter.requests.last.data as Map;
    expect(body['category'], 'services');
    expect(body['url'], isNull);
    expect(body['description'], {'fr': 'Hébergement', 'en': ''});
  });

  test('list filtre par rubrique', () async {
    adapter.whenRequest(
      'GET',
      '/v1/uses-items',
      statusCode: 200,
      body: {
        'data': [_itemJson],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 50, 'total': 1},
      },
    );

    final page = await repository.list(page: 1, category: 'hardware');

    expect(page.items.single.name, 'MacBook Pro');
    expect(adapter.requests.single.queryParameters['category'], 'hardware');
  });
}
