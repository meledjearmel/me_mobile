import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

/// Thèmes jour / nuit, repris du site public : fond crème ou bleu nuit,
/// cartes arrondies sans ombre, accent or, titres en DM Serif Display.
abstract final class AppTheme {
  /// Police à chiffres tabulaires pour le code 2FA et les montants (`Track`, prix…).
  static TextStyle get fontMono => GoogleFonts.jetBrainsMono();

  static const radius = 24.0;
  static const fieldRadius = 16.0;

  static final light = _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: AppPalette.ink,
      onPrimary: AppPalette.cream,
      primaryContainer: AppPalette.gold,
      onPrimaryContainer: AppPalette.ink,
      secondary: AppPalette.gold,
      onSecondary: AppPalette.ink,
      tertiary: AppPalette.coral,
      onTertiary: AppPalette.ink,
      error: AppPalette.danger,
      onError: Colors.white,
      surface: AppPalette.cream,
      onSurface: AppPalette.ink,
      onSurfaceVariant: Color(0xFF6B665C),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFFBF4E8),
      surfaceContainer: Color(0xFFF5EFDF),
      surfaceContainerHigh: AppPalette.sand,
      surfaceContainerHighest: Color(0xFFE6DFC6),
      outline: Color(0xFFCFC6AE),
      outlineVariant: AppPalette.dayBorder,
    ),
    AppColors.light,
  );

  static final dark = _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: AppPalette.moon,
      onPrimary: AppPalette.night,
      primaryContainer: AppPalette.gold,
      onPrimaryContainer: AppPalette.ink,
      secondary: AppPalette.gold,
      onSecondary: AppPalette.ink,
      tertiary: AppPalette.coral,
      onTertiary: AppPalette.ink,
      error: Color(0xFFFF8A7A),
      onError: AppPalette.night,
      surface: AppPalette.night,
      onSurface: AppPalette.moon,
      onSurfaceVariant: Color(0xFFA8B0C8),
      surfaceContainerLowest: Color(0xFF0A0F20),
      surfaceContainerLow: Color(0xFF0F1830),
      surfaceContainer: AppPalette.nightSurface,
      surfaceContainerHigh: Color(0xFF16223F),
      surfaceContainerHighest: AppPalette.nightRaised,
      outline: Color(0xFF34436E),
      outlineVariant: Color(0xFF1E2B4D),
    ),
    AppColors.dark,
  );

  static ThemeData _build(ColorScheme scheme, AppColors colors) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final body = GoogleFonts.spaceGroteskTextTheme(base.textTheme);
    final text = body.copyWith(
      displayLarge: GoogleFonts.dmSerifDisplay(textStyle: body.displayLarge),
      displayMedium: GoogleFonts.dmSerifDisplay(textStyle: body.displayMedium),
      displaySmall: GoogleFonts.dmSerifDisplay(textStyle: body.displaySmall),
      headlineLarge: GoogleFonts.dmSerifDisplay(textStyle: body.headlineLarge),
      headlineMedium: GoogleFonts.dmSerifDisplay(textStyle: body.headlineMedium),
      headlineSmall: GoogleFonts.dmSerifDisplay(textStyle: body.headlineSmall),
      titleLarge: body.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(fieldRadius),
      borderSide: BorderSide(color: scheme.outlineVariant),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(borderSide: BorderSide(color: scheme.primary, width: 1.5)),
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
          side: BorderSide(color: scheme.outline),
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
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? colors.onAccent : scheme.onSurfaceVariant,
          ),
        ),
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
