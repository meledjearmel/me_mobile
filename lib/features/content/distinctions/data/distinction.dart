import 'package:flutter/foundation.dart';

import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';

/// Ce à quoi une distinction peut être rattachée.
enum DistinctionContextType {
  experience('experience', 'Expérience'),
  education('education', 'Formation'),
  project('project', 'Projet');

  const DistinctionContextType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static DistinctionContextType? fromWire(String? value) {
    for (final type in values) {
      if (type.wireValue == value) {
        return type;
      }
    }
    return null;
  }
}

/// Prix reçu, affiché dans la carte « Distinction » de la page À propos
/// (seules les entrées publiées), avec son compteur de félicitations.
@immutable
class Distinction {
  const Distinction({
    required this.id,
    required this.title,
    required this.issuer,
    this.description = const Translated(),
    required this.awardedOn,
    this.url,
    this.contextType,
    this.contextId,
    this.contextLabel,
    this.congratulationsCount = 0,
    required this.status,
    this.draftedBy,
    required this.sortOrder,
  });

  factory Distinction.fromJson(Map<String, dynamic> json) => Distinction(
    id: json['id'] as int,
    title: Translated.fromJson(json['title']),
    issuer: json['issuer'] as String? ?? '',
    description: Translated.fromJson(json['description']),
    awardedOn: DateTime.parse(json['awarded_on'] as String),
    url: json['url'] as String?,
    contextType: DistinctionContextType.fromWire(json['context_type'] as String?),
    contextId: json['context_id'] as int?,
    contextLabel: json['context_label'] as String?,
    congratulationsCount: json['congratulations_count'] as int? ?? 0,
    status: PublicationStatus.fromWire(json['status'] as String?),
    draftedBy: json['drafted_by'] as String?,
    sortOrder: json['sort_order'] as int? ?? 0,
  );

  final int id;

  /// Le français est exigé ; l'anglais aussi, sauf en brouillon.
  final Translated title;

  /// Organisme qui l'a décernée (120 caractères au plus).
  final String issuer;

  /// Contexte facultatif, 500 caractères au plus par langue.
  final Translated description;

  /// Date de remise, aujourd'hui au plus tard.
  final DateTime awardedOn;
  final String? url;

  /// Expérience, formation ou projet de rattachement, sinon `null`.
  final DistinctionContextType? contextType;
  final int? contextId;

  /// Libellé du rattachement calculé par le serveur.
  final String? contextLabel;
  final int congratulationsCount;
  final PublicationStatus status;

  /// Client IA qui a rédigé le brouillon (« Claude Code », « Codex »…), sinon `null`.
  final String? draftedBy;
  final int sortOrder;
}
