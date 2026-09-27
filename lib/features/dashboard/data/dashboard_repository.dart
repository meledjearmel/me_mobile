import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import 'dashboard.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(apiClientProvider)),
);

class DashboardRepository {
  const DashboardRepository(this._api);

  final ApiClient _api;

  Future<Dashboard> get() async => Dashboard.fromJson(await _api.get('/v1/dashboard') as Map<String, dynamic>);
}

/// Un seul appel qui alimente l'accueil et les badges des onglets (§4.1).
/// Rafraîchi manuellement (tirer pour rafraîchir) et automatiquement au retour
/// au premier plan ou à la réception d'une notification push (voir
/// `app.dart` et `push_service.dart`).
final dashboardProvider = FutureProvider<Dashboard>((ref) => ref.watch(dashboardRepositoryProvider).get());
