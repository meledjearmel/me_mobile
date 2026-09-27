import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/feedback.dart';
import '../../auth/application/session_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    return hour >= 18 || hour < 5 ? 'Bonsoir' : 'Bonjour';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                InitialsAvatar(user?.initials ?? '?'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      Text(user?.firstName ?? '', style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
                const AppLogo(height: 20),
              ],
            ),
            const SizedBox(height: 28),
            Text('Tableau de bord', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 16),
            const ComingSoon(
              icon: Icons.insights_rounded,
              title: 'Éléments à traiter et audience',
              description: 'Compteurs, visites sur 30 jours et santé du site : prévu à l\'étape 3.',
            ),
          ],
        ),
      ),
    );
  }
}
