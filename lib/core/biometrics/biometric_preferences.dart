import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Préférence « déverrouillage biométrique activé », propre à cet appareil.
abstract interface class BiometricPreferences {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool value);
}

final biometricPreferencesProvider = Provider<BiometricPreferences>((ref) => SecureBiometricPreferences());

/// Vaut `true` seulement si la préférence est activée. Invalidé après tout
/// changement (voir [BiometricPreferences.setEnabled]) pour rester à jour.
final biometricEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricPreferencesProvider).isEnabled(),
);

class SecureBiometricPreferences implements BiometricPreferences {
  SecureBiometricPreferences([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'biometric_lock_enabled';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> isEnabled() async => await _storage.read(key: _key) == '1';

  @override
  Future<void> setEnabled(bool value) => _storage.write(key: _key, value: value ? '1' : '0');
}
