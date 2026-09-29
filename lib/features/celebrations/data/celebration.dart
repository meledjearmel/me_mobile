import 'package:flutter/foundation.dart';

import '../../../core/models/translated.dart';

/// Surprise : bonne nouvelle qu'Armi, l'avatar du site, annonce au hasard aux
/// visiteurs, qui peuvent féliciter d'un clic.
@immutable
class Celebration {
  const Celebration({
    required this.id,
    required this.message,
    required this.buttonLabel,
    required this.congratulatedFor,
    required this.isActive,
    required this.startsAt,
    required this.endsAt,
    required this.weight,
    required this.chancePercent,
    required this.delaySeconds,
    required this.displaySeconds,
    required this.snoozeDays,
    required this.congratulationsCount,
  });

  factory Celebration.fromJson(Map<String, dynamic> json) => Celebration(
    id: json['id'] as int,
    message: Translated.fromJson(json['message']),
    buttonLabel: Translated.fromJson(json['button_label']),
    congratulatedFor: json['congratulated_for'] as String? ?? '',
    isActive: json['is_active'] as bool? ?? false,
    startsAt: DateTime.tryParse(json['starts_at']?.toString() ?? '')?.toLocal(),
    endsAt: DateTime.tryParse(json['ends_at']?.toString() ?? '')?.toLocal(),
    weight: json['weight'] as int? ?? 1,
    chancePercent: json['chance_percent'] as int? ?? 100,
    delaySeconds: json['delay_seconds'] as int? ?? 0,
    displaySeconds: json['display_seconds'] as int? ?? 10,
    snoozeDays: json['snooze_days'] as int? ?? 7,
    congratulationsCount: json['congratulations_count'] as int? ?? 0,
  );

  final int id;
  final Translated message;
  final Translated buttonLabel;

  /// Ce qui est célébré, adressé à Armel : sert à rédiger la notification push.
  final String congratulatedFor;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int weight;
  final int chancePercent;
  final int delaySeconds;
  final int displaySeconds;

  /// Jours pendant lesquels un visiteur qui l'a fermée ne la revoit plus (0 = dès la session suivante).
  final int snoozeDays;
  final int congratulationsCount;

  /// Active, et dans sa période de diffusion si elle en a une.
  bool get isLive {
    final now = DateTime.now();
    return isActive && (startsAt == null || !now.isBefore(startsAt!)) && (endsAt == null || now.isBefore(endsAt!));
  }

  String get statusLabel {
    if (!isActive) {
      return 'Inactive';
    }
    if (startsAt != null && DateTime.now().isBefore(startsAt!)) {
      return 'Programmée';
    }
    if (endsAt != null && !DateTime.now().isBefore(endsAt!)) {
      return 'Terminée';
    }
    return 'En ligne';
  }
}
