import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/session_controller.dart';
import 'biometric_preferences.dart';

/// `true` = l'app doit montrer l'écran de verrouillage plutôt que son contenu.
///
/// L'état initial (calculé une seule fois, au tout premier démarrage du
/// provider) répond à la question « faut-il verrouiller à froid ? » : oui si
/// la préférence est activée et qu'une session est déjà valide (jeton stocké).
/// Les transitions suivantes sont pilotées explicitement :
/// - [SessionController] appelle [unlock] après une connexion interactive
///   réussie (inutile de redemander l'empreinte juste après le mot de passe)
///   et à la déconnexion ;
/// - le cycle de vie de l'app appelle [lockIfEnabled] quand elle repasse en
///   arrière-plan.
final biometricLockControllerProvider = AsyncNotifierProvider<BiometricLockController, bool>(
  BiometricLockController.new,
);

class BiometricLockController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final enabled = await ref.read(biometricEnabledProvider.future);
    final user = await ref.read(sessionProvider.future);
    return enabled && user != null;
  }

  void unlock() => state = const AsyncData(false);

  /// À appeler quand l'app repasse en arrière-plan (voir `MeAdminApp`).
  Future<void> lockIfEnabled() async {
    final enabled = await ref.read(biometricEnabledProvider.future);
    if (enabled && ref.read(sessionProvider).value != null) {
      state = const AsyncData(true);
    }
  }
}
