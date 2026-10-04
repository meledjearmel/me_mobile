import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import 'site_settings.dart';

final siteSettingsRepositoryProvider = Provider<SiteSettingsRepository>(
  (ref) => SiteSettingsRepository(ref.watch(apiClientProvider)),
);

final siteSettingsProvider = FutureProvider<SiteSettings>((ref) => ref.watch(siteSettingsRepositoryProvider).get());

/// `GET|PATCH /v1/site-settings`. Chaque champ est facultatif : ceux qui ne
/// sont pas envoyés gardent leur valeur.
class SiteSettingsRepository {
  const SiteSettingsRepository(this._api);

  final ApiClient _api;

  Future<SiteSettings> get() async =>
      SiteSettings.fromJson(await _api.get('/v1/site-settings') as Map<String, dynamic>);

  Future<SiteSettings> update(SiteSettings settings) => patch(settings.toJson());

  /// Modifie seulement les champs de [fields] (ex. le délai des félicitations).
  Future<SiteSettings> patch(Map<String, Object?> fields) async =>
      SiteSettings.fromJson(await _api.patch('/v1/site-settings', data: fields) as Map<String, dynamic>);
}
