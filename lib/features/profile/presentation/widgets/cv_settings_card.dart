import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/models/uploaded_file.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../content/job_profiles/data/job_profile.dart';
import '../../../content/job_profiles/presentation/job_profile_form_screen.dart';
import '../../application/profile_providers.dart';
import '../../data/profile.dart';

/// Explication de la source choisie, telle que le site l'applique.
String cvSourceExplanation(CvSource source) => switch (source) {
  CvSource.uploaded =>
    'Le PDF importé est servi s\'il existe (sinon celui de l\'autre langue) ; le CV généré sert de repli.',
  CvSource.generated => 'Le CV généré à partir du contenu est toujours servi, même si un PDF est importé.',
};

/// « CV du site » : profil métier proposé et source prioritaire. Le profil
/// effectif suit la règle du site : le choix s'il est publié, sinon le premier
/// profil publié.
class CvSettingsCard extends ConsumerWidget {
  const CvSettingsCard({
    super.key,
    required this.jobProfileId,
    required this.source,
    required this.onJobProfileChanged,
    required this.onSourceChanged,
    this.jobProfileError,
    this.sourceError,
  });

  final int? jobProfileId;
  final CvSource source;
  final ValueChanged<int?> onJobProfileChanged;
  final ValueChanged<CvSource> onSourceChanged;
  final String? jobProfileError;
  final String? sourceError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = context.appColors.muted;
    final profiles = ref.watch(publishedJobProfilesProvider);
    final list = profiles.asData?.value ?? const <JobProfile>[];
    final chosen = list.where((p) => p.id == jobProfileId).firstOrNull;
    final effective = chosen ?? list.firstOrNull;
    final unpublished = jobProfileId != null && profiles.hasValue && chosen == null;

    return SurfaceCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('CV du site', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text('Le CV que télécharge un visiteur.', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            // Reconstruit une fois la liste chargée : `initialValue` n'est lu qu'au départ.
            key: ValueKey('${profiles.hasValue}-${chosen?.id}'),
            // Un profil dépublié n'est plus dans la liste : affiché comme « Automatique ».
            initialValue: chosen?.id,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Profil métier proposé', errorText: jobProfileError),
            items: [
              const DropdownMenuItem(value: null, child: Text('Automatique (premier profil publié)')),
              for (final profile in list)
                DropdownMenuItem(
                  value: profile.id,
                  child: Text(profile.label.display, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: profiles.hasValue ? onJobProfileChanged : null,
          ),
          if (profiles.isLoading)
            const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator(minHeight: 2)),
          if (profiles.hasError)
            _Note(
              'Profils métier indisponibles.',
              action: TextButton(
                onPressed: () => ref.invalidate(publishedJobProfilesProvider),
                child: const Text('Réessayer'),
              ),
            ),
          if (unpublished)
            const _Note('Le profil choisi n\'est plus publié : le site propose le premier profil publié.'),
          const SizedBox(height: 16),
          Text('Source prioritaire', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<CvSource>(
            segments: [for (final value in CvSource.values) ButtonSegment(value: value, label: Text(value.label))],
            selected: {source},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onSourceChanged(selection.first),
          ),
          const SizedBox(height: 6),
          Text(
            sourceError ?? cvSourceExplanation(source),
            style: theme.textTheme.bodySmall?.copyWith(color: sourceError == null ? muted : theme.colorScheme.error),
          ),
          if (effective != null) ...[
            const SizedBox(height: 16),
            Text('PDF importés pour ${effective.label.display}', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            _PdfLine(locale: 'FR', file: effective.cvFiles.fr, fallback: effective.cvFiles.en == null ? null : 'EN'),
            _PdfLine(locale: 'EN', file: effective.cvFiles.en, fallback: effective.cvFiles.fr == null ? null : 'FR'),
            if (source == CvSource.uploaded && effective.cvFiles.fr == null && effective.cvFiles.en == null)
              const _Note('Aucun PDF importé : le CV généré sera servi.'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (context) => JobProfileFormScreen(id: effective.id)));
                  ref.invalidate(publishedJobProfilesProvider);
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Gérer les PDF'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PdfLine extends StatelessWidget {
  const _PdfLine({required this.locale, required this.file, required this.fallback});

  final String locale;
  final UploadedFile? file;

  /// Langue de repli disponible quand [file] manque.
  final String? fallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.appColors.muted;
    final text = file?.fileName ?? (fallback == null ? 'aucun' : 'aucun : repli sur le $fallback');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text(locale, style: theme.textTheme.labelMedium)),
          Icon(
            file == null ? Icons.remove_rounded : Icons.check_circle_rounded,
            size: 16,
            color: file == null ? muted : context.appColors.success,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: file == null ? muted : null),
            ),
          ),
        ],
      ),
    );
  }
}

/// Note d'avertissement (couleur d'accent secondaire de la palette).
class _Note extends StatelessWidget {
  const _Note(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = context.appColors.highlight;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
          ?action,
        ],
      ),
    );
  }
}
