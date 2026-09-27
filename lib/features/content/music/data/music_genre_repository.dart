import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../core/api/paginated.dart';
import '../../../../core/models/translated.dart';
import '../../data/reference_repository.dart';
import 'music_genre.dart';

final musicGenreRepositoryProvider = Provider<MusicGenreRepository>(
  (ref) => MusicGenreRepository(ref.watch(apiClientProvider)),
);

/// `GET|POST|PUT|DELETE /v1/music-genres` (§4.3).
class MusicGenreRepository {
  const MusicGenreRepository(this._api);

  final ApiClient _api;

  Future<Paginated<MusicGenre>> list({required int page, String search = ''}) async {
    final json = await _api.get(
      '/v1/music-genres',
      query: {'page': page, 'per_page': 25, 'search': search},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => MusicGenre.fromJson(item));
  }

  Future<MusicGenre> get(int id) async =>
      MusicGenre.fromJson(await _api.get('/v1/music-genres/$id') as Map<String, dynamic>);

  Future<MusicGenre> save({int? id, required String key, required Translated label, required int sortOrder}) async {
    final data = {'key': key, 'label': label.toJson(), 'sort_order': sortOrder};
    final json = id == null
        ? await _api.post('/v1/music-genres', data: data)
        : await _api.put('/v1/music-genres/$id', data: data);
    return MusicGenre.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/music-genres/$id');
}

/// Tous les registres, en cache, pour le sélecteur du formulaire Pistes (§4.4).
final musicGenresAllProvider = FutureProvider<List<MusicGenre>>(
  (ref) => ref.watch(referenceListRepositoryProvider).fetchAll('/v1/music-genres', MusicGenre.fromJson),
);
