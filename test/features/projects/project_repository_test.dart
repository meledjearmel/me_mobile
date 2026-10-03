import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/projects/data/project.dart';
import 'package:me_mobile/features/projects/data/project_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _projectJson = {
  'id': 1,
  'slug': 'mon-projet',
  'title': {'fr': 'Mon projet', 'en': 'My project'},
  'context': {'fr': '', 'en': ''},
  'realization': {'fr': '', 'en': ''},
  'result': {'fr': '', 'en': ''},
  'accent_color': null,
  'repo_url': null,
  'demo_url': null,
  'is_featured': false,
  'is_open_source': false,
  'status': 'published',
  'sort_order': 0,
  'cover_url': null,
  'gallery': <dynamic>[],
  'domains': <dynamic>[],
  'job_profiles': <dynamic>[],
  'technologies': <dynamic>[],
  'related_project_ids': <dynamic>[],
};

Map<String, String> _fieldMap(FormData form) => {for (final e in form.fields) e.key: e.value};

void main() {
  late FakeDioAdapter adapter;
  late ProjectRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = ProjectRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  Future<void> saveArgs({int? id, List<KeyFigure> keyFigures = const []}) => repository.save(
    id: id,
    title: const Translated(fr: 'Mon projet', en: 'My project'),
    slug: 'mon-projet',
    tagline: const Translated(fr: 'Accroche', en: 'Tagline'),
    role: const Translated(fr: 'Lead'),
    client: const Translated(),
    platform: const Translated(fr: 'Web', en: 'Web'),
    context: const Translated(),
    realization: const Translated(),
    result: const Translated(),
    keyFigures: keyFigures,
    accentColor: null,
    repoUrl: null,
    demoUrl: null,
    isFeatured: true,
    isOpenSource: false,
    status: ProjectStatus.published,
    sortOrder: 2,
    domains: [1, 2],
    jobProfiles: [3],
    technologies: [4, 5],
    relatedProjects: [6],
  );

  test('list envoie les 3 filtres et la recherche', () async {
    adapter.whenRequest(
      'GET',
      '/v1/projects',
      statusCode: 200,
      body: {
        'data': [_projectJson],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 1},
      },
    );

    await repository.list(page: 1, search: 'mon', status: 'published', isFeatured: true, isOpenSource: false);

    final query = adapter.requests.single.queryParameters;
    expect(query['search'], 'mon');
    expect(query['status'], 'published');
    expect(query['is_featured'], 1);
    expect(query['is_open_source'], 0);
  });

  test('save (création) envoie un POST sans _method, avec les relations et sort_order', () async {
    adapter.whenRequest('POST', '/v1/projects', statusCode: 200, body: _projectJson);

    await saveArgs();

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    final fields = _fieldMap(request.data as FormData);
    expect(fields.containsKey('_method'), isFalse);
    expect(fields['title[fr]'], 'Mon projet');
    expect(fields['sort_order'], '2');
    expect(fields['is_featured'], '1');
    final domainFields = (request.data as FormData).fields.where((e) => e.key == 'domains[]').map((e) => e.value);
    expect(domainFields, ['1', '2']);
  });

  test('save (modification) envoie un POST avec _method=PUT (piège des fichiers)', () async {
    adapter.whenRequest('POST', '/v1/projects/1', statusCode: 200, body: _projectJson);

    await saveArgs(id: 1);

    final fields = _fieldMap(adapter.requests.single.data as FormData);
    expect(fields['_method'], 'PUT');
  });

  test('delete appelle DELETE /v1/projects/{id}', () async {
    adapter.whenRequest('DELETE', '/v1/projects/1', statusCode: 204);

    await repository.delete(1);

    expect(adapter.requests.single.path, '/v1/projects/1');
  });

  test('deleteCover renvoie le projet mis à jour (pas un 204)', () async {
    adapter.whenRequest('DELETE', '/v1/projects/1/cover', statusCode: 200, body: {..._projectJson, 'cover_url': null});

    final updated = await repository.deleteCover(1);

    expect(updated.coverUrl, isNull);
  });

  test('deleteGalleryImage cible bien /gallery/{id} et renvoie le projet à jour', () async {
    adapter.whenRequest(
      'DELETE',
      '/v1/projects/1/gallery/a1',
      statusCode: 200,
      body: {
        ..._projectJson,
        'gallery': [
          {'id': 'a2', 'url': 'https://armeldev.xyz/gallery/2.jpg'},
        ],
      },
    );

    final updated = await repository.deleteGalleryImage(1, 'a1');

    expect(updated.gallery.single.id, 'a2');
  });

  test("save envoie l'étude de cas et les chiffres clés (texte vide → chaîne vide, lue null par Laravel)", () async {
    adapter.whenRequest('POST', '/v1/projects/1', statusCode: 200, body: _projectJson);

    await saveArgs(
      id: 1,
      keyFigures: const [
        KeyFigure(
          value: '3×',
          label: Translated(fr: 'plus rapide', en: 'faster'),
        ),
        KeyFigure(
          value: '40 %',
          label: Translated(fr: 'de coûts en moins', en: 'lower costs'),
        ),
      ],
    );

    final fields = _fieldMap(adapter.requests.single.data as FormData);
    expect(fields['tagline[fr]'], 'Accroche');
    expect(fields['role[en]'], '');
    expect(fields['client[fr]'], '');
    expect(fields['platform[en]'], 'Web');
    expect(fields['key_figures[0][value]'], '3×');
    expect(fields['key_figures[0][label][fr]'], 'plus rapide');
    expect(fields['key_figures[1][label][en]'], 'lower costs');
  });
}
