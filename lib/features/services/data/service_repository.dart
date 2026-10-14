import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import '../../../core/models/publication_status.dart';
import '../../../core/models/translated.dart';
import '../../estimator/data/estimator.dart';
import 'service.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) => ServiceRepository(ref.watch(apiClientProvider)));

/// `GET|POST|PUT|DELETE /v1/services` et `POST /v1/ai/draft-service`.
class ServiceRepository {
  const ServiceRepository(this._api);

  final ApiClient _api;

  /// Dans l'ordre de la page « Services ».
  Future<Paginated<Service>> list({required int page, String search = '', String? status}) async {
    final json = await _api.get(
      '/v1/services',
      query: {'page': page, 'per_page': 25, 'search': search, 'status': status},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, Service.fromJson);
  }

  Future<Service> get(int id) async => Service.fromJson(await _api.get('/v1/services/$id') as Map<String, dynamic>);

  /// Seul le champ utile au [priceMode] est envoyé : le type de projet
  /// (`estimator`) ou les montants (`manual`).
  Future<Service> save({
    int? id,
    required String slug,
    required Translated title,
    required Translated tagline,
    required Translated description,
    required Translated includes,
    required ServicePriceMode priceMode,
    int? estimatorItemId,
    Map<String, int> manualPrices = const {},
    List<int> projectIds = const [],
    required PublicationStatus status,
    int sortOrder = 0,
  }) async {
    final data = {
      'slug': slug,
      'title': {'fr': title.fr, 'en': _nullIfBlank(title.en)},
      'tagline': _translated(tagline),
      'description': _translated(description),
      'includes': _translated(includes),
      'price_mode': priceMode.wireValue,
      'estimator_item_id': priceMode == ServicePriceMode.estimator ? estimatorItemId : null,
      'manual_prices': priceMode == ServicePriceMode.manual ? hourlyRatesToJson(manualPrices) : null,
      'project_ids': projectIds,
      'status': status.wireValue,
      'sort_order': sortOrder,
    };
    final json = id == null
        ? await _api.post('/v1/services', data: data)
        : await _api.put('/v1/services/$id', data: data);
    return Service.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/services/$id');

  /// L'IA rédige le texte de l'offre en français d'après des notes (10 caractères au moins).
  Future<ServiceDraft> draftWithAi(String notes) async {
    final json = await _api.post(
      '/v1/ai/draft-service',
      data: {'notes': notes.trim()},
      receiveTimeout: const Duration(seconds: 90),
    ) as Map<String, dynamic>;
    return ServiceDraft.fromJson(json['service'] as Map<String, dynamic>);
  }

  static Map<String, String?> _translated(Translated value) => {
    'fr': _nullIfBlank(value.fr),
    'en': _nullIfBlank(value.en),
  };

  static String? _nullIfBlank(String value) => value.trim().isEmpty ? null : value;
}
