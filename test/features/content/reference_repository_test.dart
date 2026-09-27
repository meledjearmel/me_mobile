import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/content/data/reference_repository.dart';
import 'package:me_mobile/features/content/data/refs.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

void main() {
  late FakeDioAdapter adapter;
  late ReferenceListRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = ReferenceListRepository(
      ApiClient(baseUrl: 'https://me.armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('fetchAll parcourt toutes les pages à per_page=50', () async {
    adapter.whenRequest(
      'GET',
      '/v1/domains',
      statusCode: 200,
      body: {
        'data': [
          {'id': 1, 'key': 'web', 'label': {'fr': 'Web', 'en': 'Web'}, 'color': '#3b82f6'},
        ],
        'meta': {'current_page': 1, 'last_page': 2, 'per_page': 50, 'total': 2},
      },
    );
    adapter.whenRequest(
      'GET',
      '/v1/domains',
      statusCode: 200,
      body: {
        'data': [
          {'id': 2, 'key': 'mobile', 'label': {'fr': 'Mobile', 'en': 'Mobile'}, 'color': '#22c55e'},
        ],
        'meta': {'current_page': 2, 'last_page': 2, 'per_page': 50, 'total': 2},
      },
    );

    final result = await repository.fetchAll('/v1/domains', DomainRef.fromJson);

    expect(result.map((d) => d.id), [1, 2]);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.first.queryParameters['page'], 1);
    expect(adapter.requests.last.queryParameters['page'], 2);
    expect(adapter.requests.first.queryParameters['per_page'], 50);
  });

  test('s\'arrête dès que la dernière page est atteinte', () async {
    adapter.whenRequest(
      'GET',
      '/v1/technologies',
      statusCode: 200,
      body: {
        'data': [
          {'id': 1, 'name': 'Flutter', 'category': 'frameworks'},
        ],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 50, 'total': 1},
      },
    );

    await repository.fetchAll('/v1/technologies', TechnologyRef.fromJson);

    expect(adapter.requests, hasLength(1));
  });
}
