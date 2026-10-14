import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/blog/data/post.dart';
import 'package:me_mobile/features/blog/data/post_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

void main() {
  group('splitHtmlBlocks', () {
    test('regroupe les blocs sans dépasser la limite ni couper une balise', () {
      final html = '<p>${'a' * 40}</p><h2>Titre</h2><p>${'b' * 40}</p><ul><li>x</li></ul>';

      final chunks = splitHtmlBlocks(html, maxLength: 70);

      expect(chunks.join(), html);
      expect(chunks.every((c) => c.length <= 70), isTrue);
      expect(chunks.first, '<p>${'a' * 40}</p><h2>Titre</h2>');
    });

    test('un texte court reste en un seul morceau, sans balise finale', () {
      expect(splitHtmlBlocks('<p>Un</p> fin', maxLength: 6000), ['<p>Un</p> fin']);
      expect(splitHtmlBlocks('', maxLength: 6000), isEmpty);
    });

    test('un bloc plus long que la limite reste entier', () {
      final long = '<p>${'c' * 100}</p>';

      expect(splitHtmlBlocks('$long<p>d</p>', maxLength: 50), [long, '<p>d</p>']);
    });
  });

  late FakeDioAdapter adapter;
  late PostRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = PostRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('translateHtml traduit bloc par bloc et recolle le résultat', () async {
    adapter
      ..whenRequest('POST', '/v1/ai/translate-html', statusCode: 200, body: {'text': '<p>One</p>'})
      ..whenRequest('POST', '/v1/ai/translate-html', statusCode: 200, body: {'text': '<p>Two</p>'});
    final progress = <(int, int)>[];
    final html = '<p>${'u' * 3500}</p><p>${'d' * 3500}</p>';

    final english = await repository.translateHtml(
      html: html,
      sourceLocale: 'fr',
      targetLocale: 'en',
      onProgress: (done, total) => progress.add((done, total)),
    );

    expect(english, '<p>One</p><p>Two</p>');
    expect(adapter.requests, hasLength(2));
    expect((adapter.requests.first.data as Map)['target_locale'], 'en');
    expect(progress.last, (2, 2));
  });

  test('writeWithAi envoie la fin du contexte et ignore les champs vides', () async {
    adapter.whenRequest('POST', '/v1/ai/write-post', statusCode: 200, body: {'text': '<p>Suite</p>'});

    final html = await repository.writeWithAi(
      instruction: ' Une conclusion ',
      locale: 'fr',
      context: 'x' * 7000,
      title: 'Titre',
      excerpt: '',
    );

    final data = adapter.requests.single.data as Map<String, dynamic>;
    expect(html, '<p>Suite</p>');
    expect(data['instruction'], 'Une conclusion');
    expect((data['context'] as String).length, 6000);
    expect(data['excerpt'], isNull);
    expect(data['selection'], isNull);
  });

  test('uploadImage envoie le fichier en multipart et renvoie son adresse', () async {
    adapter.whenRequest(
      'POST',
      '/v1/posts/images',
      statusCode: 201,
      body: {'url': 'https://armeldev.xyz/storage/x.jpg'},
    );

    final url = await repository.uploadImage(MultipartFile.fromBytes([1, 2, 3], filename: 'x.jpg'));

    expect(url, 'https://armeldev.xyz/storage/x.jpg');
    expect(adapter.requests.single.data, isA<FormData>());
  });
}
