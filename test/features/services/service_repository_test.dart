import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/api/content_status_repository.dart';
import 'package:me_mobile/core/models/publication_status.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/services/data/service.dart';
import 'package:me_mobile/features/services/data/service_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _serviceJson = {
  'id': 4,
  'slug': 'site-vitrine',
  'title': {'fr': 'Site vitrine', 'en': 'Showcase website'},
  'tagline': {'fr': 'Votre activité en ligne'},
  'description': [],
  'includes': {'fr': 'Design\nHébergement', 'en': ''},
  'price_mode': 'manual',
  'estimator_item_id': null,
  'manual_prices': {'XOF': 500000, 'EUR': 800},
  'project_ids': [12, 3],
  'status': 'draft',
  'drafted_by': 'Claude Code',
  'sort_order': 1,
};

void main() {
  late FakeDioAdapter adapter;
  late ApiClient api;
  late ServiceRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    api = ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter);
    repository = ServiceRepository(api);
  });

  test('Service.fromJson lit le mode de prix, les montants et les projets', () {
    final service = Service.fromJson(_serviceJson);

    expect(service.priceMode, ServicePriceMode.manual);
    expect(service.manualPrices, {'XOF': 500000, 'EUR': 800});
    expect(service.projectIds, [12, 3]);
    expect(service.description.isEmpty, isTrue);
    expect(service.copyWith(status: PublicationStatus.published).status, PublicationStatus.published);
  });

  test('save en mode estimateur envoie le type de projet et pas de montants', () async {
    adapter.whenRequest('POST', '/v1/services', statusCode: 201, body: _serviceJson);

    await repository.save(
      slug: 'site-vitrine',
      title: const Translated(fr: 'Site vitrine'),
      tagline: const Translated(),
      description: const Translated(fr: 'Texte'),
      includes: const Translated(),
      priceMode: ServicePriceMode.estimator,
      estimatorItemId: 1,
      manualPrices: {'EUR': 800},
      status: PublicationStatus.draft,
    );

    final data = adapter.requests.single.data as Map<String, dynamic>;
    expect(data['estimator_item_id'], 1);
    expect(data['manual_prices'], isNull);
    expect(data['title'], {'fr': 'Site vitrine', 'en': null});
    expect(data['tagline'], {'fr': null, 'en': null});
    expect(data['description'], {'fr': 'Texte', 'en': null});
  });

  test('save en mode manuel envoie les quatre devises', () async {
    adapter.whenRequest('PUT', '/v1/services/4', statusCode: 200, body: _serviceJson);

    await repository.save(
      id: 4,
      slug: 'site-vitrine',
      title: const Translated(fr: 'Site vitrine', en: 'Showcase website'),
      tagline: const Translated(),
      description: const Translated(),
      includes: const Translated(),
      priceMode: ServicePriceMode.manual,
      estimatorItemId: 1,
      manualPrices: {'EUR': 800},
      status: PublicationStatus.published,
    );

    final data = adapter.requests.single.data as Map<String, dynamic>;
    expect(data['estimator_item_id'], isNull);
    expect(data['manual_prices'], {'XOF': null, 'EUR': 800, 'USD': null, 'CHF': null});
    expect(data['status'], 'published');
  });

  test('draftWithAi lit le texte proposé', () async {
    adapter.whenRequest(
      'POST',
      '/v1/ai/draft-service',
      statusCode: 200,
      body: {
        'service': {
          'title': 'Application mobile',
          'slug': 'application-mobile',
          'tagline': null,
          'description': 'Texte',
          'includes': 'Design\nPublication',
        },
      },
    );

    final draft = await repository.draftWithAi('  Apps Flutter pour PME  ');

    expect(adapter.requests.single.data, {'notes': 'Apps Flutter pour PME'});
    expect(draft.slug, 'application-mobile');
    expect(draft.tagline, isNull);
  });

  test('ContentStatusRepository change le statut par PATCH /v1/status', () async {
    adapter.whenRequest(
      'PATCH',
      '/v1/status/service/4',
      statusCode: 200,
      body: {
        'data': {'type': 'service', 'id': 4, 'status': 'published'},
      },
    );

    final status = await ContentStatusRepository(api).update('service', 4, 'published');

    expect(status, 'published');
    expect(adapter.requests.single.data, {'status': 'published'});
  });
}
