import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/content_status_repository.dart';

typedef StatusOption = ({String value, String label});

/// Statuts atteignables depuis [current], comme l'API les accepte : un rendez-vous
/// refusé, une révision traitée ou un document payé ne reviennent pas en arrière.
List<String> allowedStatuses(String type, String current, List<String> all) => switch (type) {
  'appointment' =>
    const {
          'pending': ['confirmed', 'declined'],
          'confirmed': ['declined'],
        }[current] ??
        const [],
  'commercial_document' =>
    current == 'draft'
        ? const ['issued']
        : const ['paid', 'cancelled'].contains(current)
        ? const []
        : const ['accepted', 'declined', 'paid', 'cancelled'].where((s) => s != current).toList(),
  'revision' => current == 'pending' ? const ['applied', 'rejected'] : const [],
  _ => all.where((s) => s != current).toList(),
};

/// Changements à confirmer avant l'envoi : publication, emails, numérotation, contenu remplacé.
const Map<String, Map<String, String>> _confirmations = {
  'appointment': {
    'confirmed': 'Le visiteur reçoit un email de confirmation.',
    'declined': 'Le visiteur est prévenu par email et le créneau est libéré.',
  },
  'commercial_document': {
    'issued': 'Le document reçoit son numéro définitif et ne se modifie plus.',
    'cancelled': 'Le document est annulé, sans retour possible.',
  },
  'revision': {'applied': 'Le contenu est remplacé sur le site par la révision proposée.'},
};

/// Changement de statut rapide depuis une liste, à l'appui long (`PATCH /v1/status/{type}/{id}`) :
/// feuille des statuts possibles, confirmation des changements lourds, puis [onChanged].
/// [type] : `project`, `post`, `experience`, `education`, `certification`, `distinction`,
/// `uses_item`, `skill`, `service`, `domain`, `job_profile`, `contact`, `engagement`,
/// `job_application`, `comment`, `testimonial`, `appointment`, `commercial_document` ou `revision`.
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
  final allowed = allowedStatuses(type, current, [for (final o in options) o.value]);
  if (allowed.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('Ce statut ne peut plus changer.')));
    return;
  }
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
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final option in options)
            ListTile(
              leading: Icon(option.value == current ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(option.label),
              enabled: allowed.contains(option.value),
              onTap: () => Navigator.pop(context, option),
            ),
        ],
      ),
    ),
  );
  if (target == null || !context.mounted) {
    return;
  }
  final warning = target.value == 'published' ? 'Il sera visible sur le site.' : _confirmations[type]?[target.value];
  if (warning != null) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${target.label} « $title » ?'),
        content: Text(warning),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer')),
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
    // Publier sans l'anglais obligatoire, ou un changement impossible, est refusé.
    messenger.showSnackBar(SnackBar(content: Text(e.errors.values.expand((m) => m).firstOrNull ?? e.message)));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}
