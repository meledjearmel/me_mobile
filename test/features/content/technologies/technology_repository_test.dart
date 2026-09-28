import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/content/data/refs.dart';
import 'package:me_mobile/features/content/technologies/data/technology.dart';
import 'package:me_mobile/features/content/technologies/data/technology_category_repository.dart';
import 'package:me_mobile/features/content/technologies/data/technology_repository.dart';

import '../../../helpers/fake_dio_adapter.dart';
import '../../../helpers/memory_token_storage.dart';

const _categoryJson = {
  'id': 3,
  'key': 'frameworks',
  'label': {'fr': 'Frameworks', 'en': 'Frameworks'},
  'sort_order': 2,
};

const _technologyJson = {
  'id': 1,
  'name': 'Flutter',
  'category_id': 3,
  'category': _categoryJson,
  'icon': null,
  'icon_light_url': null,
  'icon_dark_url': null,
  // Traduction vide : PHP renvoie un tableau vide.
  'description': <Object>[],
};

void main() {
  test('Technology.fromJson lit la catégorie en objet, description vide tolérée', () {
    final technology = Technology.fromJson(_technologyJson);
    expect(technology.name, 'Flutter');
    expect(technology.categoryId, 3);
    expect(technology.category?.key, 'frameworks');
    expect(technology.category?.label.display, 'Frameworks');
    expect(technology.description.isEmpty, isTrue);
    expect(technology.icon, isNull);
  });

  test('Technology.fromJson lit les URL de logo et la description', () {
    final technology = Technology.fromJson({
      ..._technologyJson,
      'icon': 'flutter',
      'icon_light_url': 'https://cdn/flutter-light.svg',
      'icon_dark_url': 'https://cdn/flutter-dark.svg',
      'description': {'fr': 'UI multiplateforme', 'en': 'Cross-platform UI'},
    });
    expect(technology.icon, 'flutter');
    expect(technology.iconLightUrl, 'https://cdn/flutter-light.svg');
    expect(technology.iconDarkUrl, 'https://cdn/flutter-dark.svg');
    expect(technology.description.en, 'Cross-platform UI');
  });

  test('TechnologyRef.fromJson tire le libellé de la catégorie en objet', () {
    expect(TechnologyRef.fromJson(_technologyJson).category, 'Frameworks');
  });

  late FakeDioAdapter adapter;
  late ApiClient api;

  setUp(() {
    adapter = FakeDioAdapter();
    api = ApiClient(baseUrl: 'https://me.armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter);
  });

  group('TechnologyRepository', () {
    test('list envoie category_id comme filtre', () async {
      adapter.whenRequest(
        'GET',
        '/v1/technologies',
        statusCode: 200,
        body: {
          'data': [_technologyJson],
          'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 1},
        },
      );

      await TechnologyRepository(api).list(page: 1, categoryId: 3);

      expect(adapter.requests.single.queryParameters['category_id'], 3);
    });

    test('save envoie name, category_id, icon et description', () async {
      adapter.whenRequest('POST', '/v1/technologies', statusCode: 200, body: _technologyJson);

      await TechnologyRepository(api).save(
        name: 'Flutter',
        categoryId: 3,
        icon: null,
        description: const Translated(fr: 'UI', en: 'UI'),
      );

      final body = adapter.requests.single.data as Map;
      expect(body['name'], 'Flutter');
      expect(body['category_id'], 3);
      expect(body.containsKey('category'), isFalse);
      expect(body['description'], {'fr': 'UI', 'en': 'UI'});
    });

    test('delete appelle DELETE /v1/technologies/{id}', () async {
      adapter.whenRequest('DELETE', '/v1/technologies/1', statusCode: 204);
      await TechnologyRepository(api).delete(1);
      expect(adapter.requests.single.path, '/v1/technologies/1');
    });
  });

  group('TechnologyCategoryRepository', () {
    test('save crée en POST puis modifie en PUT, avec key, label et sort_order', () async {
      adapter.whenRequest('POST', '/v1/technology-categories', statusCode: 200, body: _categoryJson);
      adapter.whenRequest('PUT', '/v1/technology-categories/3', statusCode: 200, body: _categoryJson);
      final repository = TechnologyCategoryRepository(api);

      await repository.save(key: 'frameworks', label: const Translated(fr: 'Frameworks', en: 'Frameworks'), sortOrder: 2);
      final updated = await repository.save(
        id: 3,
        key: 'frameworks',
        label: const Translated(fr: 'Frameworks', en: 'Frameworks'),
        sortOrder: 2,
      );

      expect(adapter.requests.first.data, {
        'key': 'frameworks',
        'label': {'fr': 'Frameworks', 'en': 'Frameworks'},
        'sort_order': 2,
      });
      expect(adapter.requests.last.path, '/v1/technology-categories/3');
      expect(updated.sortOrder, 2);
    });

    test('delete appelle DELETE /v1/technology-categories/{id}', () async {
      adapter.whenRequest('DELETE', '/v1/technology-categories/3', statusCode: 204);
      await TechnologyCategoryRepository(api).delete(3);
      expect(adapter.requests.single.path, '/v1/technology-categories/3');
    });
  });
}
