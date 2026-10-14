import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/content_status_repository.dart';

typedef StatusOption = ({String value, String label});

/// Changement de statut rapide depuis une liste (`PATCH /v1/status/{type}/{id}`) :
/// feuille des statuts possibles, confirmation avant de publier, puis [onChanged].
/// [type] : `project`, `post`, `experience`, `education`, `certification`,
/// `uses_item`, `skill` ou `service`.
Future<void> showStatusSheet(
  BuildContext context,
  WidgetRef ref, {
  required String type,
  required int id,
  required String title,
  required String current,
  required List<StatusOption> options,
  required VoidCallback onChanged,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final target = await showModalBottomSheet<StatusOption>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium, maxLines: 2),
          ),
          for (final option in options)
            ListTile(
              leading: Icon(option.value == current ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(option.label),
              enabled: option.value != current,
              onTap: () => Navigator.pop(context, option),
            ),
        ],
      ),
    ),
  );
  if (target == null || !context.mounted) {
    return;
  }
  if (target.value == 'published') {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Publier « $title » ?'),
        content: const Text('Il sera visible sur le site.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Publier')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
  }
  try {
    await ref.read(contentStatusRepositoryProvider).update(type, id, target.value);
    messenger.showSnackBar(SnackBar(content: Text('Statut : ${target.label.toLowerCase()}.')));
    onChanged();
  } on ValidationException catch (e) {
    // Publier sans l'anglais obligatoire est refusé.
    messenger.showSnackBar(SnackBar(content: Text(e.errors.values.expand((m) => m).firstOrNull ?? e.message)));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}
