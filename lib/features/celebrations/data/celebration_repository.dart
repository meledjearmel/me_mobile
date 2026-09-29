import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import '../../../core/models/translated.dart';
import '../../../core/utils/date_only.dart';
import 'celebration.dart';

final celebrationRepositoryProvider = Provider<CelebrationRepository>(
  (ref) => CelebrationRepository(ref.watch(apiClientProvider)),
);

/// `GET|POST|PUT|DELETE /v1/celebrations`.
class CelebrationRepository {
  const CelebrationRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Celebration>> list({required int page, String search = ''}) async {
    final json = await _api.get(
      '/v1/celebrations',
      query: {'page': page, 'per_page': 25, 'search': search},
    ) as Map<String, dynamic>;
    return Paginated.fromJson(json, (item) => Celebration.fromJson(item));
  }

  Future<Celebration> get(int id) async =>
      Celebration.fromJson(await _api.get('/v1/celebrations/$id') as Map<String, dynamic>);

  /// Les dates sont choisies au jour près : la surprise démarre au début du
  /// jour de début et s'arrête à la fin du jour de fin.
  Future<Celebration> save({
    int? id,
    required Translated message,
    required Translated buttonLabel,
    required String congratulatedFor,
    required bool isActive,
    required DateTime? startsAt,
    required DateTime? endsAt,
    required int weight,
    required int chancePercent,
    required int delaySeconds,
    required int displaySeconds,
    required int snoozeDays,
  }) async {
    final data = {
      'message': message.toJson(),
      'button_label': buttonLabel.toJson(),
      'congratulated_for': congratulatedFor,
      'is_active': isActive,
      'starts_at': startsAt == null ? null : '${formatDateOnly(startsAt)} 00:00:00',
      'ends_at': endsAt == null ? null : '${formatDateOnly(endsAt)} 23:59:59',
      'weight': weight,
      'chance_percent': chancePercent,
      'delay_seconds': delaySeconds,
      'display_seconds': displaySeconds,
      'snooze_days': snoozeDays,
    };
    final json = id == null
        ? await _api.post('/v1/celebrations', data: data)
        : await _api.put('/v1/celebrations/$id', data: data);
    return Celebration.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('/v1/celebrations/$id');
}
