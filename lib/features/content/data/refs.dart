import 'package:flutter/foundation.dart';

import '../../../core/models/translated.dart';

/// Références légères utilisées dans les sélecteurs de relations (§4.4) :
/// domaines, profils métier, technologies, projets liés. Les écrans complets
/// de gestion de ces ressources arrivent à l'étape 6.
@immutable
class DomainRef {
  const DomainRef({required this.id, required this.label, required this.color});

  factory DomainRef.fromJson(Map<String, dynamic> json) => DomainRef(
        id: json['id'] as int,
        label: Translated.fromJson(json['label']),
        color: json['color'] as String? ?? '#999999',
      );

  final int id;
  final Translated label;
  final String color;
}

@immutable
class JobProfileFullRef {
  const JobProfileFullRef({required this.id, required this.label});

  factory JobProfileFullRef.fromJson(Map<String, dynamic> json) =>
      JobProfileFullRef(id: json['id'] as int, label: Translated.fromJson(json['label']));

  final int id;
  final Translated label;
}

@immutable
class TechnologyRef {
  const TechnologyRef({required this.id, required this.name, required this.category});

  factory TechnologyRef.fromJson(Map<String, dynamic> json) => TechnologyRef(
        id: json['id'] as int,
        name: json['name'] as String,
        category: json['category'] as String? ?? '',
      );

  final int id;
  final String name;
  final String category;
}

@immutable
class ProjectLiteRef {
  const ProjectLiteRef({required this.id, required this.title});

  factory ProjectLiteRef.fromJson(Map<String, dynamic> json) =>
      ProjectLiteRef(id: json['id'] as int, title: Translated.fromJson(json['title']));

  final int id;
  final Translated title;
}
