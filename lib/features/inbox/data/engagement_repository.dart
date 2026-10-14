import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import 'engagement.dart';

final engagementRepositoryProvider = Provider<EngagementRepository>(
  (ref) => EngagementRepository(ref.watch(apiClientProvider)),
);

/// `GET|PUT|DELETE /v1/engagements` — pas de création (§4.2).
class EngagementRepository {
  const EngagementRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Engagement>> list({
    required int page,
    String search = '',
    String? type,
    String? status,
  }) async {
    final json = await _api.get(
      '/v1/engagements',
      query: {'page': page, 'per_page': 25, 'search': search, 'type': type, 'status': status},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Engagement.fromJson(item));
  }

  Future<Engagement> get(int id) async =>
      Engagement.fromJson(await _api.get('/v1/engagements/$id') as Map<String, dynamic>);

  Future<Engagement> updateStatus(int id, EngagementStatus status) async => Engagement.fromJson(
        await _api.put('/v1/engagements/$id', data: {'status': status.wireValue}) as Map<String, dynamic>,
      );

  Future<void> delete(int id) => _api.delete('/v1/engagements/$id');

  /// `PUT /v1/engagements/{id}/outcome` : [outcome] `null` efface l'issue. Le
  /// montant (hors taxes) et sa devise ne valent que pour une demande gagnée.
  /// Une issue range aussi la demande parmi les traitées.
  Future<Engagement> setOutcome(int id, EngagementOutcome? outcome, {int? amount, String? currency}) async {
    final won = outcome == EngagementOutcome.won;
    return Engagement.fromJson(
      await _api.put(
            '/v1/engagements/$id/outcome',
            data: {
              'outcome': outcome?.wireValue,
              'outcome_amount': won ? amount : null,
              'outcome_currency': won ? currency : null,
            },
          )
          as Map<String, dynamic>,
    );
  }

  /// `POST /v1/ai/engagements/{id}/analyze` : relance l'analyse IA ; 503 si
  /// l'assistance est indisponible.
  Future<Engagement> analyze(int id) async => Engagement.fromJson(
        await _api.post('/v1/ai/engagements/$id/analyze', receiveTimeout: const Duration(seconds: 90))
            as Map<String, dynamic>,
      );
}
