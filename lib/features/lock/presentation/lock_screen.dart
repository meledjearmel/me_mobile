import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../../core/biometrics/biometric_authenticator.dart';
import '../../../core/biometrics/biometric_lock_controller.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../auth/application/session_controller.dart';

/// Verrouillage local de l'app : la session reste valide côté serveur, mais
/// le contenu reste caché tant que l'empreinte (ou le visage) n'est pas
/// reconnu. Se déclenche à froid si activé, et à chaque retour au premier
/// plan (voir [BiometricLockController]).
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _authenticating = false;
  bool _lastAttemptFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_authenticating) {
      return;
    }
    setState(() {
      _authenticating = true;
      _lastAttemptFailed = false;
    });

    final ok = await ref
        .read(biometricAuthenticatorProvider)
        .authenticate('Déverrouillez Me Admin pour continuer.');

    if (!mounted) {
      return;
    }
    if (ok) {
      ref.read(biometricLockControllerProvider.notifier).unlock();
    } else {
      setState(() {
        _authenticating = false;
        _lastAttemptFailed = true;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('À utiliser si vous ne pouvez pas vous authentifier avec cet appareil.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Se déconnecter')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: colors.hero),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppLogo(height: 40, color: colors.onHero),
                  const SizedBox(height: 40),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(color: colors.onHero.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(Icons.fingerprint_rounded, size: 44, color: colors.onHero),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Application verrouillée',
                    style: theme.textTheme.headlineSmall?.copyWith(color: colors.onHero),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lastAttemptFailed
                        ? 'Authentification annulée ou échouée. Réessayez.'
                        : 'Utilisez votre empreinte ou votre visage pour continuer.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.onHero.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _authenticating ? null : _authenticate,
                    style: FilledButton.styleFrom(backgroundColor: colors.onHero, foregroundColor: AppPalette.ink),
                    icon: _authenticating
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.fingerprint_rounded),
                    label: Text(_authenticating ? 'Vérification…' : 'Déverrouiller'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _logout,
                    style: TextButton.styleFrom(foregroundColor: colors.onHero),
                    child: const Text('Se déconnecter'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
