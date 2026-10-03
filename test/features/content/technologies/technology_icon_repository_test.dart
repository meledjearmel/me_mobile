import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/content/technologies/data/technology_icon.dart';
import 'package:me_mobile/features/content/technologies/data/technology_icon_repository.dart';

import '../../../helpers/fake_dio_adapter.dart';
import '../../../helpers/memory_token_storage.dart';

void main() {
  late FakeDioAdapter adapter;
  late TechnologyIconRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = TechnologyIconRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('list analyse la bibliothèque, variante sombre absente tolérée', () async {
    adapter.whenRequest(
      'GET',
      '/v1/technology-icons',
      statusCode: 200,
      body: {
        'data': [
          {'slug': 'flutter', 'light_url': 'https://cdn/flutter.svg', 'dark_url': 'https://cdn/flutter.svg'},
          {'slug': 'php', 'light_url': 'https://cdn/php.svg', 'dark_url': null},
        ],
      },
    );

    final icons = await repository.list();

    expect(icons.map((i) => i.slug), ['flutter', 'php']);
    expect(icons.last.darkUrl, isNull);
  });

  test('search envoie q et analyse les résultats', () async {
    adapter.whenRequest(
      'GET',
      '/v1/technology-icons/search',
      statusCode: 200,
      body: {
        'data': [
          {'id': 'logos:flutter', 'name': 'Flutter', 'collection': 'Logos', 'preview_url': 'https://cdn/p.svg'},
        ],
      },
    );

    final results = await repository.search('flut');

    expect(adapter.requests.single.queryParameters['q'], 'flut');
    expect(results.single.id, 'logos:flutter');
    expect(results.single.collection, 'Logos');
  });

  test('import envoie icon, slug et theme (null pour les deux thèmes)', () async {
    adapter.whenRequest('POST', '/v1/technology-icons', statusCode: 200, body: 201);

    await repository.import(icon: 'devicon:php', slug: 'php');
    await repository.import(icon: 'devicon:php', slug: 'php', theme: LogoTheme.dark);

    final bodies = adapter.requests.map((r) => r.data as Map).toList();
    expect(bodies[0], {'icon': 'devicon:php', 'slug': 'php', 'theme': null});
    expect(bodies[1]['theme'], 'dark');
  });

  test('upload envoie un multipart avec le fichier et le slug', () async {
    adapter.whenRequest('POST', '/v1/technology-icons/upload', statusCode: 200, body: 201);

    await repository.upload(
      slug: 'mon-logo',
      theme: LogoTheme.light,
      file: MultipartFile.fromString('<svg/>', filename: 'logo.svg'),
    );

    final form = adapter.requests.single.data as FormData;
    expect(Map.fromEntries(form.fields), {'slug': 'mon-logo', 'theme': 'light'});
    expect(form.files.single.key, 'file');
    expect(form.files.single.value.filename, 'logo.svg');
  });

  test('isValidSlug refuse les suffixes de thème, les majuscules et les slugs trop longs', () {
    expect(TechnologyIconRepository.isValidSlug('node-js'), isTrue);
    expect(TechnologyIconRepository.isValidSlug('flutter-dark'), isFalse);
    expect(TechnologyIconRepository.isValidSlug('light'), isTrue);
    expect(TechnologyIconRepository.isValidSlug('Flutter'), isFalse);
    expect(TechnologyIconRepository.isValidSlug('-a'), isFalse);
    expect(TechnologyIconRepository.isValidSlug('a' * 61), isFalse);
  });
}
