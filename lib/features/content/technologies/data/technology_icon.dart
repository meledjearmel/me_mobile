import 'package:flutter/foundation.dart';

/// Thème auquel s'applique un logo envoyé ou importé. `null` côté API : le logo
/// sert aux deux thèmes (ou se décline seul s'il est monochrome).
enum LogoTheme {
  both(null, 'Les deux'),
  light('light', 'Clair'),
  dark('dark', 'Sombre');

  const LogoTheme(this.wireValue, this.label);

  final String? wireValue;
  final String label;
}

/// Un logo de la bibliothèque : son `slug` se passe dans le champ `icon` d'une
/// technologie. Les deux URL sont identiques si le logo n'a pas de variante.
@immutable
class TechnologyIcon {
  const TechnologyIcon({required this.slug, required this.lightUrl, required this.darkUrl});

  factory TechnologyIcon.fromJson(Map<String, dynamic> json) => TechnologyIcon(
        slug: json['slug'] as String,
        lightUrl: json['light_url'] as String?,
        darkUrl: json['dark_url'] as String?,
      );

  final String slug;
  final String? lightUrl;
  final String? darkUrl;
}

/// Résultat de recherche dans le catalogue public Iconify.
@immutable
class IconSearchResult {
  const IconSearchResult({required this.id, required this.name, required this.collection, required this.previewUrl});

  factory IconSearchResult.fromJson(Map<String, dynamic> json) => IconSearchResult(
        id: json['id'] as String,
        name: json['name'] as String,
        collection: json['collection'] as String,
        previewUrl: json['preview_url'] as String,
      );

  /// Identifiant à passer à l'import (`logos:flutter`).
  final String id;
  final String name;
  final String collection;
  final String previewUrl;
}
