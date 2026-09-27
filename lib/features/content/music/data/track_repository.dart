import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../core/api/multipart.dart';
import '../../../../core/api/paginated.dart';
import 'track.dart';

final trackRepositoryProvider = Provider<TrackRepository>((ref) => TrackRepository(ref.watch(apiClientProvider)));

/// `GET|POST|PUT|DELETE /v1/tracks` (§4.3). `audio` est obligatoire à la
/// création, facultatif en modification (remplace le fichier existant).
class TrackRepository {
  const TrackRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Track>> list({required int page, String search = '', int? musicGenreId}) async {
    final json = await _api.get(
      '/v1/tracks',
      query: {'page': page, 'per_page': 25, 'search': search, 'music_genre_id': musicGenreId},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Track.fromJson(item));
  }

  Future<Track> get(int id) async => Track.fromJson(await _api.get('/v1/tracks/$id') as Map<String, dynamic>);

  Future<Track> save({
    int? id,
    required int musicGenreId,
    required String title,
    required String? artist,
    required int sortOrder,
    MultipartFile? audio,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = buildFormData({
      'music_genre_id': musicGenreId,
      'title': title,
      'artist': artist,
      'sort_order': sortOrder,
      if (audio != null) 'audio': audio,
    }, method: id == null ? null : 'PUT');

    final path = id == null ? '/v1/tracks' : '/v1/tracks/$id';
    final json = await _api.upload(path, form, onProgress: onProgress);
    return Track.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/tracks/$id');
}
