import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/push/push_target.dart';
import 'package:me_mobile/features/dashboard/data/dashboard.dart';
import 'package:me_mobile/features/dashboard/presentation/widgets/home_sections.dart';

void main() {
  group('describeTrend', () {
    test('rien sans donnée ni comparaison', () {
      expect(describeTrend(null), isNull);
      expect(describeTrend((current: 0, previous: 0)), isNull);
    });

    test('écart brut sur une petite base, pourcentage au-delà', () {
      expect(describeTrend((current: 5, previous: 2)), (label: '▲ 3', up: true));
      expect(describeTrend((current: 80, previous: 100)), (label: '▼ 20 %', up: false));
      expect(describeTrend((current: 4, previous: 4)), (label: '= stable', up: null));
    });
  });

  test('trends et agenda sont lus, et absents avec une API plus ancienne', () {
    final trends = DashboardTrends.fromJson({
      'period_days': 7,
      'metrics': {
        'visits': {'current': 12, 'previous': 9},
      },
    });
    expect(trends['visits'], (current: 12, previous: 9));
    expect(trends['contacts'], isNull);

    final item = AgendaItem.fromJson({
      'id': 4,
      'name': 'Awa',
      'status': 'pending',
      'location': 'video',
      'starts_at': '2026-10-16T10:00:00+00:00',
    });
    expect(item.isPending, isTrue);
  });

  test("l'activité récente mélange les types, du plus récent au plus ancien", () {
    final recent = DashboardRecent.fromJson({
      'contacts': [
        {'id': 1, 'name': 'A', 'subject': 'Site', 'is_new': true, 'at': '2026-10-10T10:00:00Z'},
      ],
      'engagements': [
        {'id': 2, 'name': 'B', 'is_new': false, 'at': '2026-10-12T10:00:00Z'},
      ],
      'testimonials': [
        {'id': 3, 'name': 'C', 'excerpt': 'Top', 'at': '2026-10-11T10:00:00Z'},
      ],
    });

    final items = recentActivity(recent);

    expect(items.map((e) => e.type), [
      PushResourceType.engagement,
      PushResourceType.testimonial,
      PushResourceType.contact,
    ]);
  });
}
