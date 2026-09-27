import 'package:flutter/foundation.dart';

import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';

@immutable
class Domain {
  const Domain({
    required this.id,
    required this.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.sortOrder,
    required this.status,
  });

  factory Domain.fromJson(Map<String, dynamic> json) => Domain(
        id: json['id'] as int,
        key: json['key'] as String,
        label: Translated.fromJson(json['label']),
        color: json['color'] as String? ?? '#999999',
        icon: json['icon'] as String? ?? '',
        sortOrder: json['sort_order'] as int? ?? 0,
        status: PublicationStatus.fromWire(json['status'] as String?),
      );

  final int id;
  final String key;
  final Translated label;
  final String color;
  final String icon;
  final int sortOrder;
  final PublicationStatus status;
}
