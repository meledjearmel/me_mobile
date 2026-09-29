import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

/// Thèmes jour / nuit épurés construits depuis une palette ([AppPaletteVariant]) :
/// cartes arrondies sans bordure ni ombre, un accent unique,
/// tout en Plus Jakarta Sans (titres en 800 serré).
abstract final class AppTheme {
  /// Police à chiffres tabulaires pour le code 2FA et les montants (`Track`, prix…).
  static TextStyle get fontMono => GoogleFonts.jetBrainsMono();

  static const radius = 24.0;
  static const fieldRadius = 16.0;

  /// Palette par défaut (tests, écrans hors préférence).
  static final light = build(AppPaletteVariant.fallback, Brightness.light);
  static final dark = build(AppPaletteVariant.fallback, Brightness.dark);

  static final _cache = <(AppPaletteVariant, Brightness), ThemeData>{};

  /// Thème complet d'une palette pour une luminosité donnée.
  static ThemeData build(AppPaletteVariant variant, Brightness brightness) =>
      _cache.putIfAbsent((variant, brightness), () {
        final t = variant.tokens(brightness);
        final isLight = brightness == Brightness.light;
        final scheme = ColorScheme(
          brightness: brightness,
          // Bouton principal : encre le jour, accent la nuit.
          primary: isLight ? t.fg : t.accent,
          onPrimary: isLight ? t.bg : t.onAccent,
          primaryContainer: t.accent,
          onPrimaryContainer: t.onAccent,
          secondary: t.accent,
          onSecondary: t.onAccent,
          secondaryContainer: t.second,
          onSecondaryContainer: t.onSecond,
          tertiary: AppPalette.coral,
          onTertiary: t.fg,
          error: isLight ? AppPalette.danger : const Color(0xFFFF8A7A),
          onError: isLight ? Colors.white : t.bg,
          surface: t.bg,
          onSurface: t.fg,
          onSurfaceVariant: t.muted,
          surfaceContainerLowest: isLight ? Colors.white : Color.lerp(t.bg, Colors.black, 0.3)!,
          surfaceContainerLow: isLight ? Color.lerp(t.bg, Colors.white, 0.5)! : t.card,
          surfaceContainer: t.soft,
          surfaceContainerHigh: t.softHigh,
          surfaceContainerHighest: Color.lerp(t.softHigh, t.fg, 0.06)!,
          outline: Color.lerp(t.outline, t.fg, 0.12)!,
          outlineVariant: t.outline,
        );
        return _build(scheme, AppColors.fromTokens(t, brightness));
      });

  static ThemeData _build(ColorScheme scheme, AppColors colors) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final body = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
    TextStyle? heading(TextStyle? style) =>
        style?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.1);
    final text = body.copyWith(
      displayLarge: heading(body.displayLarge),
      displayMedium: heading(body.displayMedium),
      displaySmall: heading(body.displaySmall),
      headlineLarge: heading(body.headlineLarge),
      headlineMedium: heading(body.headlineMedium),
      headlineSmall: heading(body.headlineSmall),
      titleLarge: body.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: body.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(fieldRadius),
      borderSide: BorderSide.none,
    );

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(borderSide: BorderSide(color: colors.accent, width: 1.5)),
        errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: scheme.error, width: 1.5)),
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
          side: BorderSide.none,
          backgroundColor: colors.card,
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48), textStyle: text.labelLarge),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.accent,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) =>
              IconThemeData(color: states.contains(WidgetState.selected) ? colors.onAccent : scheme.onSurfaceVariant),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: scheme.surfaceContainer,
          foregroundColor: scheme.onSurfaceVariant,
          selectedBackgroundColor: colors.accent,
          selectedForegroundColor: colors.onAccent,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 44),
          textStyle: text.labelLarge,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppPalette.ink : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? colors.accent : scheme.surfaceContainerHigh,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.card,
        selectedColor: colors.accent,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        // Or sélectionné : le libellé passe à l'encre, y compris en mode nuit.
        labelStyle: text.labelLarge?.copyWith(
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected) ? colors.onAccent : scheme.onSurface,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        shape: const CircleBorder(),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        minVerticalPadding: 12,
        iconColor: scheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(fieldRadius)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
    );
  }
}
