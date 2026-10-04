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

  /// [days] : `7`, `30`, `90`, `365` ou `all` ; [type] (`post` ou `project`) ne
  /// filtre que `visits.top_content`.
  Future<Dashboard> get({String days = '30', String? type}) async =>
      Dashboard.fromJson(await _api.get('/v1/dashboard', query: {'days': days, 'type': type}) as Map<String, dynamic>);
}

/// Un seul appel qui alimente l'accueil et les badges des onglets (§4.1).
/// Rafraîchi manuellement (tirer pour rafraîchir) et automatiquement au retour
/// au premier plan ou à la réception d'une notification push (voir
/// `app.dart` et `push_service.dart`).
final dashboardProvider = FutureProvider<Dashboard>((ref) => ref.watch(dashboardRepositoryProvider).get());

/// Période et type de contenu choisis dans l'écran Statistiques.
final statisticsQueryProvider = StateProvider<({String days, String? type})>((ref) => (days: '30', type: null));

/// Tableau de bord filtré pour l'écran Statistiques ; l'accueil garde
/// [dashboardProvider] (30 jours). Un changement de filtre garde l'affichage
/// précédent pendant le rechargement.
final statisticsProvider = FutureProvider.autoDispose<Dashboard>((ref) {
  final query = ref.watch(statisticsQueryProvider);
  return ref.watch(dashboardRepositoryProvider).get(days: query.days, type: query.type);
});
