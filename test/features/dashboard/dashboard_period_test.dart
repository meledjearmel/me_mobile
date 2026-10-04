import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/dashboard/data/dashboard.dart';
import 'package:me_mobile/features/dashboard/data/dashboard_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

Map<String, dynamic> _dashboard({int? periodDays, String? since, String granularity = 'day'}) => {
  'todo': {'contacts': 1, 'engagements': 0, 'testimonials': 2, 'appointments': 3},
  'visits': {
    'total': 900,
    'period_days': periodDays,
    'since': since,
    'period': 900,
    'today': 4,
    'french': 600,
    'english': 300,
    'visitors': 250,
    'granularity': granularity,
    'daily': [
      {'date': '2025-01-01', 'count': 300},
      {'date': '2026-01-01', 'count': 600},
    ],
    'by_source': [],
    'by_device': [],
    'top_pages': [],
    'top_content': [],
  },
  'content': {
    'projects': {'published': 0, 'archived': 0, 'featured': 0, 'open_source': 0},
    'testimonials': {'approved': 0, 'pending': 0, 'rejected': 0, 'featured': 0},
    'engagements': {'freelance': 0, 'hiring': 0, 'cv_sent': 0},
  },
  'distribution': {'projects_by_domain': [], 'skills_by_domain': [], 'technologies_by_category': []},
  'health': [],
  'recent': {'contacts': [], 'engagements': [], 'testimonials': []},
  'cv_downloads': {'total': 5, 'period_days': periodDays, 'since': since, 'period': 5, 'with_email': 1},
  'conversions': {'period_days': periodDays, 'since': since, 'visitors': 250, 'goals': []},
};

void main() {
  late FakeDioAdapter adapter;
  late DashboardRepository repository;

  setUpAll(() => initializeDateFormatting('fr_FR'));

  setUp(() {
    adapter = FakeDioAdapter();
    repository = DashboardRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('get transmet la période et le type de contenu', () async {
    adapter.whenRequest('GET', '/v1/dashboard', statusCode: 200, body: _dashboard(periodDays: 7, since: '2026-09-28'));

    await repository.get(days: '7', type: 'project');

    final query = adapter.requests.single.queryParameters;
    expect(query['days'], '7');
    expect(query['type'], 'project');
  });

  test('« tout » : period_days null, début de la période et granularité annuelle', () {
    final dashboard = Dashboard.fromJson(_dashboard(since: '2023-03-12', granularity: 'year'));

    expect(dashboard.visits.periodDays, isNull);
    expect(dashboard.visits.since, DateTime(2023, 3, 12));
    expect(dashboard.visits.granularity, 'year');
    expect(dashboard.visits.periodLabel, 'Depuis le 12 mars 2023');
    expect(dashboard.cvDownloads.periodLabel, 'Depuis le 12 mars 2023');
    expect(dashboard.conversions.periodLabel, 'Depuis le 12 mars 2023');
  });

  test('libellés de période', () {
    expect(describePeriod(7, null), '7 derniers jours');
    expect(describePeriod(30, null), '30 derniers jours');
    expect(describePeriod(365, null), '12 derniers mois');
    expect(describePeriod(null, null), 'Depuis le début');
  });

  test('todo compte les rendez-vous en attente', () {
    final dashboard = Dashboard.fromJson(_dashboard(periodDays: 30));

    expect(dashboard.todo.appointments, 3);
    expect(dashboard.todo.total, 6);
  });
}
