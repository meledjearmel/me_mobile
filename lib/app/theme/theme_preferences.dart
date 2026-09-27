import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Préférence d'apparence (clair / sombre / système), propre à cet appareil.
abstract interface class ThemePreferences {
  Future<ThemeMode> getThemeMode();

  Future<void> setThemeMode(ThemeMode mode);
}

final themePreferencesProvider = Provider<ThemePreferences>((ref) => SecureThemePreferences());

/// Valeur courante, relue depuis le stockage. Invalidé après tout changement
/// (voir [ThemePreferences.setThemeMode]) pour rester à jour, comme
/// `biometricEnabledProvider`.
final themeModeProvider = FutureProvider<ThemeMode>(
  (ref) => ref.watch(themePreferencesProvider).getThemeMode(),
);

class SecureThemePreferences implements ThemePreferences {
  SecureThemePreferences([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'theme_mode';

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
}
