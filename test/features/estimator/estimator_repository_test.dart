import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/estimator/data/estimator.dart';
import 'package:me_mobile/features/estimator/data/estimator_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _projectTypeJson = {
  'id': 1,
  'kind': 'project_type',
  'name': {'fr': 'Site vitrine', 'en': 'Showcase website'},
  'description': {'fr': '', 'en': ''},
  'hours_min': 20,
  'hours_max': 40,
  'pricing': 'hours',
  'percent': null,
  'billing': 'fixed',
  'project_type_ids': [],
  'estimator_rate_id': 3,
  'hourly_rates': null,
  'is_active': true,
  'sort_order': 0,
};

const _percentFeatureJson = {
  'id': 2,
  'kind': 'feature',
  'name': {'fr': 'Multilingue', 'en': 'Multilingual'},
  'description': [],
  'hours_min': 0,
  'hours_max': 0,
  'pricing': 'percent',
  'percent': 15,
  'billing': null,
  'project_type_ids': [1],
  'estimator_rate_id': null,
  'hourly_rates': {'EUR': 60, 'XOF': 0},
  'is_active': false,
  'sort_order': 2,
};

Map<String, dynamic> _page(List<Map<String, dynamic>> items, {int page = 1, int last = 1}) => {
  'data': items,
  'meta': {'current_page': page, 'last_page': last, 'per_page': 50, 'total': items.length},
};

