import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import 'congratulation.dart';

final congratulationRepositoryProvider = Provider<CongratulationRepository>(
  (ref) => CongratulationRepository(ref.watch(apiClientProvider)),
);

/// `GET /v1/congratulations` : historique en lecture seule, du plus récent au plus ancien.
class CongratulationRepository {
  const CongratulationRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Congratulation>> list({required int page, String search = '', Object? source}) async {
    final json = await _api.get(
      '/v1/congratulations',
      query: {'page': page, 'per_page': 25, 'search': search, 'source': source},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Congratulation.fromJson(item));
  }
}
