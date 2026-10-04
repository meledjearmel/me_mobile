import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/models/publication_status.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/blog/data/post.dart';
import 'package:me_mobile/features/blog/data/post_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _postJson = {
  'id': 3,
  'slug': 'mon-article',
  'title': {'fr': 'Mon article', 'en': ''},
  'excerpt': [],
  'body': {'fr': '<p>Bonjour <strong>à tous</strong></p><ul><li>Un</li><li>Deux</li></ul>', 'en': ''},
  'reading_minutes': 4,
  'is_featured': true,
  'status': 'published',
  'published_at': '2099-01-01T08:00:00Z',
  'is_live': false,
  'cover_url': null,
  'tags': ['Laravel', 'Flutter'],
  'created_at': '2026-10-04T10:00:00Z',
  'updated_at': '2026-10-04T10:00:00Z',
};

Map<String, String> _fields(FormData form) => {for (final e in form.fields) e.key: e.value};

void main() {
  late FakeDioAdapter adapter;
  late PostRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = PostRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('Post.fromJson lit le statut, la programmation et les tags', () {
    final post = Post.fromJson(_postJson);

    expect(post.status, PublicationStatus.published);
    expect(post.isScheduled, isTrue);
    expect(post.tags, ['Laravel', 'Flutter']);
    expect(post.excerpt.isEmpty, isTrue);
    expect(post.readingMinutes, 4);
  });

  test('création : POST multipart sans _method, premier jet en HTML et tags[]', () async {
    adapter.whenRequest('POST', '/v1/posts', statusCode: 201, body: _postJson);

    await repository.save(
      title: const Translated(fr: 'Mon article'),
      slug: 'mon-article',
      excerpt: const Translated(),
      body: Translated(fr: plainTextToHtml('Idée')),
      isFeatured: false,
      status: PublicationStatus.draft,
      publishedAt: null,
      tags: const ['Laravel', 'Flutter'],
    );

    final form = adapter.requests.single.data as FormData;
    final fields = _fields(form);
    expect(fields.containsKey('_method'), isFalse);
    expect(fields['title[fr]'], 'Mon article');
    expect(fields['body[fr]'], '<p>Idée</p>');
    expect(fields['status'], 'draft');
    expect(fields['published_at'], '');
    expect(form.fields.where((f) => f.key == 'tags[]').map((f) => f.value), ['Laravel', 'Flutter']);
  });

  test('modification : _method=PUT et date de parution en UTC', () async {
    adapter.whenRequest('POST', '/v1/posts/3', statusCode: 200, body: _postJson);

    await repository.save(
      id: 3,
      title: const Translated(fr: 'Mon article'),
      slug: 'mon-article',
      excerpt: const Translated(),
      body: const Translated(fr: '<p>Corps existant</p>'),
      isFeatured: true,
      status: PublicationStatus.published,
      publishedAt: DateTime.utc(2026, 11, 1, 8),
      tags: const [],
    );

    final fields = _fields(adapter.requests.single.data as FormData);
    expect(fields['_method'], 'PUT');
    expect(fields['body[fr]'], '<p>Corps existant</p>');
    expect(fields['published_at'], '2026-11-01T08:00:00.000Z');
    expect(fields['is_featured'], '1');
  });

  test("série : envoyée avec sa place, vide pour sortir l'article de sa série", () async {
    adapter.whenRequest(
      'POST',
      '/v1/posts/3',
      statusCode: 200,
      body: {..._postJson, 'series': 'Laravel', 'series_position': 2},
    );

    Future<Post> save(String? series) => repository.save(
      id: 3,
      title: const Translated(fr: 'Mon article'),
      slug: 'mon-article',
      excerpt: const Translated(),
      body: const Translated(fr: '<p>x</p>'),
      isFeatured: false,
      status: PublicationStatus.draft,
      publishedAt: null,
      tags: const [],
      series: series,
      seriesPosition: 2,
    );

    final post = await save('Laravel');
    await save(null);

    final withSeries = _fields(adapter.requests.first.data as FormData);
    expect(withSeries['series'], 'Laravel');
    expect(withSeries['series_position'], '2');
    final without = _fields(adapter.requests.last.data as FormData);
    expect(without['series'], '');
    expect(without['series_position'], '');
    expect(post.series, 'Laravel');
    expect(post.seriesPosition, 2);
  });

  test('tags() lit la liste des noms', () async {
    adapter.whenRequest(
      'GET',
      '/v1/posts/tags',
      statusCode: 200,
      body: {
        'data': ['Laravel', 'IA'],
      },
    );

    expect(await repository.tags(), ['Laravel', 'IA']);
  });

  group('Conversions de texte', () {
    test('htmlToPlainText garde paragraphes et listes', () {
      expect(
        htmlToPlainText('<p>Bonjour <strong>à tous</strong></p><ul><li>Un</li><li>Deux</li></ul>'),
        'Bonjour à tous\n\n• Un\n\n• Deux',
      );
      expect(htmlToPlainText('<p>A &amp; B&nbsp;!</p>'), 'A & B !');
    });

    test('plainTextToHtml échappe le texte et découpe les paragraphes', () {
      expect(plainTextToHtml('Un <test>\nsuite\n\nDeux'), '<p>Un &lt;test&gt;<br>suite</p><p>Deux</p>');
      expect(plainTextToHtml('   '), '');
    });

    test('slugify retire accents et ponctuation', () {
      expect(slugify('Été 2026 : l\'IA & Flutter !'), 'ete-2026-l-ia-flutter');
    });
  });
}
