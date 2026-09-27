import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/multipart.dart';
import '../../../core/api/paginated.dart';
import '../../../core/models/translated.dart';
import 'project.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) => ProjectRepository(ref.watch(apiClientProvider)));

/// `GET|POST|PUT|DELETE /v1/projects`, plus `DELETE .../cover` et
/// `.../gallery/{id}` (§4.3). La ressource la plus complexe : relations,
/// couverture, galerie avec suppression ciblée.
class ProjectRepository {
  const ProjectRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Project>> list({
    required int page,
    String search = '',
    String? status,
    bool? isFeatured,
    bool? isOpenSource,
  }) async {
    final json = await _api.get(
      '/v1/projects',
      query: {
        'page': page,
        'per_page': 25,
        'search': search,
        'status': status,
        'is_featured': isFeatured,
        'is_open_source': isOpenSource,
      },
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Project.fromJson(item));
  }

  Future<Project> get(int id) async => Project.fromJson(await _api.get('/v1/projects/$id') as Map<String, dynamic>);

  /// [id] = `null` : création (`POST`). Sinon modification (`_method=PUT`, §3.4).
  ///
  /// Toujours renvoyer la ressource complète (§3.5) : `domains`, `job_profiles`,
  /// `technologies` et `related_projects` absents videraient ces relations.
  Future<Project> save({
    int? id,
    required Translated title,
    required String slug,
    required Translated context,
    required Translated realization,
    required Translated result,
    required String? accentColor,
    required String? repoUrl,
    required String? demoUrl,
    required bool isFeatured,
    required bool isOpenSource,
    required ProjectStatus status,
    required int sortOrder,
    required List<int> domains,
    required List<int> jobProfiles,
    required List<int> technologies,
    required List<int> relatedProjects,
    MultipartFile? cover,
    List<MultipartFile> gallery = const [],
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = buildFormData({
      'title': title,
      'slug': slug,
      'context': context,
      'realization': realization,
      'result': result,
      'accent_color': accentColor,
      'repo_url': repoUrl,
      'demo_url': demoUrl,
      'is_featured': isFeatured,
      'is_open_source': isOpenSource,
      'status': status.wireValue,
      'sort_order': sortOrder,
      'domains': domains,
      'job_profiles': jobProfiles,
      'technologies': technologies,
      'related_projects': relatedProjects,
      if (cover != null) 'cover': cover,
      if (gallery.isNotEmpty) 'gallery': gallery,
    }, method: id == null ? null : 'PUT');

    final path = id == null ? '/v1/projects' : '/v1/projects/$id';
    final json = await _api.upload(path, form, onProgress: onProgress);
    return Project.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/projects/$id');

  Future<Project> deleteCover(int id) async =>
      Project.fromJson(await _api.delete('/v1/projects/$id/cover') as Map<String, dynamic>);

  Future<Project> deleteGalleryImage(int id, String imageId) async =>
      Project.fromJson(await _api.delete('/v1/projects/$id/gallery/$imageId') as Map<String, dynamic>);
}
