import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/models/publication_status.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/celebrations/data/congratulation.dart';
import 'package:me_mobile/features/content/distinctions/application/distinction_list_controller.dart';
import 'package:me_mobile/features/content/distinctions/data/distinction.dart';
import 'package:me_mobile/features/content/distinctions/data/distinction_repository.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _json = {
  'id': 1,
  'title': {'fr': 'Meilleur agent du premier semestre 2025', 'en': 'Best agent, H1 2025'},
  'issuer': 'CIAPOL',
  'description': <String>[],
  'awarded_on': '2025-06-30',
  'url': null,
  'context_type': 'experience',
  'context_id': 1,
  'context_label': 'CIAPOL — Centre Ivoirien Antipollution',
  'congratulations_count': 12,
  'status': 'published',
  'drafted_by': null,
  'sort_order': 1,
};

void main() {
  late FakeDioAdapter adapter;
  late DistinctionRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = DistinctionRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('fromJson lit le contexte, la date et le compteur ; description `[]` donne des chaînes vides', () {
    final d = Distinction.fromJson(_json);

    expect(d.title.fr, 'Meilleur agent du premier semestre 2025');
    expect(d.description.isEmpty, isTrue);
    expect(d.awardedOn, DateTime(2025, 6, 30));
    expect(d.contextType, DistinctionContextType.experience);
    expect(d.contextId, 1);
    expect(d.contextLabel, 'CIAPOL — Centre Ivoirien Antipollution');
    expect(d.congratulationsCount, 12);
    expect(d.status, PublicationStatus.published);
  });

  test('fromJson : sans contexte, une seule langue de description', () {
    final d = Distinction.fromJson({
      ..._json,
      'context_type': null,
      'context_id': null,
      'context_label': null,
      'description': {'fr': 'Remis en interne'},
      'drafted_by': 'Claude Code',
    });

    expect(d.contextType, isNull);
    expect(d.description.fr, 'Remis en interne');
    expect(d.description.en, '');
    expect(d.draftedBy, 'Claude Code');
  });

  test('save : JSON, date Y-m-d, PUT en modification', () async {
    adapter.whenRequest('PUT', '/v1/distinctions/1', statusCode: 200, body: _json);

    await repository.save(
      id: 1,
      title: const Translated(fr: 'Prix', en: 'Award'),
      issuer: 'CIAPOL',
      description: const Translated(fr: 'Contexte'),
      awardedOn: DateTime(2025, 6, 30),
      url: null,
      contextType: DistinctionContextType.project,
      contextId: 7,
      status: PublicationStatus.draft,
      sortOrder: 2,
    );

    final data = adapter.requests.single.data as Map<String, dynamic>;
    expect(data['title'], {'fr': 'Prix', 'en': 'Award'});
    expect(data['description'], {'fr': 'Contexte', 'en': ''});
    expect(data['awarded_on'], '2025-06-30');
    expect(data['context_type'], 'project');
    expect(data['context_id'], 7);
    expect(data['status'], 'draft');
    expect(data['sort_order'], 2);
  });

  test('save : sans contexte, envoie context_type et context_id à null (détache)', () async {
    adapter.whenRequest('POST', '/v1/distinctions', statusCode: 201, body: _json);

    await repository.save(
      title: const Translated(fr: 'Prix'),
      issuer: 'CIAPOL',
      description: const Translated(),
      awardedOn: DateTime(2025, 6, 30),
      url: 'https://exemple.ci',
      contextType: null,
      contextId: 3,
      status: PublicationStatus.draft,
      sortOrder: 0,
    );

    final data = adapter.requests.single.data as Map<String, dynamic>;
    expect(data.containsKey('context_type'), isTrue);
    expect(data['context_type'], isNull);
    expect(data['context_id'], isNull);
    expect(data['url'], 'https://exemple.ci');
  });

  test('le contrôleur de liste transmet la recherche et le filtre de statut', () async {
    final page = {
      'data': [_json],
      'meta': {'current_page': 1, 'last_page': 1, 'per_page': 50, 'total': 1},
    };
    adapter.whenRequest('GET', '/v1/distinctions', statusCode: 200, body: page);
    adapter.whenRequest('GET', '/v1/distinctions', statusCode: 200, body: page);
    final container = ProviderContainer(overrides: [distinctionRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);

    final state = await container.read(distinctionListProvider.future);
    expect(state.items.single.issuer, 'CIAPOL');

    await container.read(distinctionListProvider.notifier).setFilters(const {'status': 'draft'});
    expect(adapter.requests.last.queryParameters['status'], 'draft');
  });

  test('Congratulation.fromJson lit distinction_id (int ou null)', () {
    final base = {'id': 3, 'source': 'about', 'reason': 'Bravo', 'count': 2, 'created_at': '2026-10-01T10:00:00Z'};

    expect(Congratulation.fromJson({...base, 'distinction_id': 1}).distinctionId, 1);
    expect(Congratulation.fromJson({...base, 'distinction_id': null}).distinctionId, isNull);
    expect(Congratulation.fromJson({...base, 'source': 'surprise'}).distinctionId, isNull);
  });
}
