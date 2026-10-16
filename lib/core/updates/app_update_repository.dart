import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_providers.dart';
import 'app_release.dart';

final appUpdateRepositoryProvider = Provider<AppUpdateRepository>(
  (ref) => AppUpdateRepository(ref.watch(apiClientProvider)),
);

class AppUpdateRepository {
  const AppUpdateRepository(this._api);

  final ApiClient _api;

  /// Dernière version publiée, ou `null` si aucune (réponse 204).
  Future<AppRelease?> latest() async {
    final body = await _api.get('/v1/app/latest');
    if (body is! Map || body['data'] is! Map) {
      return null;
    }
    return AppRelease.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }
}
