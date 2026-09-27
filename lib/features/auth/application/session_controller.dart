import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/device/device_name.dart';
import '../../../core/push/push_service.dart';
import '../data/auth_repository.dart';
import '../data/user.dart';

/// Session de l'administrateur : `null` = déconnecté.
///
/// Au démarrage, le jeton stocké est validé par `GET /auth/me`. Une erreur réseau
/// laisse la session en erreur (écran « Réessayer ») plutôt que de déconnecter.
final sessionProvider = AsyncNotifierProvider<SessionController, User?>(SessionController.new);

class SessionController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final subscription = ref.watch(apiClientProvider).unauthorized.listen((_) => _expire());
    ref.onDispose(subscription.cancel);

    final tokens = ref.read(tokenStorageProvider);
    if (await tokens.read() == null) {
      return null;
    }

    try {
      return await ref.read(authRepositoryProvider).me();
    } on UnauthorizedException {
      await tokens.clear();
      return null;
    }
  }

  /// Première étape de connexion. Renvoie [TwoFactorRequired] si le compte a la 2FA :
  /// la session reste alors fermée jusqu'à [confirmTwoFactor].
  Future<LoginResult> login({required String email, required String password}) async {
    final result = await ref.read(authRepositoryProvider).login(
          email: email.trim(),
          password: password,
          deviceName: await ref.read(deviceNameProvider.future),
        );
    if (result is LoginSucceeded) {
      await _open(result);
    }
    return result;
  }

  Future<void> confirmTwoFactor({required String challenge, String? code, String? recoveryCode}) async {
    final result = await ref.read(authRepositoryProvider).confirmTwoFactor(
          challenge: challenge,
          deviceName: await ref.read(deviceNameProvider.future),
          code: code,
          recoveryCode: recoveryCode,
        );
    await _open(result);
  }

  /// Retire le jeton push de l'appareil, révoque le jeton d'API côté serveur si
  /// possible, puis ferme la session dans tous les cas (§3.1 : l'appareil ne
  /// doit plus recevoir de notifications une fois déconnecté).
  Future<void> logout() async {
    await ref.read(pushServiceProvider).unregisterCurrentDevice();
    try {
      await ref.read(authRepositoryProvider).logout();
    } on ApiException {
      // Hors ligne ou jeton déjà révoqué : la déconnexion locale suffit.
    } finally {
      await ref.read(tokenStorageProvider).clear();
      state = const AsyncData(null);
    }
  }

  Future<void> _open(LoginSucceeded result) async {
    await ref.read(tokenStorageProvider).write(result.token);
    state = AsyncData(result.user);
  }

  /// 401 reçu en cours de session : jeton révoqué depuis le web, retour à la connexion.
  Future<void> _expire() async {
    if (state.value == null) {
      return;
    }
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncData(null);
  }
}
