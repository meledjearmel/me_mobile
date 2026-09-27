import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../core/api/paginated.dart';
import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import 'job_profile.dart';

final jobProfileRepositoryProvider = Provider<JobProfileRepository>(
  (ref) => JobProfileRepository(ref.watch(apiClientProvider)),
);

/// `GET|POST|PUT|DELETE /v1/job-profiles` (§4.3).
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
  }) async {
    final data = {
      'key': key,
      'label': label.toJson(),
      'description': description.toJson(),
      'hero_title': heroTitle.toJson(),
      'hero_words': heroWords.toJson(),
      'cv_description': cvDescription.toJson(),
      'sort_order': sortOrder,
      'status': status.wireValue,
    };
    final json = id == null
        ? await _api.post('/v1/job-profiles', data: data)
        : await _api.put('/v1/job-profiles/$id', data: data);
    return JobProfile.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/job-profiles/$id');
}
