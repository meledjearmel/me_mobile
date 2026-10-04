import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/content/github/data/github_repositories.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _payload = {
  'available': [
    {
      'full_name': 'meledjearmel/me',
      'name': 'me',
      'description': 'Portfolio',
      'language': 'PHP',
      'stars': 3,
      'url': 'https://github.com/meledjearmel/me',
      'pushed_at': '2026-10-04T10:00:00Z',
      'private': false,
      'archived': false,
      'contribution': false,
    },
    {
      'full_name': 'neocodesupport/fne-client',
      'name': 'fne-client',
      'description': null,
      'language': null,
      'stars': 0,
      'url': 'https://github.com/neocodesupport/fne-client',
      'pushed_at': null,
      'private': true,
      'archived': false,
      'contribution': true,
    },
  ],
  'selected': ['neocodesupport/fne-client'],
  'synced_at': '2026-10-04T12:00:00Z',
  'has_token': true,
};

void main() {
  late FakeDioAdapter adapter;
  late GitHubApi api;

  setUp(() {
    adapter = FakeDioAdapter();
    api = GitHubApi(ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter));
  });

  test('lit les dépôts disponibles, la sélection et le jeton', () async {
    adapter.whenRequest('GET', '/v1/github', statusCode: 200, body: _payload);

    final data = await api.get();

    expect(data.available, hasLength(2));
    expect(data.available.last.isPrivate, isTrue);
    expect(data.available.last.isContribution, isTrue);
    expect(data.selected, ['neocodesupport/fne-client']);
    expect(data.hasToken, isTrue);
  });

  test('available vide (chaîne ou tableau vide) ne casse rien', () {
    expect(
      GitHubSelection.fromJson({'available': '', 'selected': [], 'synced_at': null, 'has_token': false}).available,
      isEmpty,
    );
  });

  test('select envoie les noms complets dans l\'ordre', () async {
    adapter.whenRequest('PUT', '/v1/github', statusCode: 200, body: _payload);

    await api.select(['meledjearmel/me', 'neocodesupport/fne-client']);

    expect(adapter.requests.single.data, {
      'repositories': ['meledjearmel/me', 'neocodesupport/fne-client'],
    });
  });
}
