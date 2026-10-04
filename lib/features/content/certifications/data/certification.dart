import 'package:flutter/foundation.dart';

import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';

enum CertificationKind {
  certification('certification', 'Certification'),
  course('course', 'Formation');

  const CertificationKind(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static CertificationKind fromWire(String? value) => value == course.wireValue ? course : certification;
}

/// Certification ou formation courte, affichée sur la page publique
/// (seules les entrées publiées).
@immutable
class Certification {
  const Certification({
    required this.id,
    required this.kind,
    required this.name,
    required this.issuer,
    required this.issuedOn,
    required this.expiresOn,
    required this.credentialId,
    required this.credentialUrl,
    required this.badgeUrl,
    required this.status,
    required this.sortOrder,
  });

  factory Certification.fromJson(Map<String, dynamic> json) => Certification(
    id: json['id'] as int,
    kind: CertificationKind.fromWire(json['kind'] as String?),
    name: Translated.fromJson(json['name']),
    issuer: json['issuer'] as String? ?? '',
    issuedOn: DateTime.parse(json['issued_on'] as String),
    expiresOn: json['expires_on'] == null ? null : DateTime.tryParse(json['expires_on'] as String),
    credentialId: json['credential_id'] as String?,
    credentialUrl: json['credential_url'] as String?,
    badgeUrl: json['badge_url'] as String?,
    status: PublicationStatus.fromWire(json['status'] as String?),
    sortOrder: json['sort_order'] as int? ?? 0,
  );

  final int id;
  final CertificationKind kind;

  /// 160 caractères au plus, les deux langues exigées.
  final Translated name;

  /// Organisme (AWS, Google, Udemy…).
  final String issuer;

  /// Date d'obtention, aujourd'hui au plus tard.
  final DateTime issuedOn;
  final DateTime? expiresOn;
  final String? credentialId;

  /// Lien de vérification.
  final String? credentialUrl;
  final String? badgeUrl;
  final PublicationStatus status;
  final int sortOrder;

  bool get isExpired => expiresOn != null && expiresOn!.isBefore(DateTime.now());
}
