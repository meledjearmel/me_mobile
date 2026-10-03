import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/full_screen_image_viewer.dart';
import '../../../shared/widgets/glass.dart';
import '../application/profile_providers.dart';
import '../data/profile.dart';
import 'profile_edit_screen.dart';

/// Aperçu du profil, avant modification (§4.3).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: const GlassAppBar(),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Impossible de charger le profil.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(profileProvider), child: const Text('Réessayer')),
            ],
          ),
        ),
        data: (data) => _ProfileBody(profile: data),
      ),
      floatingActionButton: profile.maybeWhen(
        data: (data) => GlassFab(
          icon: Icons.edit_outlined,
          tooltip: 'Modifier le profil',
          bottom: MediaQuery.paddingOf(context).bottom,
          onPressed: () async {
            final updated = await Navigator.of(context)
                .push<Profile>(MaterialPageRoute(builder: (context) => ProfileEditScreen(profile: data)));
            if (updated != null) {
              ref.invalidate(profileProvider);
            }
          },
        ),
        orElse: () => null,
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Même règle que le site : le profil choisi s'il est publié, sinon le premier publié.
    final published = ref.watch(publishedJobProfilesProvider).asData?.value ?? const [];
    final cvJobProfileLabel =
        (published.where((p) => p.id == profile.cvJobProfileId).firstOrNull ?? published.firstOrNull)?.label.display;

    return ListView(
      padding: pageInsets(context, horizontal: 20, bottom: 96),
      children: [
        Center(
          child: GestureDetector(
            onTap: profile.photoUrl == null
                ? null
                : () => FullScreenImageViewer.open(context, profile.photoUrl!, heroTag: 'profile-photo'),
            child: Semantics(
              button: profile.photoUrl != null,
              label: profile.photoUrl != null ? 'Photo du profil, voir en plein écran' : 'Aucune photo de profil',
              child: Hero(
                tag: 'profile-photo',
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
                  child: profile.photoUrl == null
                      ? Icon(Icons.person_outline_rounded, size: 40, color: theme.colorScheme.onSurfaceVariant)
                      : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(profile.name, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
        ),
        if (profile.headline.display.isNotEmpty) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              profile.headline.display,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(leading: const Icon(Icons.alternate_email_rounded), title: Text(profile.email)),
              if (profile.phone?.isNotEmpty == true) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(leading: const Icon(Icons.phone_outlined), title: Text(profile.phone!)),
              ],
              if (profile.location?.isNotEmpty == true) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(leading: const Icon(Icons.place_outlined), title: Text(profile.location!)),
              ],
              if (profile.socialLinks.github?.isNotEmpty == true) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(leading: const Icon(Icons.code_rounded), title: Text(profile.socialLinks.github!)),
              ],
              if (profile.socialLinks.linkedin?.isNotEmpty == true) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.business_center_outlined),
                  title: Text(profile.socialLinks.linkedin!),
                ),
              ],
            ],
          ),
        ),
        if (profile.bioShort.display.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Bio courte', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(profile.bioShort.display),
        ],
        if (profile.bioFull.display.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Bio complète', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(profile.bioFull.display),
        ],
        const SizedBox(height: 20),
        Text('CV du site', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(cvJobProfileLabel ?? 'Premier profil publié'),
            subtitle: Text(profile.cvSource.label),
          ),
        ),
        const SizedBox(height: 20),
        Text('Musique', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.music_note_outlined),
            title: const Text('Musique du site'),
            subtitle: Text(profile.music?.fileName ?? 'Piste par défaut'),
          ),
        ),
      ],
    );
  }
}
