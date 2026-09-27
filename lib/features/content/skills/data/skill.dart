import 'package:flutter/foundation.dart';

import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';
import '../../data/refs.dart';

@immutable
class Skill {
  const Skill({
    required this.id,
    required this.domainId,
    required this.domain,
    required this.name,
    required this.description,
    required this.details,
    required this.technologies,
    required this.sortOrder,
    required this.status,
  });

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
        id: json['id'] as int,
        domainId: json['domain_id'] as int,
        domain: json['domain'] == null ? null : DomainRef.fromJson(json['domain'] as Map<String, dynamic>),
        name: Translated.fromJson(json['name']),
        description: Translated.fromJson(json['description']),
        details: Translated.fromJson(json['details']),
        technologies: [
          for (final item in (json['technologies'] as List<dynamic>? ?? const []))
            TechnologyRef.fromJson(item as Map<String, dynamic>),
        ],
        sortOrder: json['sort_order'] as int? ?? 0,
        status: PublicationStatus.fromWire(json['status'] as String?),
      );

  final int id;
  final int domainId;
  final DomainRef? domain;
  final Translated name;
  final Translated description;
  final Translated details;

  /// Ordre conservé (§4.3) : reflète l'ordre choisi dans le formulaire.
  final List<TechnologyRef> technologies;
  final int sortOrder;
  final PublicationStatus status;
}
