import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_providers.dart';

/// `POST/DELETE /v1/push-tokens` : associe ou retire le jeton FCM de cet
/// appareil au compte connecté. Android uniquement pour cette app.
final pushTokenRepositoryProvider = Provider<PushTokenRepository>(
  (ref) => PushTokenRepository(ref.watch(apiClientProvider)),
);

class PushTokenRepository {
  const PushTokenRepository(this._api);

  final ApiClient _api;

  /// Idempotent côté serveur : renvoyer un jeton déjà connu le réattribue
  /// simplement au compte courant (utile après une réinstallation).
  Future<void> register(String token) => _api.post('/v1/push-tokens', data: {'token': token, 'platform': 'android'});

  Future<void> unregister(String token) => _api.delete('/v1/push-tokens', data: {'token': token});
}
