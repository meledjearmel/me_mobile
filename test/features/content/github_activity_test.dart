import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:me_mobile/app/theme/app_palette_variant.dart';
import 'package:me_mobile/app/theme/app_theme.dart';
import 'package:me_mobile/features/content/github/data/github_repositories.dart';
import 'package:me_mobile/features/content/github/presentation/widgets/contribution_activity_card.dart';

/// 365 jours finissant le dimanche 11 octobre 2026 ; 1 contribution par jour,
/// 5 le dernier jour.
List<ContributionDay> _calendar() {
  final end = DateTime(2026, 10, 11);
  return [
    for (var i = 364; i >= 0; i--)
      ContributionDay(
        date: DateTime(end.year, end.month, end.day - i),
        count: i == 0 ? 5 : 1,
        level: i == 0 ? 4 : 1,
        repositories: i == 0
            ? const [
                ContributionRepository(fullName: 'meledjearmel/me', isPrivate: false, count: 3),
                ContributionRepository(fullName: 'neocodesupport/fne-client', isPrivate: true, count: 2),
              ]
            : const [],
      ),
  ];
}

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test('calendar : jours et dépôts lus, null sans jeton', () {
    final data = GitHubSelection.fromJson({
      'available': [],
      'selected': [],
      'calendar': [
        {
          'date': '2026-10-10',
          'count': 4,
          'level': 3,
          'repositories': [
            {'full_name': 'neocodesupport/fne-client', 'private': true, 'count': 4},
          ],
        },
      ],
      'synced_at': null,
      'has_token': true,
    });

    final day = data.calendar!.single;
    expect(day.date, DateTime(2026, 10, 10));
    expect(day.count, 4);
    expect(day.level, 3);
    expect(day.repositories.single.isPrivate, isTrue);
    expect(
      GitHubSelection.fromJson({'available': [], 'selected': [], 'calendar': null, 'has_token': false}).calendar,
      isNull,
    );
  });

  test('découpage semaine, mois et année', () {
    final calendar = _calendar();

    expect(ActivityRange.week.slice(calendar), hasLength(7));
    expect(ActivityRange.week.slice(calendar).last.date, DateTime(2026, 10, 11));
    expect(ActivityRange.month.slice(calendar), hasLength(30));
    expect(ActivityRange.year.slice(calendar), hasLength(365));

    // 30 jours depuis le samedi 12 septembre : 5 cases vides devant (lun → ven).
    final month = mondayAligned(ActivityRange.month.slice(calendar));
    expect(month.take(5), everyElement(isNull));
    expect(month[5]!.date, DateTime(2026, 9, 12));

    // Année : du dimanche 12 octobre 2025, 6 cases vides puis 52 semaines pleines.
    final year = weeks(calendar);
    expect(year, hasLength(53));
    expect(year.every((w) => w.length == 7), isTrue);
    expect(year.first.take(6), everyElement(isNull));
    expect(year.last.last!.date, DateTime(2026, 10, 11));
  });

  Future<void> pump(WidgetTester tester, List<ContributionDay>? calendar) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(AppPaletteVariant.values.first, Brightness.light),
      home: Scaffold(
        body: ListView(children: [ContributionActivityCard(calendar: calendar)]),
      ),
    ),
  );

  testWidgets('sans calendrier : invite à configurer le jeton', (tester) async {
    await pump(tester, null);

    expect(find.textContaining('GITHUB_TOKEN'), findsOneWidget);
  });

  testWidgets('total par période et détail d\'un jour, dépôts privés nommés', (tester) async {
    await pump(tester, _calendar());

    expect(find.text('11 contributions'), findsOneWidget);

    await tester.tap(find.text('Mois'));
    await tester.pumpAndSettle();
    expect(find.text('34 contributions'), findsOneWidget);

    await tester.tap(find.text('Année'));
    await tester.pumpAndSettle();
    expect(find.text('369 contributions'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('day-2026-10-11')));
    await tester.pumpAndSettle();
    expect(find.text('Dimanche 11 octobre 2026'), findsOneWidget);
    expect(find.text('5 contributions'), findsOneWidget);
    expect(find.text('neocodesupport/fne-client'), findsOneWidget);
    expect(find.text('privé'), findsOneWidget);
  });
}
