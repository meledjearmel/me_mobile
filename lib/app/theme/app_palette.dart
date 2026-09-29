import 'package:flutter/material.dart';

import 'app_palette_variant.dart';

export 'app_palette_variant.dart';

/// Palette de l'app, dérivée du site public (`me/resources/css/public.css`) :
/// fond neutre chaud, cartes blanches, or comme accent unique, nuit quasi noire.
abstract final class AppPalette {
  // Jour
  static const cream = Color(0xFFF6F4EE);
  static const soft = Color(0xFFEFEBE1);
  static const sand = Color(0xFFEEE8D2);
  static const ink = Color(0xFF060606);
  static const gold = Color(0xFFFFDA3F);
  static const coral = Color(0xFFFC9073);
  static const skyFrom = Color(0xFF71B7F4);
  static const skyTo = Color(0xFF5788B3);
  static const wisp = Color(0xFFFDEED6);
  static const dayBorder = Color(0xFFE7DFCD);

  // Nuit
  static const night = Color(0xFF0A0E1A);
  static const nightSurface = Color(0xFF141A2B);
  static const nightRaised = Color(0xFF1A2236);
  static const moon = Color(0xFFFFF9E9);
  static const nightSkyFrom = Color(0xFF1F3B6D);
  static const nightSkyTo = Color(0xFF031835);

  // États
  static const success = Color(0xFF2E9E6A);
  static const danger = Color(0xFFD9483B);
}

/// Couleurs propres à l'app, hors du [ColorScheme] Material, tirées de la
/// palette choisie ([AppPaletteVariant]).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.card,
    required this.hero,
    required this.onHero,
    required this.accent,
    required this.onAccent,
    required this.highlight,
    required this.success,
    required this.muted,
    required this.second,
    required this.onSecond,
    required this.nav,
    required this.navIcon,
  });

  factory AppColors.fromTokens(PaletteTokens t, Brightness brightness) => AppColors(
    card: t.card,
    hero: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: brightness == Brightness.light
          ? const [AppPalette.skyFrom, AppPalette.skyTo]
          : const [AppPalette.nightSkyFrom, AppPalette.nightSkyTo],
    ),
    onHero: brightness == Brightness.light ? Colors.white : AppPalette.moon,
    accent: t.accent,
    onAccent: t.onAccent,
    highlight: AppPalette.coral,
    success: t.ok,
    muted: t.muted,
    second: t.second,
    onSecond: t.onSecond,
    nav: t.nav,
    navIcon: t.navIcon,
  );

  /// Fond des cartes.
  final Color card;

  /// Dégradé « ciel » du hero du site (connexion, verrouillage).
  final Gradient hero;
  final Color onHero;

  /// Accent : badges, indicateur de navigation, éléments à traiter.
  final Color accent;
  final Color onAccent;

  /// Corail : mise en avant secondaire.
  final Color highlight;
  final Color success;
  final Color muted;

  /// Couleur secondaire discrète des statuts.
  final Color second;
  final Color onSecond;

  /// Barre de navigation flottante et ses icônes inactives.
  final Color nav;
  final Color navIcon;

  @override
  AppColors copyWith({
    Color? card,
    Gradient? hero,
    Color? onHero,
    Color? accent,
    Color? onAccent,
    Color? highlight,
    Color? success,
    Color? muted,
    Color? second,
    Color? onSecond,
    Color? nav,
    Color? navIcon,
  }) => AppColors(
    card: card ?? this.card,
    hero: hero ?? this.hero,
    onHero: onHero ?? this.onHero,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    highlight: highlight ?? this.highlight,
    success: success ?? this.success,
    muted: muted ?? this.muted,
    second: second ?? this.second,
    onSecond: onSecond ?? this.onSecond,
    nav: nav ?? this.nav,
    navIcon: navIcon ?? this.navIcon,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) {
      return this;
    }
    return AppColors(
      card: Color.lerp(card, other.card, t)!,
      hero: Gradient.lerp(hero, other.hero, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      success: Color.lerp(success, other.success, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      second: Color.lerp(second, other.second, t)!,
      onSecond: Color.lerp(onSecond, other.onSecond, t)!,
      nav: Color.lerp(nav, other.nav, t)!,
      navIcon: Color.lerp(navIcon, other.navIcon, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
