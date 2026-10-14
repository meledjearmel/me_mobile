import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import '../../../core/utils/date_only.dart';
import 'job_application.dart';

final jobApplicationRepositoryProvider = Provider<JobApplicationRepository>(
  (ref) => JobApplicationRepository(ref.watch(apiClientProvider)),
);

/// `GET|POST|PUT|DELETE /v1/job-applications`, l'historique (`…/events`),
/// le CV adapté (`…/cv`, `…/cv/tailor`) et `POST /v1/ai/draft-job-application`.
class JobApplicationRepository {
  const JobApplicationRepository(this._api);

  final ApiClient _api;

  static const _aiTimeout = Duration(seconds: 90);

  Future<Paginated<JobApplication>> list({required int page, String search = '', String? status}) async {
    final json = await _api.get(
      '/v1/job-applications',
      query: {'page': page, 'per_page': 25, 'search': search, 'status': status},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, JobApplication.fromJson);
  }

  Future<JobApplication> get(int id) async => JobApplication.fromJson(_map(await _api.get('/v1/job-applications/$id')));

  /// [projectIds] : les projets montrés, dans l'ordre (6 au plus).
  Future<JobApplication> save({
    int? id,
    required String company,
    String? contactName,
    required String position,
    int? jobProfileId,
    required String locale,
    required String intro,
    String? jobPostingUrl,
    String? jobPostingText,
    String? notes,
    required JobApplicationStatus status,
    DateTime? expiresOn,
    List<int> projectIds = const [],
  }) async {
    final data = {
      'company': company,
      'contact_name': _nullIfBlank(contactName),
      'position': position,
      'job_profile_id': jobProfileId,
      'locale': locale,
      'intro': intro,
      'job_posting_url': _nullIfBlank(jobPostingUrl),
      'job_posting_text': _nullIfBlank(jobPostingText),
      'notes': _nullIfBlank(notes),
      'status': status.wireValue,
      'expires_on': expiresOn == null ? null : formatDateOnly(expiresOn),
      'project_ids': projectIds,
    };
    final json = id == null
        ? await _api.post('/v1/job-applications', data: data)
        : await _api.put('/v1/job-applications/$id', data: data);
    return JobApplication.fromJson(_map(json));
  }

  Future<void> delete(int id) => _api.delete('/v1/job-applications/$id');

  /// Les 100 derniers événements, du plus récent au plus ancien.
  Future<List<JobApplicationEvent>> events(int id) async {
    final json = await _api.get('/v1/job-applications/$id/events') as Map<String, dynamic>;
    return [
      for (final item in json['data'] as List<dynamic>? ?? const [])
        JobApplicationEvent.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Le PDF que l'entreprise téléchargera (adapté s'il l'a été). 404 sans profil métier.
  Future<Uint8List> downloadCv(int id) async => Uint8List.fromList(await _api.getBytes('/v1/job-applications/$id/cv'));

  /// Adapte le CV à l'offre avec l'IA ; 503 si l'assistance est indisponible.
  Future<JobApplication> tailorCv(int id) async =>
      JobApplication.fromJson(_map(await _api.post('/v1/job-applications/$id/cv/tailor', receiveTimeout: _aiTimeout)));

  /// Retouche le titre et le résumé du CV adapté ; le reste est gardé.
  Future<JobApplication> updateCv(int id, {String? title, String? summary}) async => JobApplication.fromJson(
    _map(await _api.put('/v1/job-applications/$id/cv', data: {'title': title, 'summary': summary})),
  );

  /// Revient au CV standard du profil métier.
  Future<JobApplication> resetCv(int id) async =>
      JobApplication.fromJson(_map(await _api.delete('/v1/job-applications/$id/cv')));

  /// Prépare la page d'après le texte d'une offre (50 caractères au moins). Rien n'est enregistré.
  Future<JobApplicationDraft> draftWithAi({required String jobPosting, required String locale}) async {
    final json = await _api.post(
      '/v1/ai/draft-job-application',
      data: {'job_posting': jobPosting.trim(), 'locale': locale},
      receiveTimeout: _aiTimeout,
    ) as Map<String, dynamic>;
    return JobApplicationDraft.fromJson(json['application'] as Map<String, dynamic>);
  }

  static Map<String, dynamic> _map(dynamic json) => json as Map<String, dynamic>;

  static String? _nullIfBlank(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
}
