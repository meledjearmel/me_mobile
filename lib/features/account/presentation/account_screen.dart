import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/env.dart';
import '../../../core/biometrics/biometric_authenticator.dart';
import '../../../core/biometrics/biometric_lock_controller.dart';
import '../../../core/biometrics/biometric_preferences.dart';
import '../../../shared/widgets/feedback.dart';
import '../../auth/application/session_controller.dart';
import '../../trash/presentation/trash_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _loggingOut = false;
  bool _updatingBiometric = false;

  Future<void> _toggleBiometric(bool value) async {
    setState(() => _updatingBiometric = true);
    try {
      if (value) {
        final ok = await ref
            .read(biometricAuthenticatorProvider)
            .authenticate('Confirmez votre identité pour activer le déverrouillage biométrique.');
        if (!ok) {
          return;
        }
      }
      await ref.read(biometricPreferencesProvider).setEnabled(value);
      ref.invalidate(biometricEnabledProvider);
      if (!value) {
        ref.read(biometricLockControllerProvider.notifier).unlock();
      }
    } finally {
      if (mounted) {
        setState(() => _updatingBiometric = false);
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Cet appareil ne recevra plus de notifications jusqu\'à la prochaine connexion.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Se déconnecter')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _loggingOut = true);
    // Retire aussi le jeton push de l'appareil (voir SessionController.logout).
    await ref.read(sessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).value;
    final theme = Theme.of(context);
    final biometricSupported = ref.watch(biometricSupportedProvider).value ?? false;
    final biometricEnabled = ref.watch(biometricEnabledProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Compte')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  InitialsAvatar(user?.initials ?? '?', size: 56),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? '', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: biometricSupported
                ? SwitchListTile(
                    secondary: const Icon(Icons.fingerprint_rounded),
                    title: const Text('Déverrouillage biométrique'),
                    subtitle: const Text('Empreinte ou visage à l\'ouverture de l\'app, au lieu du mot de passe.'),
                    value: biometricEnabled,
                    onChanged: _updatingBiometric ? null : _toggleBiometric,
                  )
                : const ListTile(
                    enabled: false,
                    leading: Icon(Icons.fingerprint_rounded),
                    title: Text('Déverrouillage biométrique'),
                    subtitle: Text('Aucune empreinte ni visage configuré sur cet appareil.'),
                  ),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Corbeille'),
                  subtitle: const Text('Restaurer ou purger un élément supprimé'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const TrashScreen()),
                  ),
                ),
                const Divider(indent: 20, endIndent: 20),
                ListTile(
                  leading: const Icon(Icons.public_rounded),
                  title: const Text('Site public'),
                  subtitle: Text(Env.siteUrl),
                ),
                const Divider(indent: 20, endIndent: 20),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Documentation de l\'API'),
                  subtitle: Text('${Env.siteUrl}/docs/api'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _loggingOut ? null : _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
            ),
            icon: _loggingOut
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.logout_rounded),
            label: const Text('Se déconnecter'),
          ),
          const SizedBox(height: 16),
          Text(
            'Mot de passe, double authentification et passkeys se gèrent depuis le back-office web.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
