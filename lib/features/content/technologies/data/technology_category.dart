import 'package:flutter/foundation.dart';

import '../../../../core/models/translated.dart';

/// Catégorie de technologie, gérée côté API (`/v1/technology-categories`).
@immutable
class TechnologyCategory {
  const TechnologyCategory({required this.id, required this.key, required this.label, required this.sortOrder});

  factory TechnologyCategory.fromJson(Map<String, dynamic> json) => TechnologyCategory(
        id: json['id'] as int,
        key: json['key'] as String,
        label: Translated.fromJson(json['label']),
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  final int id;
  final String key;
  final Translated label;
  final int sortOrder;
}
