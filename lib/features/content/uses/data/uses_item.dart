import 'package:flutter/material.dart';

import '../../../../core/models/publication_status.dart';
import '../../../../core/models/translated.dart';

/// Rubriques de la page « Uses », dans leur ordre d'affichage.
enum UsesCategory {
  hardware('hardware', 'Matériel', Icons.laptop_mac_outlined),
  development('development', 'Développement', Icons.code_rounded),
  apps('apps', 'Applications', Icons.apps_rounded),
  services('services', 'Services', Icons.cloud_outlined);

  const UsesCategory(this.wireValue, this.label, this.icon);

  final String wireValue;
  final String label;
  final IconData icon;

  static UsesCategory fromWire(String? value) =>
      values.firstWhere((c) => c.wireValue == value, orElse: () => UsesCategory.development);
}

/// Élément de la page « Uses » : matériel, outil, application ou service.
@immutable
class UsesItem {
  const UsesItem({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.url,
    required this.status,
    required this.sortOrder,
  });

  factory UsesItem.fromJson(Map<String, dynamic> json) => UsesItem(
    id: json['id'] as int,
    category: UsesCategory.fromWire(json['category'] as String?),
    name: json['name'] as String,
    description: Translated.fromJson(json['description']),
    url: json['url'] as String?,
    status: PublicationStatus.fromWire(json['status'] as String?),
    sortOrder: json['sort_order'] as int? ?? 0,
  );

  final int id;
  final UsesCategory category;
  final String name;

  /// 300 caractères au plus par langue, facultative.
  final Translated description;

  /// Lien officiel (facultatif).
  final String? url;
  final PublicationStatus status;
  final int sortOrder;
}
