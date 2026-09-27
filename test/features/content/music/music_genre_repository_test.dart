import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/content/music/data/music_genre.dart';
import 'package:me_mobile/features/content/music/data/music_genre_repository.dart';

import '../../../helpers/fake_dio_adapter.dart';
import '../../../helpers/memory_token_storage.dart';

const _genreJson = {
  'id': 1,
  'key': 'ambient',
  'label': {'fr': 'Ambiance', 'en': 'Ambient'},
  'sort_order': 1,
};

void main() {
  test('MusicGenre.fromJson analyse correctement', () {
    final genre = MusicGenre.fromJson(_genreJson);
    expect(genre.key, 'ambient');
    expect(genre.label.en, 'Ambient');
  });

  late FakeDioAdapter adapter;
  late MusicGenreRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = MusicGenreRepository(
      ApiClient(baseUrl: 'https://me.armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('save envoie key, label et sort_order en JSON', () async {
    adapter.whenRequest('POST', '/v1/music-genres', statusCode: 200, body: _genreJson);

    await repository.save(key: 'ambient', label: const Translated(fr: 'Ambiance', en: 'Ambient'), sortOrder: 1);

    final body = adapter.requests.single.data as Map;
    expect(body['key'], 'ambient');
    expect(body['label'], {'fr': 'Ambiance', 'en': 'Ambient'});
  });

  test('delete appelle DELETE /v1/music-genres/{id}', () async {
    adapter.whenRequest('DELETE', '/v1/music-genres/1', statusCode: 204);
    await repository.delete(1);
    expect(adapter.requests.single.path, '/v1/music-genres/1');
  });
}
