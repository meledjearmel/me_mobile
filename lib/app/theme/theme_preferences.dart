import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_palette_variant.dart';

/// Préférences d'apparence (clair / sombre / système, et palette), propres à cet appareil.
abstract interface class ThemePreferences {
  Future<ThemeMode> getThemeMode();

  Future<void> setThemeMode(ThemeMode mode);

  Future<AppPaletteVariant> getPalette();

  Future<void> setPalette(AppPaletteVariant palette);
}

final themePreferencesProvider = Provider<ThemePreferences>((ref) => SecureThemePreferences());

/// Valeur courante, relue depuis le stockage. Invalidé après tout changement
/// (voir [ThemePreferences.setThemeMode]) pour rester à jour, comme
/// `biometricEnabledProvider`.
final themeModeProvider = FutureProvider<ThemeMode>((ref) => ref.watch(themePreferencesProvider).getThemeMode());

/// Palette choisie, relue depuis le stockage ; invalidée après [ThemePreferences.setPalette].
final paletteProvider = FutureProvider<AppPaletteVariant>((ref) => ref.watch(themePreferencesProvider).getPalette());

class SecureThemePreferences implements ThemePreferences {
  SecureThemePreferences([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'theme_mode';
  static const _paletteKey = 'theme_palette';

  final FlutterSecureStorage _storage;

  @override
  Future<ThemeMode> getThemeMode() async {
    switch (await _storage.read(key: _key)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) => _storage.write(key: _key, value: mode.name);

  @override
  Future<AppPaletteVariant> getPalette() async => AppPaletteVariant.fromName(await _storage.read(key: _paletteKey));

  @override
  Future<void> setPalette(AppPaletteVariant palette) => _storage.write(key: _paletteKey, value: palette.name);
}
