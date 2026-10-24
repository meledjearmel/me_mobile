import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/surfaces.dart';
import '../../data/testimonial.dart';

/// 2 Mo : limite de l'API pour un fichier de sous-titres.
const maxCaptionBytes = 2 * 1024 * 1024;

/// Extensions acceptées : WebVTT, SRT ou transcription ElevenLabs minutée.
const captionExtensions = ['vtt', 'srt', 'json'];

/// Sous-titres d'une vidéo d'avis, une ligne par langue (FR, EN) : piste en
/// ligne, fichier choisi (envoyé à l'enregistrement) ou retrait demandé.
class TestimonialCaptionsCard extends StatelessWidget {
  const TestimonialCaptionsCard({
    super.key,
    required this.video,
    required this.pendingFiles,
    required this.removed,
    required this.errors,
    required this.onPicked,
    required this.onCancelPending,
    required this.onRemove,
    required this.onUndoRemove,
  });

  final TestimonialVideo? video;
  final Map<String, PlatformFile> pendingFiles;
  final Set<String> removed;

  /// Erreur 422 par langue (`video_captions_files.fr`).
  final Map<String, String> errors;
  final void Function(String language, PlatformFile file) onPicked;
  final ValueChanged<String> onCancelPending;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onUndoRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sous-titres', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            'Fichier .vtt, .srt ou .json ElevenLabs (2 Mo maximum), converti en WebVTT par le serveur.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          for (final language in TestimonialCaption.languages)
            _CaptionRow(
              language: language,
              online: video?.captionFor(language) != null,
              pending: pendingFiles[language],
              removed: removed.contains(language),
              error: errors[language],
              onPicked: (file) => onPicked(language, file),
              onCancelPending: () => onCancelPending(language),
              onRemove: () => onRemove(language),
              onUndoRemove: () => onUndoRemove(language),
            ),
        ],
      ),
    );
  }
}

class _CaptionRow extends StatelessWidget {
  const _CaptionRow({
    required this.language,
    required this.online,
    required this.pending,
    required this.removed,
    required this.error,
    required this.onPicked,
    required this.onCancelPending,
    required this.onRemove,
    required this.onUndoRemove,
  });

  final String language;
  final bool online;
  final PlatformFile? pending;
  final bool removed;
  final String? error;
  final ValueChanged<PlatformFile> onPicked;
  final VoidCallback onCancelPending;
  final VoidCallback onRemove;
  final VoidCallback onUndoRemove;

  Future<void> _pick(BuildContext context) async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: captionExtensions);
    if (files.isEmpty) {
      return;
    }
    final file = files.single;
    final size = file.lengthSync() ?? await file.length();
    if (size != null && size > maxCaptionBytes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Fichier de sous-titres trop lourd (2 Mo maximum).')));
      }
      return;
    }
    onPicked(file);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = this.pending;
    final String status;
    if (pending != null) {
      status = '${pending.name} · envoyé à l\'enregistrement';
    } else if (removed) {
      status = 'Retirée à l\'enregistrement';
    } else if (online) {
      status = 'Piste en ligne';
    } else {
      status = 'Aucune piste';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${language.toUpperCase()} · ${TestimonialCaption.labelFor(language)}'),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (pending != null)
                IconButton(tooltip: 'Annuler', icon: const Icon(Icons.close_rounded), onPressed: onCancelPending)
              else if (removed)
                TextButton(onPressed: onUndoRemove, child: const Text('Annuler'))
              else ...[
                TextButton(onPressed: () => _pick(context), child: Text(online ? 'Remplacer' : 'Choisir')),
                if (online)
                  IconButton(
                    tooltip: 'Retirer cette piste',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: onRemove,
                  ),
              ],
            ],
          ),
          if (error != null)
            Text(error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        ],
      ),
    );
  }
}
