import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_palette.dart';
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

    final tabs = [
      const _Tab(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Accueil'),
      _Tab(icon: Icons.inbox_outlined, selectedIcon: Icons.inbox_rounded, label: 'Boîte', badge: todo),
      const _Tab(icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, label: 'Contenu'),
      const _Tab(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Compte'),
    ];

    return Scaffold(
      // La barre flotte : la page défile dessous et reste visible autour de la pilule.
      extendBody: true,
      body: shell,
      // Pas de fond derrière la pilule : la page reste visible à travers elle.
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayerBar(),
            _FloatingNavBar(
              tabs: tabs,
              currentIndex: shell.currentIndex,
              // Retoucher l'onglet actif revient à sa racine.
              onSelected: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab({required this.icon, required this.selectedIcon, required this.label, this.badge = 0});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
}

/// Barre noire en pilule ; l'onglet actif s'élargit en pastille or avec son libellé.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.tabs, required this.currentIndex, required this.onSelected});

  final List<_Tab> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // Pilule translucide et floutée : on devine la page qui défile dessous.
    return DecoratedBox(
      decoration: const ShapeDecoration(
        shape: StadiumBorder(),
        shadows: [BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 64,
            padding: const EdgeInsets.all(6),
            color: context.appColors.nav.withValues(alpha: 0.62),
            child: Row(
              // L'indicateur occupe toute la hauteur intérieure de la barre.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < tabs.length; i++)
                  _NavItem(tab: tabs[i], selected: i == currentIndex, onTap: () => onSelected(i)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.selected, required this.onTap});

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = selected ? colors.onAccent : colors.navIcon;
    Widget icon = Icon(selected ? tab.selectedIcon : tab.icon, color: color, size: 22);
    if (tab.badge > 0 && !selected) {
      icon = Badge(
        label: Text('${tab.badge}'),
        backgroundColor: colors.accent,
        textColor: colors.onAccent,
        child: icon,
      );
    }

    return Expanded(
      flex: selected ? 9 : 5,
      child: Semantics(
        button: true,
        selected: selected,
        label: tab.badge > 0 ? '${tab.label}, ${tab.badge} à traiter' : tab.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: ShapeDecoration(
              color: selected ? colors.accent : Colors.transparent,
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                if (selected) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.onAccent),
                    ),
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
