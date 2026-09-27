import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/features/content/music/data/track.dart';
import 'package:me_mobile/features/content/music/data/track_repository.dart';

import '../../../helpers/fake_dio_adapter.dart';
import '../../../helpers/memory_token_storage.dart';

const _trackJson = {
  'id': 1,
  'music_genre_id': 2,
  'title': 'Calme',
  'artist': null,
  'sort_order': 1,
  'audio_url': 'https://me.armeldev.xyz/music/calme.mp3',
};

Map<String, String> _fieldMap(FormData form) => {for (final e in form.fields) e.key: e.value};

void main() {
  test('Track.fromJson analyse correctement, artist absent toléré', () {
    final track = Track.fromJson(_trackJson);
    expect(track.title, 'Calme');
    expect(track.artist, isNull);
    expect(track.audioUrl, isNotNull);
  });

  late FakeDioAdapter adapter;
  late TrackRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = TrackRepository(
      ApiClient(baseUrl: 'https://me.armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('list envoie music_genre_id comme filtre', () async {
    adapter.whenRequest(
      'GET',
      '/v1/tracks',
      statusCode: 200,
      body: {
        'data': [_trackJson],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 1},
      },
    );

    await repository.list(page: 1, musicGenreId: 2);

    expect(adapter.requests.single.queryParameters['music_genre_id'], 2);
  });

  test('save sans fichier audio (modification) : pas de _method malgré tout puisqu\'aucun fichier', () async {
    adapter.whenRequest('POST', '/v1/tracks/1', statusCode: 200, body: _trackJson);

    await repository.save(id: 1, musicGenreId: 2, title: 'Calme', artist: null, sortOrder: 1);

    final fields = _fieldMap(adapter.requests.single.data as FormData);
    expect(fields['_method'], 'PUT');
    expect(fields.containsKey('audio'), isFalse);
  });

  test('save avec fichier audio (création) : le fichier part dans form.files', () async {
    adapter.whenRequest('POST', '/v1/tracks', statusCode: 200, body: _trackJson);
    final audio = MultipartFile.fromBytes([1, 2, 3], filename: 'calme.mp3');

    await repository.save(musicGenreId: 2, title: 'Calme', artist: 'Inconnu', sortOrder: 1, audio: audio);

    final form = adapter.requests.single.data as FormData;
    expect(form.files.single.key, 'audio');
    expect(_fieldMap(form).containsKey('_method'), isFalse);
  });
}
