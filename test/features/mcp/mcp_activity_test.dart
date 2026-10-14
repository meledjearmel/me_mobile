import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/mcp/data/mcp_activity.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

/// Paginateur Laravel renvoyé tel quel : la pagination est à la racine, pas dans `meta`.
const _pageJson = {
  'data': [
    {
      'id': 1,
      'client': 'Claude Code',
      'kind': 'tool',
      'name': 'get-project',
      'title': 'Lire un projet',
      'target': {'label': 'App Station', 'url': 'https://armeldev.xyz/admin/projects/12/edit'},
      'success': true,
      'error': null,
      'duration_ms': 42,
      'created_at': '2026-10-14T08:00:00+00:00',
    },
    {
      'id': 2,
      'client': 'Claude',
      'kind': 'prompt',
      'name': 'add-content',
      'title': 'Ajouter un contenu',
      'target': null,
      'success': false,
      'error': 'Contenu introuvable',
      'duration_ms': 5,
      'created_at': '2026-10-14T07:00:00+00:00',
    },
  ],
  'current_page': 1,
  'last_page': 3,
  'per_page': 25,
  'total': 60,
  'filters': {
    'clients': ['Claude', 'Claude Code'],
    'tools': [
      {'value': 'add-content', 'label': 'Ajouter un contenu'},
      {'value': 'get-project', 'label': 'Lire un projet'},
    ],
  },
};

void main() {
  late FakeDioAdapter adapter;
  late McpActivityRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = McpActivityRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('list lit la pagination à la racine, les appels et les options de filtre', () async {
    adapter.whenRequest('GET', '/v1/mcp-activity', statusCode: 200, body: _pageJson);

    final result = await repository.list(page: 1);

    expect(result.page.total, 60);
    expect(result.page.hasMore, isTrue);
    expect(result.page.items.first.target!.label, 'App Station');
    expect(result.page.items.last.isPrompt, isTrue);
    expect(result.page.items.last.success, isFalse);
    expect(result.page.items.last.target, isNull);
    expect(result.filters.clients, ['Claude', 'Claude Code']);
    expect(result.filters.tools.last.label, 'Lire un projet');
  });

  test('list envoie les filtres renseignés et ignore les autres', () async {
    adapter.whenRequest('GET', '/v1/mcp-activity', statusCode: 200, body: _pageJson);

    await repository.list(page: 2, search: 'projet', client: 'Claude', status: 'error', days: 7);

    final query = adapter.requests.single.queryParameters;
    expect(query['page'], 2);
    expect(query['search'], 'projet');
    expect(query['client'], 'Claude');
    expect(query['status'], 'error');
    expect(query['days'], 7);
    expect(query.containsKey('name'), isFalse);
    expect(query.containsKey('kind'), isFalse);
  });
}
