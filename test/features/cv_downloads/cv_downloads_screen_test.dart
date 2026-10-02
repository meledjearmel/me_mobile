import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:me_mobile/app/theme/app_palette_variant.dart';
import 'package:me_mobile/app/theme/app_theme.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/api/api_providers.dart';
import 'package:me_mobile/features/cv_downloads/presentation/cv_downloads_screen.dart';
import 'package:me_mobile/features/dashboard/data/dashboard.dart';
import 'package:me_mobile/features/dashboard/data/dashboard_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

Map<String, dynamic> _download(int id, {String? countryCode, String? city, String? country, String? email}) => {
  'id': id,
  'job_profile_id': 2,
  'job_profile_label': {'fr': 'Développeur mobile', 'en': 'Mobile developer'},
  'locale': 'en',
  'source': 'uploaded',
  'email': email,
  'country_code': countryCode,
  'country': country,
  'city': city,
  'referrer_host': 'linkedin.com',
  'utm_source': null,
  'utm_medium': null,
  'utm_campaign': null,
  'origin': 'linkedin.com',
  'device': 'mobile',
  'created_at': null,
};

const _summary = DashboardCvDownloads(
  total: 42,
  period: 12,
  withEmail: 5,
  byCountry: [CategoryCount(label: "Côte d'Ivoire", count: 7)],
  byOrigin: [CategoryCount(label: 'direct', count: 4)],
);

void main() {
  late FakeDioAdapter adapter;

  setUpAll(() => initializeDateFormatting('fr_FR'));

  setUp(() {
    adapter = FakeDioAdapter()
      ..whenRequest(
        'GET',
        '/v1/cv-downloads',
        statusCode: 200,
        body: {
          'data': [
            _download(1, countryCode: 'CI', city: 'Abidjan', country: "Côte d'Ivoire", email: 'rh@example.com'),
            _download(2),
          ],
          'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 2},
        },
      );
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(
            ApiClient(baseUrl: 'https://me.test/api', tokens: MemoryTokenStorage(), adapter: adapter),
          ),
          dashboardProvider.overrideWith((ref) => throw UnimplementedError()),
        ],
        child: MaterialApp(
          theme: AppTheme.build(AppPaletteVariant.values.first, Brightness.light),
          home: const CvDownloadsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('liste les téléchargements, lieu inconnu compris, et filtre par langue', (tester) async {
    await pumpScreen(tester);

    expect(find.text("Abidjan, Côte d'Ivoire"), findsOneWidget);
    expect(find.text('Lieu inconnu'), findsOneWidget);
    expect(find.text('Importé'), findsNWidgets(2));

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(adapter.requests.last.queryParameters['locale'], 'en');
  });

  testWidgets('le détail affiche email et provenance, puis supprime après confirmation', (tester) async {
    adapter.whenRequest('DELETE', '/v1/cv-downloads/1', statusCode: 204);
    await pumpScreen(tester);

    await tester.tap(find.text("Abidjan, Côte d'Ivoire"));
    await tester.pumpAndSettle();

    expect(find.text('rh@example.com'), findsOneWidget);
    expect(find.text('Mobile'), findsOneWidget);

    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(adapter.requests.last.method, 'DELETE');
    expect(find.text('Téléchargement supprimé'), findsOneWidget);
    expect(find.text("Abidjan, Côte d'Ivoire"), findsNothing);
  });

  testWidgets('la carte des Statistiques montre la période, le total et le premier pays', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPaletteVariant.values.first, Brightness.dark),
        home: const Scaffold(body: CvDownloadsCard(summary: _summary)),
      ),
    );

    expect(find.text('12'), findsOneWidget);
    expect(find.textContaining("42 au total · 5 avec email · Côte d'Ivoire"), findsOneWidget);
  });

  test('flagEmoji convertit un code ISO et ignore le reste', () {
    expect(flagEmoji('CI'), '🇨🇮');
    expect(flagEmoji('fr'), '🇫🇷');
    expect(flagEmoji(null), isNull);
    expect(flagEmoji('XYZ'), isNull);
  });
}