void main() {
  late FakeDioAdapter adapter;
  late EstimatorRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = EstimatorRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('EstimatorItem lit un type de projet et une option en pourcentage', () {
    final type = EstimatorItem.fromJson(_projectTypeJson);
    final feature = EstimatorItem.fromJson(_percentFeatureJson);

    expect(type.billing, EstimatorBilling.fixed);
    expect(type.rateId, 3);
    expect(type.effortLabel, '20 – 40 h');
    expect(feature.isPercent, isTrue);
    expect(feature.effortLabel, '+ 15 %');
    expect(feature.projectTypeIds, [1]);
    // Une devise à 0 n'est pas un taux.
    expect(feature.hourlyRates, {'EUR': 60});
    expect(feature.description.isEmpty, isTrue);
  });

  test('option récurrente : pricing recurring, périodes et heures par mois', () {
    final item = EstimatorItem.fromJson({
      ..._percentFeatureJson,
      'hours_min': 2,
      'hours_max': 4,
      'pricing': 'recurring',
      'percent': null,
      'periods': {'monthly': 0, 'quarterly': 5, 'yearly': 15, 'weekly': 3},
    });

    expect(item.isRecurring, isTrue);
    expect(item.effortLabel, '2 – 4 h / mois');
    // Une clé inconnue est ignorée.
    expect(item.periods, {EstimatorPeriod.monthly: 0, EstimatorPeriod.quarterly: 5, EstimatorPeriod.yearly: 15});
  });

  test('option ponctuelle avec periods: null', () {
    final item = EstimatorItem.fromJson({
      ..._percentFeatureJson,
      'pricing': 'hours',
      'hours_min': 8,
      'hours_max': 8,
      'periods': null,
    });
    expect(item.periods, isNull);
    expect(item.isRecurring, isFalse);
    expect(item.effortLabel, '8 h');
  });

  test('saveItem : une option récurrente n\'envoie que les périodes activées', () async {
    adapter.whenRequest('POST', '/v1/estimator-items', statusCode: 201, body: _percentFeatureJson);
    await repository.saveItem(
      kind: EstimatorItemKind.feature,
      name: const Translated(fr: 'Maintenance', en: 'Maintenance'),
      description: const Translated(),
      hoursMin: 2,
      hoursMax: 4,
      pricing: EstimatorPricing.recurring,
      periods: {EstimatorPeriod.monthly: 0, EstimatorPeriod.yearly: 15},
    );
    final data = adapter.requests.last.data as Map<String, dynamic>;
    expect(data['pricing'], 'recurring');
    expect(data['hours_min'], 2);
    expect(data['periods'], {'monthly': 0, 'yearly': 15});

    await repository.saveItem(
      kind: EstimatorItemKind.feature,
      name: const Translated(fr: 'Blog', en: 'Blog'),
      description: const Translated(),
      hoursMin: 8,
      hoursMax: 8,
      pricing: EstimatorPricing.hours,
      periods: {EstimatorPeriod.monthly: 0},
    );
    expect((adapter.requests.last.data as Map<String, dynamic>)['periods'], isNull);
  });

  test('hourlyRatesToJson envoie les quatre devises, absentes à null', () {
    expect(hourlyRatesToJson({'EUR': 60}), {'XOF': null, 'EUR': 60, 'USD': null, 'CHF': null});
    expect(describeRates({'XOF': 25000, 'CHF': 90}), '25000 XOF · 90 CHF');
  });

  test('settings et saveSettings utilisent les clés estimator_*', () async {
    const json = {
      'estimator_hourly_rates': {'XOF': 25000, 'EUR': 40, 'USD': null, 'CHF': null},
      'estimator_risk_percent': 20,
      'estimator_hours_per_week': 30,
    };
    adapter
      ..whenRequest('GET', '/v1/estimator-settings', statusCode: 200, body: json)
      ..whenRequest('PUT', '/v1/estimator-settings', statusCode: 200, body: json);

    final settings = await repository.settings();
    await repository.saveSettings(settings);

    expect(settings.hourlyRates, {'XOF': 25000, 'EUR': 40});
    expect(settings.hoursPerWeek, 30);
    expect(adapter.requests.last.data, {
      'estimator_hourly_rates': {'XOF': 25000, 'EUR': 40, 'USD': null, 'CHF': null},
      'estimator_risk_percent': 20,
      'estimator_hours_per_week': 30,
    });
  });

  test('items parcourt toutes les pages', () async {
    adapter
      ..whenRequest('GET', '/v1/estimator-items', statusCode: 200, body: _page([_projectTypeJson], last: 2))
      ..whenRequest(
        'GET',
        '/v1/estimator-items',
        statusCode: 200,
        body: _page([_percentFeatureJson], page: 2, last: 2),
      );

    final items = await repository.items();

    expect(items.map((i) => i.id), [1, 2]);
    expect(adapter.requests.last.queryParameters['page'], 2);
  });

  test('saveItem : une option en pourcentage n\'envoie ni heures ni facturation', () async {
    adapter.whenRequest('POST', '/v1/estimator-items', statusCode: 201, body: _percentFeatureJson);

    await repository.saveItem(
      kind: EstimatorItemKind.feature,
      name: const Translated(fr: 'Multilingue', en: 'Multilingual'),
      description: const Translated(),
      hoursMin: 10,
      hoursMax: 20,
      pricing: EstimatorPricing.percent,
      percent: 15,
      billing: EstimatorBilling.hourly,
      projectTypeIds: [1],
    );

    final data = adapter.requests.single.data as Map<String, dynamic>;
    expect(data['hours_min'], isNull);
    expect(data['hours_max'], isNull);
    expect(data['percent'], 15);
    expect(data['pricing'], 'percent');
    expect(data['billing'], isNull);
    expect(data['project_type_ids'], [1]);
    expect(data['hourly_rates'], isNull);
  });

  test('saveItem : un type de projet garde ses heures, sa grille et ses taux propres', () async {
    adapter.whenRequest('PUT', '/v1/estimator-items/1', statusCode: 200, body: _projectTypeJson);

    await repository.saveItem(
      id: 1,
      kind: EstimatorItemKind.projectType,
      name: const Translated(fr: 'Site vitrine', en: 'Showcase website'),
      description: const Translated(),
      hoursMin: 20,
      hoursMax: 40,
      pricing: EstimatorPricing.percent,
      billing: EstimatorBilling.hourly,
      projectTypeIds: [9],
      rateId: 3,
      hourlyRates: {'CHF': 120},
    );

    final data = adapter.requests.single.data as Map<String, dynamic>;
    expect(data['hours_min'], 20);
    expect(data['billing'], 'hourly');
    expect(data['pricing'], isNull);
    expect(data['project_type_ids'], isEmpty);
    expect(data['estimator_rate_id'], 3);
    expect(data['hourly_rates'], {'XOF': null, 'EUR': null, 'USD': null, 'CHF': 120});
  });

  test('saveRate envoie le nom bilingue et les quatre devises', () async {
    adapter.whenRequest(
      'POST',
      '/v1/estimator-rates',
      statusCode: 201,
      body: {
        'id': 3,
        'name': {'fr': 'Maintenance', 'en': 'Maintenance'},
        'hourly_rates': {'EUR': 50},
        'sort_order': 0,
        'items_count': 0,
      },
    );

    final rate = await repository.saveRate(
      name: const Translated(fr: 'Maintenance', en: 'Maintenance'),
      hourlyRates: {'EUR': 50},
    );

    expect(rate.hourlyRates, {'EUR': 50});
    expect((adapter.requests.single.data as Map)['hourly_rates'], {'XOF': null, 'EUR': 50, 'USD': null, 'CHF': null});
  });

  test('suggestItem lit la proposition, pourcentage compris', () async {
    adapter.whenRequest(
      'POST',
      '/v1/ai/suggest-estimator-item',
      statusCode: 200,
      body: {
        'item': {
          'name': {'fr': 'Multilingue', 'en': 'Multilingual'},
          'description': {'fr': 'Deux langues', 'en': null},
          'pricing': 'percent',
          'percent': 15,
          'hours_min': 0,
          'hours_max': 0,
          'reasoning': 'Traductions',
        },
      },
    );

    final suggestion = await repository.suggestItem(kind: EstimatorItemKind.feature, name: ' Multilingue ', notes: '');

    expect(adapter.requests.single.data, {'kind': 'feature', 'name': 'Multilingue'});
    expect(suggestion.pricing, EstimatorPricing.percent);
    expect(suggestion.percent, 15);
    expect(suggestion.description.en, '');
  });

  test('proposeGrid puis applyConfiguration renvoie la proposition telle quelle', () async {
    const items = [
      {
        'ref': 'vitrine',
        'kind': 'project_type',
        'name_fr': 'Site vitrine',
        'name_en': 'Website',
        'hours_min': 20,
        'hours_max': 40,
        'billing': 'fixed',
      },
      {
        'id': 2,
        'ref': 'multi',
        'kind': 'feature',
        'name_fr': 'Multilingue',
        'name_en': 'Multilingual',
        'hours_min': 0,
        'hours_max': 0,
        'pricing': 'percent',
        'percent': 15,
        'project_types': ['vitrine'],
      },
    ];
    adapter
      ..whenRequest(
        'POST',
        '/v1/ai/propose-estimator-grid',
        statusCode: 200,
        body: {
          'proposal': {
            'settings': {
              'hourly_rates': {'XOF': 25000},
              'risk_percent': 20,
            },
            'items': items,
            'reasoning': 'Pourquoi',
          },
        },
      )
      ..whenRequest(
        'POST',
        '/v1/estimator-configuration',
        statusCode: 200,
        body: {
          'settings_updated': true,
          'rates': [],
          'created': [
            {'id': 7, 'name': 'Site vitrine'},
          ],
          'updated': [
            {'id': 2, 'name': 'Multilingue'},
          ],
        },
      );

    final proposal = await repository.proposeGrid('  Sites pour PME à Abidjan, forfaits  ');
    final result = await repository.applyConfiguration(proposal);

    expect(adapter.requests.first.data, {'brief': 'Sites pour PME à Abidjan, forfaits'});
    expect(proposal.proposedRates, {'XOF': 25000});
    expect(proposal.items.last.isUpdate, isTrue);
    expect(proposal.items.last.projectTypes, ['vitrine']);
    expect(proposal.items.last.effortLabel, '+ 15 %');
    expect(adapter.requests.last.data, {
      'settings': {
        'hourly_rates': {'XOF': 25000},
        'risk_percent': 20,
      },
      'items': items,
    });
    expect(result.summary, 'réglages mis à jour, 1 élément créé, 1 modifié');
  });
}
