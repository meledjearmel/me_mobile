import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../core/api/multipart.dart';
import '../../../../core/api/paginated.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import 'job_profile.dart';

final jobProfileRepositoryProvider = Provider<JobProfileRepository>(
  (ref) => JobProfileRepository(ref.watch(apiClientProvider)),
);

/// `GET|POST|PUT|DELETE /v1/job-profiles`, plus
/// `DELETE /v1/job-profiles/{id}/cv/{locale}` (§4.3).
class JobProfileRepository {
  const JobProfileRepository(this._api);

  final ApiClient _api;

  Future<Paginated<JobProfile>> list({required int page, String search = '', String? status}) async {
    final json = await _api.get(
      '/v1/job-profiles',
      query: {'page': page, 'per_page': 25, 'search': search, 'status': status},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => JobProfile.fromJson(item));
  }

  Future<JobProfile> get(int id) async =>
      JobProfile.fromJson(await _api.get('/v1/job-profiles/$id') as Map<String, dynamic>);

  /// Toujours envoyé en multipart (`_method=PUT` en modification, §3.4) :
  /// seul moyen d'envoyer un fichier CV, que la requête en contienne un ou non.
  Future<JobProfile> save({
    int? id,
    required String key,
    required Translated label,
    required Translated description,
    required Translated heroTitle,
    required Translated heroWords,
    required Translated cvDescription,
    required int sortOrder,
    required PublicationStatus status,
    MultipartFile? cvFileFr,
    MultipartFile? cvFileEn,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = buildFormData({
      'key': key,
      'label': label,
      'description': description,
      'hero_title': heroTitle,
      'hero_words': heroWords,
      'cv_description': cvDescription,
      'sort_order': sortOrder,
      'status': status.wireValue,
      if (cvFileFr != null) 'cv_file_fr': cvFileFr,
      if (cvFileEn != null) 'cv_file_en': cvFileEn,
    }, method: id == null ? null : 'PUT');

    final path = id == null ? '/v1/job-profiles' : '/v1/job-profiles/$id';
    final json = await _api.upload(path, form, onProgress: onProgress);
    return JobProfile.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/job-profiles/$id');

  /// [locale] : `'fr'` ou `'en'`.
  Future<JobProfile> deleteCv(int id, String locale) async =>
      JobProfile.fromJson(await _api.delete('/v1/job-profiles/$id/cv/$locale') as Map<String, dynamic>);
}
