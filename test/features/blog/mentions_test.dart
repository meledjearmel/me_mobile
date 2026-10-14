import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/blog/data/mentions.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

void main() {
  test('markup : syntaxe @[Nom](type:id) comprise par le site', () {
    const item = Mentionable(kind: 'project', id: 12, label: 'App Station');

    expect(item.markup, '@[App Station](project:12)');
    expect(item.kindLabel, 'Projet');
  });

  test('search interroge /v1/posts/mentions avec q', () async {
    final adapter = FakeDioAdapter();
    final repository = MentionRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
    adapter.whenRequest(
      'GET',
      '/v1/posts/mentions',
      statusCode: 200,
      body: {
        'data': [
          {'kind': 'technology', 'id': 4, 'label': 'Laravel', 'hint': 'Framework PHP'},
        ],
      },
    );

    final results = await repository.search('lara');

    expect(adapter.requests.single.queryParameters['q'], 'lara');
    expect(results.single.markup, '@[Laravel](technology:4)');
    expect(results.single.hint, 'Framework PHP');
  });

  test('parseMentions découpe le texte et ne garde que le titre des jetons', () {
    final segments = parseMentions('Voir @[App Station](project:12) et @[Laravel](technology:4).');

    expect(segments.map((s) => s.text).toList(), ['Voir ', 'App Station', ' et ', 'Laravel', '.']);
    expect(segments[1].mention!.kind, 'project');
    expect(segments[1].mention!.id, 12);
    expect(segments[3].mention!.markup, '@[Laravel](technology:4)');
  });

  test('stripMentions rend le texte lisible ; un texte sans jeton reste tel quel', () {
    expect(stripMentions('Bonjour @[App Station](project:12) !'), 'Bonjour App Station !');
    expect(stripMentions('Rien [ici](lien)'), 'Rien [ici](lien)');
  });
}
