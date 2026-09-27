import 'package:flutter/foundation.dart';

enum TechnologyCategory {
  langages('langages', 'Langages'),
  frameworks('frameworks', 'Frameworks'),
  donnees('donnees', 'Données'),
  qualite('qualite', 'Qualité'),
  securite('securite', 'Sécurité'),
  infra('infra', 'Infra'),
  ia('ia', 'IA'),
  design('design', 'Design'),
  cms('cms', 'CMS');

  const TechnologyCategory(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static TechnologyCategory fromWire(String? value) =>
      values.firstWhere((c) => c.wireValue == value, orElse: () => TechnologyCategory.langages);
}

@immutable
class Technology {
  const Technology({required this.id, required this.name, required this.category, required this.icon});

  factory Technology.fromJson(Map<String, dynamic> json) => Technology(
        id: json['id'] as int,
        name: json['name'] as String,
        category: TechnologyCategory.fromWire(json['category'] as String?),
        icon: json['icon'] as String?,
      );

  final int id;
  final String name;
  final TechnologyCategory category;
  final String? icon;
}
