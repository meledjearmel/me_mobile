import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';
import '../../../app/theme/app_palette.dart';
import '../../../shared/widgets/glass.dart';
import '../../../app/env.dart';
import '../../../app/theme/theme_preferences.dart';
import '../../../core/biometrics/biometric_authenticator.dart';
import '../../../core/biometrics/biometric_lock_controller.dart';
import '../../../core/biometrics/biometric_preferences.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/surfaces.dart';
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
  bool _updatingTheme = false;

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _updatingTheme = true);
    try {
      await ref.read(themePreferencesProvider).setThemeMode(mode);
      ref.invalidate(themeModeProvider);
    } finally {
      if (mounted) {
        setState(() => _updatingTheme = false);
      }
    }
  }

  Future<void> _setPalette(AppPaletteVariant palette) async {
    setState(() => _updatingTheme = true);
    try {
      await ref.read(themePreferencesProvider).setPalette(palette);
      ref.invalidate(paletteProvider);
    } finally {
      if (mounted) {
        setState(() => _updatingTheme = false);
      }
    }
  }

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
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar.statusOnly(),
      // Builder : les marges lues sous le Scaffold tiennent compte des barres flottantes.
      body: Builder(
        builder: (context) => ListView(
          padding: pageInsets(context, horizontal: 20, top: 16),
          children: [
            Text('Compte', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    InitialsAvatar(
                      user?.initials ?? '?',
                      size: 56,
                      photoUrl: ref.watch(profileProvider).value?.photoUrl,
                    ),
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
            const SizedBox(height: 28),
            const SectionHeader('Sécurité et apparence'),
            const SizedBox(height: 8),
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.contrast_rounded),
                        const SizedBox(width: 12),
                        Text('Apparence', style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        // Occupe toute la largeur de la carte, segments de même taille.
                        expandedInsets: EdgeInsets.zero,
                        // Icônes seules ; le libellé reste lu par les lecteurs d'écran (infobulle).
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            tooltip: 'Système',
                            icon: Icon(Icons.desktop_windows_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            tooltip: 'Clair',
                            icon: Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment(value: ThemeMode.dark, tooltip: 'Sombre', icon: Icon(Icons.dark_mode_outlined)),
                        ],
                        showSelectedIcon: false,
                        selected: {themeMode},
                        onSelectionChanged: _updatingTheme ? null : (modes) => _setThemeMode(modes.single),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Palette', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 10),
                    _PalettePicker(
                      selected: ref.watch(paletteProvider).value ?? AppPaletteVariant.fallback,
                      onSelected: _updatingTheme ? null : _setPalette,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            const SectionHeader('Outils'),
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('Corbeille'),
                    subtitle: const Text('Restaurer ou purger un élément supprimé'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const TrashScreen())),
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
      ),
    );
  }
}

/// Grille 2 × 2 des palettes : aperçu (fond, carte, accent) et nom, la
/// palette active entourée de l'accent.
class _PalettePicker extends StatelessWidget {
  const _PalettePicker({required this.selected, required this.onSelected});

  final AppPaletteVariant selected;
  final ValueChanged<AppPaletteVariant>? onSelected;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    const variants = AppPaletteVariant.values;

    return Column(
      children: [
        for (var i = 0; i < variants.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            children: [
              for (final variant in variants.skip(i).take(2)) ...[
                if (variant != variants[i]) const SizedBox(width: 10),
                Expanded(
                  child: _PaletteTile(
                    variant: variant,
                    tokens: variant.tokens(brightness),
                    selected: variant == selected,
                    onTap: onSelected == null ? null : () => onSelected!(variant),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({required this.variant, required this.tokens, required this.selected, required this.onTap});

  final AppPaletteVariant variant;
  final PaletteTokens tokens;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label: 'Palette ${variant.label}',
      excludeSemantics: true,
      child: Material(
        color: tokens.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? theme.colorScheme.onSurface : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Aperçu miniature : carte, accent et couleur secondaire.
                Row(
                  children: [
                    for (final color in [tokens.card, tokens.accent, tokens.second])
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: tokens.outline),
                        ),
                      ),
                    const Spacer(),
                    if (selected) Icon(Icons.check_circle_rounded, size: 18, color: tokens.fg),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  variant.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: tokens.fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
