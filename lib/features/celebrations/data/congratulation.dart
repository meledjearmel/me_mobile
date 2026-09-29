import 'package:flutter/foundation.dart';

/// D'où vient une félicitation : la carte « Distinction » de la page À propos,
/// ou une surprise d'Armi.
enum CongratulationSource {
  about('about', 'Page À propos'),
  surprise('surprise', 'Surprise');

  const CongratulationSource(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static CongratulationSource fromWire(String? value) => value == about.wireValue ? about : surprise;
}

/// Un envoi de félicitations depuis le site (les clics d'un visiteur sont regroupés).
@immutable
class Congratulation {
  const Congratulation({
    required this.id,
    required this.source,
    required this.celebrationId,
    required this.reason,
    required this.count,
    required this.locale,
    required this.createdAt,
  });

  factory Congratulation.fromJson(Map<String, dynamic> json) => Congratulation(
    id: json['id'] as int,
    source: CongratulationSource.fromWire(json['source']?.toString()),
    celebrationId: json['celebration_id'] as int?,
    reason: json['reason'] as String? ?? '',
    count: json['count'] as int? ?? 1,
    locale: json['locale'] as String?,
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal(),
  );

  final int id;
  final CongratulationSource source;

  /// `null` pour la page À propos, ou si la surprise a été supprimée.
  final int? celebrationId;

  /// Motif lisible, figé au moment du clic.
  final String reason;

  /// Nombre de clics regroupés dans cet envoi.
  final int count;
  final String? locale;
  final DateTime? createdAt;
}
