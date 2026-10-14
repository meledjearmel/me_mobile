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

  test('une demande de l\'estimateur porte son estimation et l\'analyse IA', () {
    final engagement = Engagement.fromJson({
      ..._engagementJson,
      'type': 'freelance',
      'estimate': {
        'billing': 'fixed',
        'currency': 'CHF',
        'hourly_rate': 100,
        'risk_percent': 20,
        'project_type': 'Site vitrine',
        'features': ['Blog', 'Multilingue'],
        'hours_min': 36,
        'hours_max': 60,
        'price_min': 3600,
        'price_max': 6000,
        'weeks_min': 1,
        'weeks_max': 2,
      },
      'estimate_label': '3 600 – 6 000 CHF (forfait, 36 – 60 h) · 2 semaines',
      'ai_analysis': {
        'summary': 'Projet clair',
        'risks': ['Contenus en retard'],
        'unclear_points': [],
        'questions': ['Qui fournit les textes ?'],
        'hours_min': 45,
        'hours_max': 70,
        'billing': 'hourly',
        'reasoning': null,
        'price_min': 4500,
        'price_max': 7000,
        'currency': 'CHF',
      },
      'ai_analyzed_at': '2026-10-01T10:00:00Z',
    });

    expect(engagement.estimate!.features, ['Blog', 'Multilingue']);
    expect(engagement.estimate!.priceMax, 6000);
    expect(engagement.estimateLabel, startsWith('3 600'));
    expect(engagement.aiAnalysis!.questions.single, 'Qui fournit les textes ?');
    expect(engagement.aiAnalysis!.billing, 'hourly');
    expect(billingLabel(engagement.aiAnalysis!.billing), 'À l\'heure');
    expect(engagement.copyWith(status: EngagementStatus.handled).aiAnalysis, isNotNull);
  });

  test('sans estimation, les champs restent vides (libellé vide compris)', () {
    final engagement = Engagement.fromJson({..._engagementJson, 'estimate': null, 'estimate_label': '', 'ai_analysis': null});

    expect(engagement.estimate, isNull);
    expect(engagement.estimateLabel, isNull);
    expect(engagement.aiAnalysis, isNull);
  });

  test('analyze relance l\'analyse IA et renvoie la demande à jour', () async {
    adapter.whenRequest(
      'POST',
      '/v1/ai/engagements/5/analyze',
      statusCode: 200,
      body: {
        ..._engagementJson,
        'ai_analysis': {
          'summary': 'Résumé',
          'risks': [],
          'unclear_points': [],
          'questions': [],
          'hours_min': 10,
          'hours_max': 20,
          'billing': 'fixed',
          'reasoning': null,
          'price_min': null,
          'price_max': null,
          'currency': null,
        },
      },
    );

    final updated = await repository.analyze(5);

    expect(adapter.requests.single.method, 'POST');
    expect(updated.aiAnalysis!.summary, 'Résumé');
    expect(updated.aiAnalysis!.priceMin, isNull);
  });
}
