import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/api/api_exception.dart';
import 'package:me_mobile/features/blog/data/syndication.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _settingsJson = {
  'devto': {'mode': 'manual', 'has_key': true, 'locale': 'en', 'auto_since': null},
  'hashnode': {
    'mode': 'auto',
    'has_key': false,
    'locale': 'fr',
    'auto_since': '2026-10-01T08:00:00+00:00',
    'publication_id': 'abc123',
  },
};

const _kitJson = {
  'url': 'https://armeldev.xyz/fr/blog/mon-article',
  'image': 'https://armeldev.xyz/fr/blog/mon-article/share.png',
  'texts': {'linkedin': 'Mon article', 'x': null, 'facebook': null, 'whatsapp': 'À lire'},
  'links': {
    'linkedin': 'https://www.linkedin.com/feed/?shareActive=true&text=Mon%20article',
    'x': 'https://x.com/intent/post?text=Titre',
    'facebook': 'https://www.facebook.com/sharer/sharer.php?u=x',
    'whatsapp': 'https://wa.me/?text=x',
  },
};

void main() {
  late FakeDioAdapter adapter;
  late SyndicationRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = SyndicationRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('settings lit la présence des clés, jamais leur valeur', () async {
    adapter.whenRequest('GET', '/v1/syndication', statusCode: 200, body: _settingsJson);

    final settings = await repository.settings();

    expect(settings.devto.mode, SyndicationMode.manual);
    expect(settings.devto.hasKey, isTrue);
    expect(settings.hashnode.mode, SyndicationMode.auto);
    expect(settings.hashnode.autoSince, isNotNull);
    expect(settings.of(SyndicationPlatform.hashnode).publicationId, 'abc123');
  });

  test('saveSettings : une clé vide n\'est pas envoyée, la clé enregistrée est gardée', () async {
    adapter.whenRequest('PUT', '/v1/syndication', statusCode: 200, body: {..._settingsJson, 'hashnode_error': null});

    await repository.saveSettings(
      devto: (mode: SyndicationMode.auto, locale: 'en', apiKey: '   ', clearKey: false),
      hashnode: (mode: SyndicationMode.manual, locale: 'fr', apiKey: ' nouvelle-cle ', clearKey: false),
      hashnodePublicationId: '',
    );

    final data = adapter.requests.single.data as Map<String, dynamic>;
    expect(data.containsKey('devto_api_key'), isFalse);
    expect(data['hashnode_api_key'], 'nouvelle-cle');
    expect(data['devto_mode'], 'auto');
    expect(data['devto_clear_key'], isFalse);
    expect(data['hashnode_publication_id'], isNull);
  });

  test('saveSettings peut retirer une clé', () async {
    adapter.whenRequest(
      'PUT',
      '/v1/syndication',
      statusCode: 200,
      body: {..._settingsJson, 'hashnode_error': 'Jeton refusé'},
    );

    final saved = await repository.saveSettings(
      devto: (mode: SyndicationMode.off, locale: 'en', apiKey: null, clearKey: true),
      hashnode: (mode: SyndicationMode.manual, locale: 'fr', apiKey: null, clearKey: false),
    );

    expect((adapter.requests.single.data as Map)['devto_clear_key'], isTrue);
    expect(saved.hashnodeError, 'Jeton refusé');
  });

  test('hashnodePublications lit la liste des blogs', () async {
    adapter.whenRequest(
      'GET',
      '/v1/syndication/hashnode-publications',
      statusCode: 200,
      body: [
        {'id': 'abc123', 'title': 'Mon blog', 'url': 'https://blog.example.com'},
      ],
    );

    final publications = await repository.hashnodePublications();

    expect(publications.single.id, 'abc123');
  });

  test('distribution lit l\'état par plateforme et les kits par langue', () async {
    adapter.whenRequest(
      'GET',
      '/v1/posts/9/syndications',
      statusCode: 200,
      body: {
        'syndications': [
          {
            'platform': 'devto',
            'status': 'failed',
            'external_url': null,
            'locale': 'en',
            'error': 'Clé refusée',
            'published_at': null,
          },
        ],
        'social': {'fr': _kitJson},
      },
    );

    final distribution = await repository.distribution(9);

    expect(distribution.on(SyndicationPlatform.devto)!.isFailed, isTrue);
    expect(distribution.on(SyndicationPlatform.hashnode), isNull);
    final kit = distribution.social['fr']!;
    expect(kit.texts[SocialNetwork.linkedin], 'Mon article');
    expect(kit.texts.containsKey(SocialNetwork.x), isFalse);
    expect(kit.links[SocialNetwork.x], startsWith('https://x.com'));
    expect(kit.hasTexts, isTrue);
  });

  test('syndicate : un échec de la plateforme arrive en 422 avec son message', () async {
    adapter.whenRequest(
      'POST',
      '/v1/posts/9/syndications/hashnode',
      statusCode: 422,
      body: {
        'platform': 'hashnode',
        'status': 'failed',
        'external_url': null,
        'error': 'Jeton refusé',
        'message': 'Jeton refusé',
      },
    );

    expect(() => repository.syndicate(9, SyndicationPlatform.hashnode), throwsA(isA<ValidationException>()));
  });

  test('saveSocialTexts envoie les quatre réseaux, vides à null', () async {
    adapter.whenRequest('PUT', '/v1/posts/9/social-texts', statusCode: 200, body: _kitJson);

    await repository.saveSocialTexts(9, 'fr', {SocialNetwork.linkedin: ' Mon article ', SocialNetwork.x: ''});

    expect(adapter.requests.single.data, {
      'locale': 'fr',
      'texts': {'linkedin': 'Mon article', 'x': null, 'facebook': null, 'whatsapp': null},
    });
  });

  test('generateSocialTexts appelle la route de la langue', () async {
    adapter.whenRequest('POST', '/v1/posts/9/social-texts/en', statusCode: 200, body: _kitJson);

    final kit = await repository.generateSocialTexts(9, 'en');

    expect(kit.url, contains('mon-article'));
  });
}
