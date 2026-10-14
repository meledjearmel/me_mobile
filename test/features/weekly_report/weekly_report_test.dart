import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/weekly_report/data/weekly_report.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _stateJson = {
  'enabled': true,
  'sent_at': '2026-10-12T07:00:00+00:00',
  'report': {
    'period': {'from': '2026-10-07', 'to': '2026-10-14'},
    'audience': {
      'visits': 120,
      'visitors': 80,
      'previous_visits': 100,
      'previous_visitors': 70,
      'change': 20,
      'top_content': [
        {
          'type': 'post',
          'title': 'Mon article',
          'url': '/fr/blog/x',
          'visits': 30,
          'visitors': 20,
          'top_source': 'direct',
        },
      ],
      'sources': [
        {'label': 'direct', 'count': 50},
      ],
    },
    'requests': {
      'total': 3,
      'contacts': 1,
      'freelance': 1,
      'hiring': 0,
      'appointments': 1,
      'upcoming_appointments': 2,
      'estimates': [
        {'id': 5, 'subject': 'Site', 'estimate': '3 600 – 6 000 CHF', 'ai_billing': 'fixed', 'ai_hours': '45 – 70 h'},
      ],
    },
    'applications': {
      'created': 1,
      'viewed': [
        {'id': 7, 'company': 'Acme', 'position': 'Dev', 'views': 4, 'cv_downloads': 1, 'first_time': true},
      ],
    },
    'cv_downloads': 6,
    'blog': {'published': 1, 'comments': 2, 'reactions': 9, 'new_subscribers': 3, 'subscribers': 40},
    'todo': {'contacts': 1, 'revisions': 2},
    'highlights': null,
  },
};

void main() {
  test('WeeklyReportState lit le rapport complet', () {
    final state = WeeklyReportState.fromJson(_stateJson);
    final report = state.report;

    expect(state.enabled, isTrue);
    expect(state.sentAt, isNotNull);
    expect(report.from, DateTime(2026, 10, 7));
    expect(report.change, 20);
    expect(report.topContent.single.title, 'Mon article');
    expect(report.estimates.single.aiHours, '45 – 70 h');
    expect(report.applicationsViewed.single.firstTime, isTrue);
    expect(report.cvDownloads, 6);
    expect(report.todo.revisions, 2);
    expect(report.todo.engagements, 0);
    expect(report.highlights, isNull);
  });

  test('un « todo » vide arrive en tableau PHP et ne casse pas la lecture', () {
    final report = WeeklyReport.fromJson({
      ...(_stateJson['report']! as Map<String, dynamic>),
      'todo': <dynamic>[],
      'highlights': ['Point 1', 'Point 2'],
    });

    expect(report.todo.total, 0);
    expect(report.highlights, ['Point 1', 'Point 2']);
  });

  late FakeDioAdapter adapter;
  late WeeklyReportRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = WeeklyReportRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('get demande les points à retenir seulement si on le veut', () async {
    adapter.whenRequest('GET', '/v1/weekly-report', statusCode: 200, body: _stateJson);

    await repository.get();
    await repository.get(highlights: true);

    expect(adapter.requests.first.queryParameters['highlights'], 0);
    expect(adapter.requests.last.queryParameters['highlights'], 1);
  });

  test('setEnabled et sendNow', () async {
    adapter
      ..whenRequest('PUT', '/v1/weekly-report', statusCode: 200, body: {'enabled': false})
      ..whenRequest('POST', '/v1/weekly-report/send', statusCode: 200, body: {'status': 'no_recipient'});

    expect(await repository.setEnabled(false), isFalse);
    expect(adapter.requests.first.data, {'enabled': false});
    expect(await repository.sendNow(), 'no_recipient');
  });
}
