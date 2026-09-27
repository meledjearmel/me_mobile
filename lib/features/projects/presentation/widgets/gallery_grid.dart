import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/project.dart';

/// Galerie d'un projet : vignettes existantes (retrait ciblé via
/// `DELETE .../gallery/{id}`) + images en attente d'envoi (§4.3).
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
      runSpacing: 10,
      children: [
        for (final image in images)
          _Thumbnail(
            image: NetworkImage(image.url),
            removing: removingId == image.id,
            onRemove: () => onRemove(image.id),
          ),
        for (final (index, file) in pendingFiles.indexed)
          _Thumbnail(image: FileImage(File(file.path)), onRemove: () => onRemovePending(index), isPending: true),
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
            child: Icon(Icons.add_photo_alternate_outlined, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.image, required this.onRemove, this.removing = false, this.isPending = false});

  final ImageProvider image;
  final VoidCallback onRemove;
  final bool removing;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Opacity(
              opacity: isPending ? 0.7 : 1,
              child: Image(image: image, width: 88, height: 88, fit: BoxFit.cover),
            ),
          ),
          if (isPending)
            const Positioned(
              left: 4,
              bottom: 4,
              child: Icon(Icons.upload_rounded, size: 16, color: Colors.white),
            ),
          Positioned(
            right: 2,
            top: 2,
            child: GestureDetector(
              onTap: removing ? null : onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: removing
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.close_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
