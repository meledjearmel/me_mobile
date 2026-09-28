import 'package:flutter/foundation.dart';

import '../../../../core/models/translated.dart';
import 'technology_category.dart';

@immutable
class Technology {
  const Technology({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.category,
    required this.icon,
    this.iconLightUrl,
    this.iconDarkUrl,
    this.description = const Translated(),
  });

  factory Technology.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    return Technology(
      id: json['id'] as int,
      name: json['name'] as String,
      categoryId: json['category_id'] as int? ?? (category is Map ? category['id'] as int? : null),
      category: category is Map<String, dynamic> ? TechnologyCategory.fromJson(category) : null,
      icon: json['icon'] as String?,
      iconLightUrl: json['icon_light_url'] as String?,
      iconDarkUrl: json['icon_dark_url'] as String?,
      description: Translated.fromJson(json['description']),
    );
  }

  final int id;
  final String name;
  final int? categoryId;
  final TechnologyCategory? category;

  /// Slug du logo dans la bibliothèque (`null` : pas de logo).
  final String? icon;
  final String? iconLightUrl;
  final String? iconDarkUrl;

  /// Infobulle affichée au survol du logo sur la page publique (150 caractères max).
  final Translated description;
}
