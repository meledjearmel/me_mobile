import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/content/technologies/data/technology.dart';
import 'package:me_mobile/features/content/technologies/data/technology_repository.dart';

import '../../../helpers/fake_dio_adapter.dart';
import '../../../helpers/memory_token_storage.dart';

const _technologyJson = {'id': 1, 'name': 'Flutter', 'category': 'frameworks', 'icon': null};

void main() {
  test('Technology.fromJson analyse correctement, icon absent toléré', () {
    final technology = Technology.fromJson(_technologyJson);
    expect(technology.name, 'Flutter');
    expect(technology.category, TechnologyCategory.frameworks);
    expect(technology.icon, isNull);
  });

  test('Technology.fromJson lit les URL de logo claire et sombre', () {
    final technology = Technology.fromJson({
      ..._technologyJson,
      'icon': 'flutter',
      'icon_light_url': 'https://cdn/flutter-light.svg',
      'icon_dark_url': 'https://cdn/flutter-dark.svg',
    });
    expect(technology.icon, 'flutter');
    expect(technology.iconLightUrl, 'https://cdn/flutter-light.svg');
    expect(technology.iconDarkUrl, 'https://cdn/flutter-dark.svg');
  });

  test('un catégorie inconnue retombe sur "langages" plutôt que de planter', () {
    expect(TechnologyCategory.fromWire('autre'), TechnologyCategory.langages);
  });

  late FakeDioAdapter adapter;
  late TechnologyRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = TechnologyRepository(
      ApiClient(baseUrl: 'https://me.armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('list envoie la catégorie comme filtre', () async {
    adapter.whenRequest(
      'GET',
      '/v1/technologies',
      statusCode: 200,
      body: {
        'data': [_technologyJson],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 1},
      },
    );

    await repository.list(page: 1, category: 'frameworks');

    expect(adapter.requests.single.queryParameters['category'], 'frameworks');
  });

  test('save envoie name, category et icon', () async {
    adapter.whenRequest('POST', '/v1/technologies', statusCode: 200, body: _technologyJson);

    await repository.save(name: 'Flutter', category: TechnologyCategory.frameworks, icon: null);

    final body = adapter.requests.single.data as Map;
    expect(body['name'], 'Flutter');
    expect(body['category'], 'frameworks');
  });

  test('delete appelle DELETE /v1/technologies/{id}', () async {
    adapter.whenRequest('DELETE', '/v1/technologies/1', statusCode: 204);
    await repository.delete(1);
    expect(adapter.requests.single.path, '/v1/technologies/1');
  });
}
