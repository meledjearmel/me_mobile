import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/widgets/full_screen_image_viewer.dart';
import '../../data/project.dart';

/// Galerie d'un projet : vignettes existantes (retrait ciblé via
/// `DELETE .../gallery/{id}`, aperçu plein écran au tap) + images en attente
/// d'envoi (§4.3, §5).
class GalleryGrid extends StatelessWidget {
  const GalleryGrid({
    super.key,
    required this.images,
    required this.pendingFiles,
    required this.onAdd,
    required this.onRemove,
    required this.onRemovePending,
    this.removingId,
  });

  final List<GalleryImage> images;
  final List<XFile> pendingFiles;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<int> onRemovePending;
  final String? removingId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 10,
      runSpacing: 14,
      children: [
        for (final image in images)
          _Thumbnail(
            image: NetworkImage(image.url),
            onTap: () => FullScreenImageViewer.open(context, image.url, heroTag: 'gallery-${image.id}'),
            heroTag: 'gallery-${image.id}',
            removing: removingId == image.id,
            onRemove: () => onRemove(image.id),
          ),
        for (final (index, file) in pendingFiles.indexed)
          _Thumbnail(image: FileImage(File(file.path)), onRemovePending: () => onRemovePending(index), isPending: true),
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Semantics(
              button: true,
              label: 'Ajouter une image à la galerie',
              child: Icon(Icons.add_photo_alternate_outlined, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.image,
    this.onTap,
    this.heroTag,
    this.onRemove,
    this.onRemovePending,
    this.removing = false,
    this.isPending = false,
  });

  final ImageProvider image;
  final VoidCallback? onTap;
  final Object? heroTag;

  /// Image déjà uploadée : retire via l'API.
  final VoidCallback? onRemove;

  /// Image en attente d'envoi : retire localement, sans appel réseau.
  final VoidCallback? onRemovePending;
  final bool removing;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    // Décode à la taille réellement affichée plutôt qu'en pleine résolution :
    // une galerie de plusieurs images ne doit pas garder chacune en mémoire
    // à sa taille d'origine pour un aperçu de 88×88 (§5, performances).
    final devicePixels = (88 * MediaQuery.of(context).devicePixelRatio).round();
    final resized = ResizeImage(image, width: devicePixels, height: devicePixels);

    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isPending ? 0.7 : 1,
        child: Image(image: resized, width: 88, height: 88, fit: BoxFit.cover),
      ),
    );

    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          onTap == null
              ? thumbnail
              : InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: heroTag != null ? Hero(tag: heroTag!, child: thumbnail) : thumbnail,
                ),
          if (isPending)
            const Positioned(
              left: 4,
              bottom: 4,
              child: Icon(Icons.upload_rounded, size: 16, color: Colors.white),
            ),
          Positioned(
            right: -8,
            top: -8,
            child: IconButton(
              tooltip: removing ? 'Suppression…' : 'Retirer cette image',
              onPressed: removing ? null : (isPending ? onRemovePending : onRemove),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                minimumSize: const Size(44, 44),
              ),
              icon: removing
                  ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.close_rounded, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
