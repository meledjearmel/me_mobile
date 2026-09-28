import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_providers.dart';
import '../../../../core/api/multipart.dart';
import 'technology_icon.dart';

final technologyIconRepositoryProvider = Provider<TechnologyIconRepository>(
  (ref) => TechnologyIconRepository(ref.watch(apiClientProvider)),
);

/// Bibliothèque de logos : `GET|POST /v1/technology-icons`, `GET .../search`,
/// `POST .../upload` (SVG en multipart, 200 Ko max).
class TechnologyIconRepository {
  const TechnologyIconRepository(this._api);

  final ApiClient _api;

  /// Slug attendu par l'API : minuscules et tirets, sans suffixe `-light` / `-dark`
  /// (il serait pris pour une variante de thème), 60 caractères au plus.
  static final slugPattern = RegExp(r'^(?!.*-(light|dark)$)[a-z0-9]+(-[a-z0-9]+)*$');
  static const maxSlugLength = 60;
  static const maxUploadBytes = 200 * 1024;

  static bool isValidSlug(String slug) => slug.length <= maxSlugLength && slugPattern.hasMatch(slug);

  Future<List<TechnologyIcon>> list() async {
    final json = await _api.get('/v1/technology-icons') as Map<String, dynamic>;
    return [for (final item in json['data'] as List<dynamic>) TechnologyIcon.fromJson(item as Map<String, dynamic>)];
  }

  Future<List<IconSearchResult>> search(String query) async {
    final json = await _api.get('/v1/technology-icons/search', query: {'q': query}) as Map<String, dynamic>;
    return [for (final item in json['data'] as List<dynamic>) IconSearchResult.fromJson(item as Map<String, dynamic>)];
  }

  /// Télécharge un logo du catalogue dans la bibliothèque sous le nom [slug].
  Future<void> import({required String icon, required String slug, LogoTheme theme = LogoTheme.both}) =>
      _api.post('/v1/technology-icons', data: {'icon': icon, 'slug': slug, 'theme': theme.wireValue});

  Future<void> upload({
    required String slug,
    required MultipartFile file,
    LogoTheme theme = LogoTheme.both,
    void Function(int sent, int total)? onProgress,
  }) =>
      _api.upload(
        '/v1/technology-icons/upload',
        buildFormData({'slug': slug, 'theme': theme.wireValue, 'file': file}),
        onProgress: onProgress,
      );
}
