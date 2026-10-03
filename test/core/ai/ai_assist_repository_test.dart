import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/ai/ai_assist_repository.dart';
import 'package:me_mobile/core/ai/text_tone.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/api/api_exception.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

void main() {
  late FakeDioAdapter adapter;
  late AiAssistRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = AiAssistRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('translate envoie le texte et les deux langues, renvoie le texte traduit', () async {
    adapter.whenRequest('POST', '/v1/ai/translate', statusCode: 200, body: {'text': 'Hello'});

    final result = await repository.translate(text: 'Bonjour', sourceLocale: 'fr', targetLocale: 'en');

    expect(result, 'Hello');
    final body = adapter.requests.single.data as Map;
    expect(body, {'text': 'Bonjour', 'source_locale': 'fr', 'target_locale': 'en'});
  });

  test('improve envoie le ton en wireValue quand fourni', () async {
    adapter.whenRequest('POST', '/v1/ai/improve', statusCode: 200, body: {'text': 'Réécrit.'});

    final result = await repository.improve(text: 'Texte.', locale: 'fr', tone: TextTone.concise);

    expect(result, 'Réécrit.');
    final body = adapter.requests.single.data as Map;
    expect(body['tone'], 'concise');
  });

  test('improve envoie tone et instructions à null quand absents', () async {
    adapter.whenRequest('POST', '/v1/ai/improve', statusCode: 200, body: {'text': 'Réécrit.'});

    await repository.improve(text: 'Texte.', locale: 'en');

    final body = adapter.requests.single.data as Map;
    expect(body['tone'], isNull);
    expect(body['instructions'], isNull);
  });

  test('describeTechnology envoie nom et catégorie, renvoie la description bilingue', () async {
    adapter.whenRequest(
      'POST',
      '/v1/ai/describe-technology',
      statusCode: 200,
      body: {
        'description': {'fr': 'Base en mémoire : cache, files d\'attente.', 'en': 'In-memory store: cache, queues.'},
      },
    );

    final result = await repository.describeTechnology(name: 'Redis', category: 'Données');

    expect(result.fr, 'Base en mémoire : cache, files d\'attente.');
    expect(result.en, 'In-memory store: cache, queues.');
    expect(adapter.requests.single.data, {'name': 'Redis', 'category': 'Données'});
  });

  test('un 503 (tous les fournisseurs IA indisponibles) devient une ApiException avec le message serveur', () async {
    adapter.whenRequest(
      'POST',
      '/v1/ai/translate',
      statusCode: 503,
      body: {'message': 'L\'assistance IA est momentanément indisponible.'},
    );

    await expectLater(
      repository.translate(text: 'Bonjour', sourceLocale: 'fr', targetLocale: 'en'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'L\'assistance IA est momentanément indisponible.',
        ),
      ),
    );
  });

  test('un 429 (limite de requêtes IA atteinte) devient TooManyRequestsException', () async {
    adapter.whenRequest('POST', '/v1/ai/improve', statusCode: 429, body: {'message': 'Too Many Attempts.'});

    await expectLater(
      repository.improve(text: 'Texte.', locale: 'fr'),
      throwsA(isA<TooManyRequestsException>()),
    );
  });
}
