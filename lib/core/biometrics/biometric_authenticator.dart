import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Fine couche au-dessus de `local_auth`, pour pouvoir la remplacer par un
/// faux dans les tests (pas de canal de plateforme dans les tests unitaires).
abstract interface class BiometricAuthenticator {
  /// Empreinte, visage… disponible et configuré sur cet appareil.
  Future<bool> isSupported();

  /// Affiche l'invite biométrique. `false` si refusée, échouée ou indisponible.
  Future<bool> authenticate(String reason);
}

final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>((ref) => LocalAuthBiometricAuthenticator());

/// Empreinte, visage… configuré sur cet appareil (pas seulement disponible en théorie).
final biometricSupportedProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricAuthenticatorProvider).isSupported(),
);

class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  final _auth = LocalAuthentication();

  @override
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // biometricOnly: false → l'appareil peut proposer son code/schéma en
        // repli si l'empreinte échoue plusieurs fois, plutôt que de bloquer.
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
    } on Object {
      return false;
    }
  }
}
