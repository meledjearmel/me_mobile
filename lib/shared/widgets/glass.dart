import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';

/// Barre du haut flottante et floutée : la page défile dessous et reste
/// visible par transparence. Bouton retour et actions en pastilles rondes.
///
/// À utiliser avec `Scaffold(extendBodyBehindAppBar: true)` ; le contenu
/// se décale ensuite avec [PageListView] ou [pageInsets].
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({super.key, this.title, this.actions = const [], this.toolbar = true});

  /// Barre réduite à la zone de statut, pour les racines d'onglets
  /// (leur grand titre défile avec la page).
  const GlassAppBar.statusOnly({super.key}) : title = null, actions = const [], toolbar = false;

  final String? title;
  final List<Widget> actions;
  final bool toolbar;

  static const toolbarHeight = 60.0;

  @override
  Size get preferredSize => Size.fromHeight(toolbar ? toolbarHeight : 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: ColoredBox(
          color: theme.scaffoldBackgroundColor.withValues(alpha: 0.72),
          child: SafeArea(
            bottom: false,
            child: !toolbar
                ? const SizedBox(width: double.infinity)
                : SizedBox(
                    height: toolbarHeight,
                    child: IconButtonTheme(
                      data: IconButtonThemeData(style: roundButtonStyle(context)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            if (canPop)
                              IconButton(
                                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                                onPressed: () => Navigator.maybePop(context),
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                            Expanded(
                              child: title == null
                                  ? const SizedBox()
                                  : Text(
                                      title!,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium,
                                    ),
                            ),
                            for (final action in actions)
                              Padding(padding: const EdgeInsets.only(left: 8), child: action),
                            // Équilibre le bouton retour quand un titre est centré.
                            if (title != null && canPop && actions.isEmpty) const SizedBox(width: 48),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Pastille ronde fond carte, pour les boutons posés sur la barre.
  static ButtonStyle roundButtonStyle(BuildContext context) => IconButton.styleFrom(
    backgroundColor: context.appColors.card,
    foregroundColor: Theme.of(context).colorScheme.onSurface,
    fixedSize: const Size.square(44),
    shape: const CircleBorder(),
  );
}

/// En-tête flouté de hauteur libre (titre + sélecteur…), posé comme `appBar`
/// d'un `Scaffold(extendBodyBehindAppBar: true)` : la page défile dessous.
class GlassHeader extends StatelessWidget implements PreferredSizeWidget {
  const GlassHeader({super.key, required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.72),
          child: SafeArea(
            bottom: false,
            child: SizedBox(height: height, child: child),
          ),
        ),
      ),
    );
  }
}

/// Bouton flottant rond en verre : or translucide, flou de ce qui passe dessous.
///
/// Il se remonte de [bottom] au-dessus des barres flottantes du bas : le
/// Scaffold le place sans tenir compte de la marge basse héritée, il finirait
/// caché derrière la navigation. [bottom] se lit dans le contexte de l'écran,
/// au-dessus de son Scaffold (dans l'emplacement du bouton, cette marge est déjà retirée).
class GlassFab extends StatelessWidget {
  const GlassFab({super.key, required this.icon, required this.tooltip, required this.onPressed, this.bottom = 0});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double bottom;

  static const size = 58.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Tooltip(
        message: tooltip,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, 8))],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Material(
                color: colors.accent.withValues(alpha: 0.72),
                child: InkWell(
                  onTap: onPressed,
                  child: SizedBox.square(
                    dimension: size,
                    child: Icon(icon, size: 26, color: colors.onAccent, semanticLabel: tooltip),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marges d'une page dont la barre du haut et le bas (navigation ou
/// bouton d'action) flottent au-dessus du contenu.
EdgeInsets pageInsets(BuildContext context, {double horizontal = 16, double top = 8, double bottom = 24}) {
  final padding = MediaQuery.paddingOf(context);
  return EdgeInsets.fromLTRB(horizontal, padding.top + top, horizontal, padding.bottom + bottom);
}

/// ListView décalée sous la barre du haut et au-dessus des éléments flottants du bas.
class PageListView extends StatelessWidget {
  const PageListView({super.key, required this.children, this.controller, this.horizontal = 16});

  final List<Widget> children;
  final ScrollController? controller;
  final double horizontal;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: pageInsets(context, horizontal: horizontal),
      children: children,
    );
  }
}

/// Fond du bas d'écran : dégradé vers la couleur de page pour que les
/// éléments flottants restent lisibles au-dessus du contenu qui défile.
class BottomFade extends StatelessWidget {
  const BottomFade({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [background, background.withValues(alpha: 0.85), background.withValues(alpha: 0)],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}
