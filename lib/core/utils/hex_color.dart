import 'package:flutter/material.dart';

/// Parse une couleur `#RRGGBB` (domaines, projets). Retombe sur un gris neutre
/// si la valeur est absente ou mal formée plutôt que de planter l'écran.
Color parseHexColor(String hex, {Color fallback = const Color(0xFF9E9E9E)}) {
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
  return value == null ? fallback : Color(value);
}
