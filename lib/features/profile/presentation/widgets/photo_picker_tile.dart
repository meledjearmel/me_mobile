import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/widgets/image_source_sheet.dart';

/// Photo (profil ou CV) : aperçu rond, tap pour choisir galerie ou appareil
/// photo. Pas de bouton « retirer » : l'API ne permet que de remplacer (§4.3).
class PhotoPickerTile extends StatelessWidget {
  const PhotoPickerTile({
    super.key,
    required this.label,
    required this.currentUrl,
    required this.pickedFile,
    required this.onPicked,
  });

  final String label;
  final String? currentUrl;
  final XFile? pickedFile;
  final ValueChanged<XFile> onPicked;

  Future<void> _pick(BuildContext context) async {
    final source = await pickImageSource(context);
    if (source == null) {
      return;
    }
    // Redimensionnée et compressée côté client : reste sous la limite de 5 Mo
    // dans l'immense majorité des cas (§5).
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (file != null) {
      onPicked(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(48),
          child: CircleAvatar(
            radius: 48,
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            backgroundImage: pickedFile != null
                ? FileImage(File(pickedFile!.path))
                : (currentUrl != null ? NetworkImage(currentUrl!) : null) as ImageProvider?,
            child: pickedFile == null && currentUrl == null
                ? Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.onSurfaceVariant)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
