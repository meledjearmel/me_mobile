import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/inbox/data/engagement.dart';
import 'package:me_mobile/features/inbox/data/engagement_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _engagementJson = {
  'id': 5,
  'type': 'hiring',
  'status': 'new',
  'name': 'Paul',
  'email': 'paul@example.com',
  'company': 'Acme',
  'subject': 'Lead dev',
  'job_profile': {
    'id': 2,
    'label': {'fr': 'Lead technique', 'en': 'Tech lead'},
  },
  'contract': 'cdi',
  'budget': '5 000 CHF (forfait)',
  'timeline': 'urgent',
  'message': 'Un message',
  'locale': 'fr',
  'cv_sent_at': '2026-09-20T10:00:00Z',
  'created_at': '2026-09-27T10:00:00Z',
};

void main() {
  late FakeDioAdapter adapter;
  late EngagementRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = EngagementRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('list envoie type et statut comme filtres, parse le profil métier et le budget', () async {
    adapter.whenRequest(
      'GET',
      '/v1/engagements',
      statusCode: 200,
      body: {
        'data': [_engagementJson],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 1},
      },
    );

    final page = await repository.list(page: 1, type: 'hiring', status: 'new');
    final engagement = page.items.single;

    expect(engagement.type, EngagementType.hiring);
    expect(engagement.jobProfile!.label.fr, 'Lead technique');
    expect(engagement.budget, '5 000 CHF (forfait)');
    expect(adapter.requests.single.queryParameters['type'], 'hiring');
  });

  test('budget null (freelance sans budget renseigné) ne fait pas planter le parsing', () async {
    final json = Map<String, dynamic>.from(_engagementJson)..['budget'] = null;
    adapter.whenRequest('GET', '/v1/engagements/5', statusCode: 200, body: json);

    final engagement = await repository.get(5);

    expect(engagement.budget, isNull);
  });

  test('updateStatus envoie {status} en PUT', () async {
    adapter.whenRequest('PUT', '/v1/engagements/5', statusCode: 200, body: {..._engagementJson, 'status': 'handled'});

    final updated = await repository.updateStatus(5, EngagementStatus.handled);

    expect(updated.status, EngagementStatus.handled);
    expect((adapter.requests.single.data as Map)['status'], 'handled');
  });
}
