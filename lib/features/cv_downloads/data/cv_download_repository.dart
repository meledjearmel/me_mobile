import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import 'cv_download.dart';

final cvDownloadRepositoryProvider = Provider<CvDownloadRepository>(
  (ref) => CvDownloadRepository(ref.watch(apiClientProvider)),
);

/// `GET /v1/cv-downloads` (filtrable), `GET|DELETE /v1/cv-downloads/{id}`.
class CvDownloadRepository {
  const CvDownloadRepository(this._api);

  final ApiClient _api;

  /// [search] porte sur l'email, la ville, le pays, le site d'origine et la
  /// campagne ; [countryCode] est un code ISO (`CI`, `FR`…).
  Future<Paginated<CvDownload>> list({
    required int page,
    String search = '',
    String? countryCode,
    String? locale,
  }) async {
    final json = await _api.get(
      '/v1/cv-downloads',
      query: {'page': page, 'per_page': 25, 'search': search, 'country_code': countryCode, 'locale': locale},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => CvDownload.fromJson(item));
  }

  Future<CvDownload> get(int id) async =>
      CvDownload.fromJson(await _api.get('/v1/cv-downloads/$id') as Map<String, dynamic>);

  Future<void> delete(int id) => _api.delete('/v1/cv-downloads/$id');
}
