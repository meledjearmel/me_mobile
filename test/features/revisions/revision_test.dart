import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:me_mobile/app/theme/app_palette_variant.dart';
import 'package:me_mobile/app/theme/app_theme.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/api/api_exception.dart';
import 'package:me_mobile/core/api/api_providers.dart';
import 'package:me_mobile/features/revisions/data/revision.dart';
import 'package:me_mobile/features/revisions/data/revision_repository.dart';
import 'package:me_mobile/features/revisions/presentation/revision_detail_screen.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _summary = {
  'id': 7,
  'content_type': 'project',
  'content_type_label': 'Projet',
  'content_id': 3,
  'title': 'Portfolio',
  'edit_url': 'https://armeldev.xyz/admin/projects/3/edit',
  'summary': 'Accroche plus courte.',
  'drafted_by': 'Claude Code',
  'status': 'pending',
  'created_at': '2026-10-11T10:00:00Z',
  'decided_at': null,
};

final _detail = {
  'data': {
    ..._summary,
    'fields': [
      {'field': 'tagline', 'locale': 'fr', 'before': 'Ancienne', 'after': 'Nouvelle', 'current': 'Ancienne'},
      {'field': 'tagline', 'locale': 'en', 'before': 'Old', 'after': 'New', 'current': 'Changed'},
      {
        'field': 'key_figures',
        'locale': 'fr',
        'before': <dynamic>[],
        'after': [
          {'value': '3×', 'label': 'plus rapide'},
        ],
        'current': null,
      },
    ],
  },
};

const _applied = {
  'data': {'id': 7, 'status': 'applied'},
};

void main() {
  late FakeDioAdapter adapter;
  late ApiClient api;

  setUpAll(() => initializeDateFormatting('fr_FR'));

  setUp(() {
    adapter = FakeDioAdapter();
    api = ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter);
  });

  test('liste par statut et détail avec les champs', () async {
    adapter
      ..whenRequest(
        'GET',
        '/v1/revisions',
        statusCode: 200,
        body: {
          'data': [_summary],
        },
      )
      ..whenRequest('GET', '/v1/revisions/7', statusCode: 200, body: _detail);
    final repository = RevisionRepository(api);

    final list = await repository.list(RevisionStatus.applied);
    expect(adapter.requests.single.queryParameters['status'], 'applied');
    expect(list.single.draftedBy, 'Claude Code');
    expect(list.single.fields, isEmpty);

    final revision = await repository.get(7);
    expect(revision.fields, hasLength(3));
    expect(revision.fields[0].changedSince, isFalse);
    expect(revision.fields[1].changedSince, isTrue);
    // Liste vide et null se valent.
    expect(revision.fields[2].changedSince, isFalse);
  });

  test('image proposée : couverture avec l\'actuelle, sinon null', () {
    final revision = Revision.fromJson({
      ..._summary,
      'fields': <dynamic>[],
      'image': {'role': 'cover', 'url': 'https://x/new.webp', 'current_url': 'https://x/old.webp'},
    });
    expect(revision.fields, isEmpty);
    expect(revision.image!.isCover, isTrue);
    expect(revision.image!.currentUrl, 'https://x/old.webp');

    expect(Revision.fromJson({..._summary, 'image': null}).image, isNull);
    final gallery = Revision.fromJson({
      ..._summary,
      'image': {'role': 'gallery', 'url': 'https://x/g.webp', 'current_url': null},
    });
    expect(gallery.image!.isCover, isFalse);
  });

  test('apply et reject ; 409 si déjà traitée', () async {
    adapter
      ..whenRequest('POST', '/v1/revisions/7/apply', statusCode: 200, body: _applied)
      ..whenRequest('POST', '/v1/revisions/8/reject', statusCode: 409, body: {'message': 'Déjà traitée.'});
    final repository = RevisionRepository(api);

    expect(await repository.apply(7), RevisionStatus.applied);
    await expectLater(repository.reject(8), throwsA(isA<ApiException>()));
  });

  test('valeurs lisibles : texte, liste en puces, objets', () {
    expect(formatRevisionValue(null), '(vide)');
    expect(formatRevisionValue(<dynamic>[]), '(vide)');
    expect(formatRevisionValue('Texte'), 'Texte');
    expect(formatRevisionValue(['a', 'b']), '• a\n• b');
    expect(
      formatRevisionValue([
        {'value': '3×', 'label': 'plus rapide'},
      ]),
      '• value : 3× — label : plus rapide',
    );
  });

  testWidgets('détail : avant/après, alerte si changé, application confirmée', (tester) async {
    adapter
      ..whenRequest('GET', '/v1/revisions/7', statusCode: 200, body: _detail)
      ..whenRequest('POST', '/v1/revisions/7/apply', statusCode: 200, body: _applied);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: AppTheme.build(AppPaletteVariant.values.first, Brightness.light),
          home: const RevisionDetailScreen(id: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle'), findsOneWidget);
    expect(find.text('Ce champ a changé depuis la proposition.'), findsOneWidget);
    expect(find.text('Changed'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Appliquer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('seront écrasés'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Appliquer'));
    await tester.pumpAndSettle();

    expect(adapter.requests.last.method, 'POST');
    expect(adapter.requests.last.path, '/v1/revisions/7/apply');
  });
}
