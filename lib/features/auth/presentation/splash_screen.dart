import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/app_logo.dart';
import '../application/session_controller.dart';

/// Pendant la validation du jeton stocké. En cas d'échec réseau, propose de réessayer
/// sans déconnecter : le jeton reste valable.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final theme = Theme.of(context);
    final error = session.hasError && !session.isLoading ? session.error : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(height: 60),
                const SizedBox(height: 40),
                if (error == null)
                  const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 2.5))
                else ...[
                  Text(
                    error is ApiException ? error.message : 'Une erreur inattendue est survenue.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(sessionProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
