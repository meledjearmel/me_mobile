import 'package:flutter/material.dart';

/// Palette du site public (`me/resources/css/public.css`).
abstract final class AppPalette {
  // Jour
  static const cream = Color(0xFFFFF9F1);
  static const sand = Color(0xFFEEE8D2);
  static const ink = Color(0xFF060606);
  static const gold = Color(0xFFFFDA3F);
  static const coral = Color(0xFFFC9073);
  static const skyFrom = Color(0xFF71B7F4);
  static const skyTo = Color(0xFF5788B3);
  static const wisp = Color(0xFFFDEED6);
  static const dayBorder = Color(0xFFE7DFCD);

  // Nuit
  static const night = Color(0xFF0D1328);
  static const nightSurface = Color(0xFF111C36);
  static const nightRaised = Color(0xFF1B2A55);
  static const moon = Color(0xFFFFF9E9);
  static const nightSkyFrom = Color(0xFF1F3B6D);
  static const nightSkyTo = Color(0xFF031835);

  // États
  static const success = Color(0xFF2E9E6A);
  static const danger = Color(0xFFD9483B);
}

/// Couleurs propres à l'app, hors du [ColorScheme] Material.
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
  });

  static const light = AppColors(
    card: Colors.white,
    hero: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppPalette.skyFrom, AppPalette.skyTo],
    ),
    onHero: Colors.white,
    accent: AppPalette.gold,
    onAccent: AppPalette.ink,
    highlight: AppPalette.coral,
    success: AppPalette.success,
    muted: Color(0xFF6B665C),
  );

  static const dark = AppColors(
    card: AppPalette.nightSurface,
    hero: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppPalette.nightSkyFrom, AppPalette.nightSkyTo],
    ),
    onHero: AppPalette.moon,
    accent: AppPalette.gold,
    onAccent: AppPalette.ink,
    highlight: AppPalette.coral,
    success: Color(0xFF4CC38A),
    muted: Color(0xFFA8B0C8),
  );

  /// Fond des cartes (blanc sur crème, bleu nuit relevé la nuit).
  final Color card;

  /// Dégradé « ciel » du hero du site.
  final Gradient hero;
  final Color onHero;

  /// Or : badges, indicateur de navigation, éléments à traiter.
  final Color accent;
  final Color onAccent;

  /// Corail : mise en avant secondaire.
  final Color highlight;
  final Color success;
  final Color muted;

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
  }) =>
      AppColors(
        card: card ?? this.card,
        hero: hero ?? this.hero,
        onHero: onHero ?? this.onHero,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        highlight: highlight ?? this.highlight,
        success: success ?? this.success,
        muted: muted ?? this.muted,
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
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
