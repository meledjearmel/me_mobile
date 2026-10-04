import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import 'availability.dart';

final availabilityRepositoryProvider = Provider<AvailabilityRepository>(
  (ref) => AvailabilityRepository(ref.watch(apiClientProvider)),
);

final availabilityProvider = FutureProvider.autoDispose<Availability>(
  (ref) => ref.watch(availabilityRepositoryProvider).get(),
);

/// `GET /v1/availability`, `POST …/rules|blocked-periods`, `DELETE …/{schedule}`.
/// Les ajouts renvoient l'agenda complet. Heures d'Abidjan (UTC).
class AvailabilityRepository {
  const AvailabilityRepository(this._api);

  final ApiClient _api;

  static final _date = DateFormat('yyyy-MM-dd');

  Future<Availability> get() async => Availability.fromJson(await _api.get('/v1/availability') as Map<String, dynamic>);

  /// [start] et [end] au format `HH:mm`, [end] après [start].
  Future<Availability> addRule({required List<Weekday> days, required String start, required String end}) async =>
      Availability.fromJson(
        await _api.post(
          '/v1/availability/rules',
          data: {
            'days': [for (final day in days) day.wireValue],
            'start': start,
            'end': end,
          },
        ) as Map<String, dynamic>,
      );

  /// Dates incluses, [from] à partir d'aujourd'hui.
  Future<Availability> addBlockedPeriod({required DateTime from, required DateTime to, String? label}) async =>
      Availability.fromJson(
        await _api.post(
          '/v1/availability/blocked-periods',
          data: {'from': _date.format(from), 'to': _date.format(to), 'label': label},
        ) as Map<String, dynamic>,
      );

  /// Retire une plage ou une période bloquée (même identifiant d'agenda).
  Future<void> delete(int id) => _api.delete('/v1/availability/$id');
}
