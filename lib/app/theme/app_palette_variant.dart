import 'package:flutter/material.dart';

/// Les palettes proposées dans Compte → Apparence. Chacune a une version
/// claire et une version sombre ; le choix est mémorisé sur l'appareil.
enum AppPaletteVariant {
  goldGraphite('Or & graphite'),
  sageAmber('Sauge & ambre'),
  limeCharcoal('Lime & charbon'),
  skyAmber('Ciel & ambre');

  const AppPaletteVariant(this.label);

  final String label;

  static const fallback = AppPaletteVariant.goldGraphite;

  static AppPaletteVariant fromName(String? name) => values.firstWhere((v) => v.name == name, orElse: () => fallback);

  PaletteTokens tokens(Brightness brightness) => switch ((this, brightness)) {
    (goldGraphite, Brightness.light) => const PaletteTokens(
      bg: Color(0xFFF4F3EF),
      card: Color(0xFFFFFFFF),
      soft: Color(0xFFECEAE4),
      softHigh: Color(0xFFE2DFD8),
      fg: Color(0xFF111114),
      muted: Color(0xFF6E6C66),
      outline: Color(0xFFE4E1DA),
      accent: Color(0xFFFFD23F),
      onAccent: Color(0xFF111114),
      second: Color(0xFFE3ECF7),
      onSecond: Color(0xFF2F5F95),
      ok: Color(0xFF23915F),
      nav: Color(0xFF111114),
      navIcon: Color(0xFFA9A8A3),
    ),
    (goldGraphite, Brightness.dark) => const PaletteTokens(
      bg: Color(0xFF0E0F12),
      card: Color(0xFF181A1F),
      soft: Color(0xFF22252C),
      softHigh: Color(0xFF2B2F37),
      fg: Color(0xFFF3F2EE),
      muted: Color(0xFF8E919A),
      outline: Color(0xFF262930),
      accent: Color(0xFFFFD23F),
      onAccent: Color(0xFF111114),
      second: Color(0xFF1D2A3B),
      onSecond: Color(0xFF8DB6E8),
      ok: Color(0xFF4CC38A),
      nav: Color(0xFF22252C),
      navIcon: Color(0xFF8E919A),
    ),
    (sageAmber, Brightness.light) => const PaletteTokens(
      bg: Color(0xFFF1F3EE),
      card: Color(0xFFFFFFFF),
      soft: Color(0xFFE4E9E0),
      softHigh: Color(0xFFD8DFD3),
      fg: Color(0xFF15201A),
      muted: Color(0xFF66706A),
      outline: Color(0xFFDDE3D8),
      accent: Color(0xFFF5B83D),
      onAccent: Color(0xFF1B1606),
      second: Color(0xFFDDEBE3),
      onSecond: Color(0xFF2F6B4F),
      ok: Color(0xFF2E8F62),
      nav: Color(0xFF15201A),
      navIcon: Color(0xFF9FAAA3),
    ),
    (sageAmber, Brightness.dark) => const PaletteTokens(
      bg: Color(0xFF0C120F),
      card: Color(0xFF151D18),
      soft: Color(0xFF1F2A23),
      softHigh: Color(0xFF28352D),
      fg: Color(0xFFEEF2EE),
      muted: Color(0xFF8B978F),
      outline: Color(0xFF1F2A23),
      accent: Color(0xFFF5B83D),
      onAccent: Color(0xFF1B1606),
      second: Color(0xFF1B2E24),
      onSecond: Color(0xFF8FCBAA),
      ok: Color(0xFF58C790),
      nav: Color(0xFF1F2A23),
      navIcon: Color(0xFF8B978F),
    ),
    (limeCharcoal, Brightness.light) => const PaletteTokens(
      bg: Color(0xFFEFEFEF),
      card: Color(0xFFFFFFFF),
      soft: Color(0xFFE4E4E4),
      softHigh: Color(0xFFD9D9D9),
      fg: Color(0xFF121212),
      muted: Color(0xFF6D6D6D),
      outline: Color(0xFFE0E0E0),
      accent: Color(0xFFD4F25A),
      onAccent: Color(0xFF121212),
      second: Color(0xFFE8E8E8),
      onSecond: Color(0xFF3A3A3A),
      ok: Color(0xFF2E9E6A),
      nav: Color(0xFF121212),
      navIcon: Color(0xFF9A9A9A),
    ),
    (limeCharcoal, Brightness.dark) => const PaletteTokens(
      bg: Color(0xFF0B0B0B),
      card: Color(0xFF171717),
      soft: Color(0xFF222222),
      softHigh: Color(0xFF2C2C2C),
      fg: Color(0xFFF2F2F2),
      muted: Color(0xFF8C8C8C),
      outline: Color(0xFF242424),
      accent: Color(0xFFD4F25A),
      onAccent: Color(0xFF121212),
      second: Color(0xFF232323),
      onSecond: Color(0xFFC9C9C9),
      ok: Color(0xFF5ACD8F),
      nav: Color(0xFF222222),
      navIcon: Color(0xFF8C8C8C),
    ),
    (skyAmber, Brightness.light) => const PaletteTokens(
      bg: Color(0xFFF3F6FA),
      card: Color(0xFFFFFFFF),
      soft: Color(0xFFE6ECF4),
      softHigh: Color(0xFFDAE2EE),
      fg: Color(0xFF0F1A2A),
      muted: Color(0xFF627085),
      outline: Color(0xFFDFE6F0),
      accent: Color(0xFFFFD23F),
      onAccent: Color(0xFF0F1A2A),
      second: Color(0xFFD8E9FB),
      onSecond: Color(0xFF2A68A8),
      ok: Color(0xFF23915F),
      nav: Color(0xFF0F1A2A),
      navIcon: Color(0xFF9DAABB),
    ),
    (skyAmber, Brightness.dark) => const PaletteTokens(
      bg: Color(0xFF08101F),
      card: Color(0xFF111C33),
      soft: Color(0xFF1A2744),
      softHigh: Color(0xFF223152),
      fg: Color(0xFFEEF3FA),
      muted: Color(0xFF8797B0),
      outline: Color(0xFF1A2744),
      accent: Color(0xFFFFD23F),
      onAccent: Color(0xFF0F1A2A),
      second: Color(0xFF16294A),
      onSecond: Color(0xFF8CC1F2),
      ok: Color(0xFF4CC38A),
      nav: Color(0xFF1A2744),
      navIcon: Color(0xFF8797B0),
    ),
  };
}

/// Jeu de couleurs d'une palette pour une luminosité donnée.
@immutable
class PaletteTokens {
  const PaletteTokens({
    required this.bg,
    required this.card,
    required this.soft,
    required this.softHigh,
    required this.fg,
    required this.muted,
    required this.outline,
    required this.accent,
    required this.onAccent,
    required this.second,
    required this.onSecond,
    required this.ok,
    required this.nav,
    required this.navIcon,
  });

  /// Fond de page.
  final Color bg;
  final Color card;

  /// Fonds discrets : champs, pastilles, carrés d'initiales.
  final Color soft;
  final Color softHigh;
  final Color fg;
  final Color muted;
  final Color outline;

  /// Accent unique : ce qui demande une action, l'onglet actif, le bouton +.
  final Color accent;
  final Color onAccent;

  /// Couleur secondaire discrète pour les statuts, pour ne pas tout mettre en accent.
  final Color second;
  final Color onSecond;
  final Color ok;

  /// Barre de navigation flottante (rendue translucide).
  final Color nav;
  final Color navIcon;
}
