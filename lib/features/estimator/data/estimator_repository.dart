import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import '../../../core/models/translated.dart';
import 'estimator.dart';

final estimatorRepositoryProvider = Provider<EstimatorRepository>(
  (ref) => EstimatorRepository(ref.watch(apiClientProvider)),
);

/// Réglages, grilles tarifaires et éléments chargés en entier : l'estimateur en
/// compte quelques dizaines au plus. À invalider après chaque modification.
final estimatorSettingsProvider = FutureProvider.autoDispose<EstimatorSettings>(
  (ref) => ref.watch(estimatorRepositoryProvider).settings(),
);

final estimatorRatesProvider = FutureProvider.autoDispose<List<EstimatorRate>>(
  (ref) => ref.watch(estimatorRepositoryProvider).rates(),
);

final estimatorItemsProvider = FutureProvider.autoDispose<List<EstimatorItem>>(
  (ref) => ref.watch(estimatorRepositoryProvider).items(),
);

/// `/v1/estimator-settings`, `/v1/estimator-rates`, `/v1/estimator-items`,
/// `/v1/estimator-configuration` et les aides IA de l'estimateur.
class EstimatorRepository {
  const EstimatorRepository(this._api);

  final ApiClient _api;

  static const _aiTimeout = Duration(seconds: 90);

  Future<EstimatorSettings> settings() async =>
      EstimatorSettings.fromJson(await _api.get('/v1/estimator-settings') as Map<String, dynamic>);

  Future<EstimatorSettings> saveSettings(EstimatorSettings settings) async => EstimatorSettings.fromJson(
    await _api.put('/v1/estimator-settings', data: settings.toJson()) as Map<String, dynamic>,
  );

  Future<List<EstimatorRate>> rates() => _all('/v1/estimator-rates', EstimatorRate.fromJson);

  Future<EstimatorRate> saveRate({
    int? id,
    required Translated name,
    required HourlyRates hourlyRates,
    int sortOrder = 0,
  }) async {
    final data = {'name': name.toJson(), 'hourly_rates': hourlyRatesToJson(hourlyRates), 'sort_order': sortOrder};
    final json = id == null
        ? await _api.post('/v1/estimator-rates', data: data)
        : await _api.put('/v1/estimator-rates/$id', data: data);
    return EstimatorRate.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteRate(int id) => _api.delete('/v1/estimator-rates/$id');

  /// Types de projet d'abord, puis options, chacun dans son ordre d'affichage.
  Future<List<EstimatorItem>> items() => _all('/v1/estimator-items', EstimatorItem.fromJson);

  Future<EstimatorItem> saveItem({
    int? id,
    required EstimatorItemKind kind,
    required Translated name,
    required Translated description,
    int? hoursMin,
    int? hoursMax,
    EstimatorPricing? pricing,
    int? percent,
    EstimatorBilling? billing,
    List<int> projectTypeIds = const [],
    int? rateId,
    HourlyRates hourlyRates = const {},
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final isFeature = kind == EstimatorItemKind.feature;
    final isPercent = isFeature && pricing == EstimatorPricing.percent;
    final data = {
      'kind': kind.wireValue,
      'name': name.toJson(),
      'description': description.toJson(),
      'hours_min': isPercent ? null : hoursMin,
      'hours_max': isPercent ? null : hoursMax,
      'pricing': isFeature ? pricing?.wireValue : null,
      'percent': isPercent ? percent : null,
      'billing': isFeature ? null : billing?.wireValue,
      'project_type_ids': isFeature ? projectTypeIds : <int>[],
      'estimator_rate_id': rateId,
      'hourly_rates': hourlyRates.isEmpty ? null : hourlyRatesToJson(hourlyRates),
      'is_active': isActive,
      'sort_order': sortOrder,
    };
    final json = id == null
        ? await _api.post('/v1/estimator-items', data: data)
        : await _api.put('/v1/estimator-items/$id', data: data);
    return EstimatorItem.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteItem(int id) => _api.delete('/v1/estimator-items/$id');

  /// L'IA chiffre un élément d'après son nom et des précisions. Rien n'est enregistré.
  Future<EstimatorItemSuggestion> suggestItem({
    required EstimatorItemKind kind,
    required String name,
    String? notes,
  }) async {
    final json = await _api.post(
      '/v1/ai/suggest-estimator-item',
      data: {
        'kind': kind.wireValue,
        'name': name.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
      receiveTimeout: _aiTimeout,
    ) as Map<String, dynamic>;
    return EstimatorItemSuggestion.fromJson(json['item'] as Map<String, dynamic>);
  }

  /// L'IA propose une grille complète d'après la description de l'activité. Rien n'est enregistré.
  Future<EstimatorGridProposal> proposeGrid(String brief) async {
    final json = await _api.post(
      '/v1/ai/propose-estimator-grid',
      data: {'brief': brief.trim()},
      receiveTimeout: _aiTimeout,
    ) as Map<String, dynamic>;
    return EstimatorGridProposal.fromJson(json['proposal'] as Map<String, dynamic>);
  }

  /// Applique une grille d'un coup, en une transaction. À n'appeler qu'après confirmation.
  Future<EstimatorConfigurationResult> applyConfiguration(EstimatorGridProposal proposal) async =>
      EstimatorConfigurationResult.fromJson(
        await _api.post('/v1/estimator-configuration', data: proposal.toConfiguration()) as Map<String, dynamic>,
      );

  Future<List<T>> _all<T>(String path, T Function(Map<String, dynamic>) fromJson) async {
    final items = <T>[];
    for (var page = 1; ; page++) {
      final result = Paginated.fromJson(
        await _api.get(path, query: {'page': page, 'per_page': 50}) as Map<String, dynamic>,
        fromJson,
      );
      items.addAll(result.items);
      if (!result.hasMore) {
        return items;
      }
    }
  }
}
