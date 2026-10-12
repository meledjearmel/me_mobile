import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/app/theme/app_palette_variant.dart';
import 'package:me_mobile/app/theme/app_theme.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/api/api_exception.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/projects/data/project.dart';
import 'package:me_mobile/features/projects/data/project_repository.dart';
import 'package:me_mobile/shared/widgets/ai_badge.dart';
import 'package:me_mobile/shared/widgets/translated_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _draft = {
  'project': {
    'title': 'Client FNE',
    'slug': 'client-fne',
    'tagline': 'Facturation normalisée',
    'role': 'Développeur principal',
    'client': null,
    'platform': 'Web',
    'context': 'Contexte.',
    'challenges': null,
    'realization': 'Réalisation.',
    'result': 'Résultat.',
    'decisions': [
      {'choice': 'Laravel', 'reason': 'Écosystème'},
    ],
    'key_figures': [
      {'value': '3×', 'label': 'plus rapide'},
    ],
    'started_on': '2025-03',
    'ended_on': null,
    'team_size': 2,
    'technologies': [4, 5],
    'domains': [1],
    'job_profiles': [],
    'github_repository': 'neocodesupport/fne-client',
    'repo_url': 'https://github.com/neocodesupport/fne-client',
    'demo_url': null,
    'is_open_source': true,
  },
};

void main() {
  late FakeDioAdapter adapter;
  late ProjectRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = ProjectRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('statut brouillon et drafted_by lus', () {
    final project = Project.fromJson({
      'id': 1,
      'slug': 'x',
      'title': {'fr': 'X', 'en': null},
      'context': null,
      'realization': null,
      'result': null,
      'status': 'draft',
      'drafted_by': 'Codex',
    });

    expect(project.status, ProjectStatus.draft);
    expect(project.status.label, 'Brouillon');
    expect(project.draftedBy, 'Codex');
  });

  test('pré-remplissage : dépôt et notes envoyés, champs français lus', () async {
    adapter.whenRequest('POST', '/v1/ai/draft-project', statusCode: 200, body: _draft);

    final draft = await repository.draftWithAi(githubRepository: 'neocodesupport/fne-client', notes: '  Notes  ');

    expect(adapter.requests.single.data, {'github_repository': 'neocodesupport/fne-client', 'notes': 'Notes'});
    expect(draft.title, 'Client FNE');
    expect(draft.decisions.single.choice, const Translated(fr: 'Laravel'));
    expect(draft.keyFigures.single.label, const Translated(fr: 'plus rapide'));
    expect(draft.technologies, [4, 5]);
    expect(draft.isOpenSource, isTrue);
    expect(draft.demoUrl, isNull);
  });

  test('pré-remplissage : dépôt privé refusé (422) avec son message', () async {
    adapter.whenRequest(
      'POST',
      '/v1/ai/draft-project',
      statusCode: 422,
      body: {
        'message': 'Ce dépôt est privé.',
        'errors': {
          'github_repository': ['Ce dépôt est privé.'],
        },
      },
    );

    await expectLater(
      repository.draftWithAi(githubRepository: 'moi/prive'),
      throwsA(isA<ValidationException>().having((e) => e.message, 'message', 'Ce dépôt est privé.')),
    );
  });

  testWidgets('badge IA seulement sur un brouillon rédigé par l\'IA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPaletteVariant.values.first, Brightness.light),
        home: const Column(
          children: [
            AiBadge(draftedBy: 'Claude Code', isDraft: true),
            AiBadge(draftedBy: 'Codex', isDraft: false),
            AiBadge(draftedBy: null, isDraft: true),
          ],
        ),
      ),
    );

    expect(find.text('IA · Claude Code'), findsOneWidget);
    expect(find.textContaining('Codex'), findsNothing);
  });

  testWidgets('EnglishOptional : l\'onglet EN vide n\'est plus signalé', (tester) async {
    Future<void> pump(bool optional) => tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EnglishOptional(
              enabled: optional,
              child: TranslatedField(
                label: 'Titre',
                value: const Translated(fr: 'Titre'),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await pump(false);
    final warnings = find.byIcon(Icons.circle).evaluate().length;
    await pump(true);

    expect(find.byIcon(Icons.circle).evaluate().length, lessThan(warnings));
  });
}
