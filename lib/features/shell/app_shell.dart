import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../content/music/presentation/widgets/mini_player_bar.dart';
import '../dashboard/data/dashboard_repository.dart';

/// Coque à 4 onglets : Accueil, Boîte de réception, Contenu, Compte.
/// Chaque onglet garde sa propre pile de navigation.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todo = ref.watch(dashboardProvider).value?.todo.total ?? 0;

    final destinations = [
      const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Accueil'),
      NavigationDestination(
        icon: todo > 0 ? Badge(label: Text('$todo'), child: const Icon(Icons.inbox_outlined)) : const Icon(Icons.inbox_outlined),
        selectedIcon: todo > 0 ? Badge(label: Text('$todo'), child: const Icon(Icons.inbox_rounded)) : const Icon(Icons.inbox_rounded),
        label: 'Réception',
        tooltip: 'Boîte de réception',
      ),
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: 'Contenu',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Compte',
      ),
    ];

    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayerBar(),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
            ),
            child: NavigationBar(
              selectedIndex: shell.currentIndex,
              // Retoucher l'onglet actif revient à sa racine.
              onDestinationSelected: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
              destinations: destinations,
            ),
          ),
        ],
      ),
    );
  }
}
