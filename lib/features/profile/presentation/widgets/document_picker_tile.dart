import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../data/profile.dart';

/// Ligne de sélection pour un fichier déjà uploadé (CV PDF, musique) : nom du
/// fichier courant, remplacement, et retrait quand l'API le permet (§4.3).
class DocumentPickerTile extends StatelessWidget {
  const DocumentPickerTile({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.extensions,
    required this.maxBytes,
    required this.tooLargeLabel,
    required this.current,
    required this.pickedFile,
    required this.onPicked,
    this.onRemove,
    this.removing = false,
  });

  final IconData icon;
  final String label;
  final String hint;

  /// Extensions acceptées par le sélecteur (filtrées côté client seulement :
  /// l'API revalide le type réel du fichier).
  final List<String> extensions;
  final int maxBytes;
  final String tooLargeLabel;
  final UploadedFile? current;
  final PlatformFile? pickedFile;
  final ValueChanged<PlatformFile> onPicked;

  /// `null` : pas de bouton retirer (cas de la photo, remplaçable seulement).
  final Future<void> Function()? onRemove;
  final bool removing;

  Future<void> _pick(BuildContext context) async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: extensions);
    if (files.isEmpty) {
      return;
    }
    final file = files.single;
    final size = file.lengthSync() ?? await file.length();
    if (size != null && size > maxBytes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tooLargeLabel)));
      }
      return;
    }
    onPicked(file);
  }

  String? _formatSize(PlatformFile file) {
    final bytes = file.lengthSync();
    return bytes == null ? null : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPending = pickedFile != null;
    final hasCurrent = current != null;
    final pendingSize = hasPending ? _formatSize(pickedFile!) : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    hasPending
                        ? '${pickedFile!.name}${pendingSize != null ? ' ($pendingSize)' : ''} · sera envoyé à l\'enregistrement'
                        : hasCurrent
                            ? current!.fileName
                            : hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (onRemove != null && hasCurrent && !hasPending)
              IconButton(
                tooltip: 'Retirer',
                onPressed: removing ? null : onRemove,
                icon: removing
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline_rounded),
              ),
            TextButton(
              onPressed: () => _pick(context),
              child: Text(hasCurrent || hasPending ? 'Changer' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}
