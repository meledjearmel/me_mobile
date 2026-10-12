import 'package:flutter/material.dart';

import '../../../content/github/data/github_repositories.dart';

/// Dépôt GitHub lié au projet : choisi parmi `available` de `GET /v1/github`,
/// avec « Aucun ». Un dépôt enregistré absent de la synchronisation reste
/// proposé pour ne pas être perdu à l'enregistrement.
class GitHubRepositoryField extends StatelessWidget {
  const GitHubRepositoryField({
    super.key,
    required this.available,
    required this.value,
    required this.onChanged,
    this.error,
  });

  final List<GitHubRepository> available;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? error;

  static const helper =
      'Montre l\'activité du dépôt sur la page du projet et renvoie vers le projet depuis la page À propos. '
      'Un dépôt privé n\'est jamais nommé publiquement.';

  @override
  Widget build(BuildContext context) {
    final missing = value != null && !available.any((r) => r.fullName == value);

    return DropdownButtonFormField<String?>(
      // Clé sur la valeur : DropdownButtonFormField ne relit pas `initialValue`.
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: 'Dépôt GitHub', helperText: helper, helperMaxLines: 4, errorText: error),
      items: [
        const DropdownMenuItem<String?>(child: Text('Aucun')),
        if (missing)
          DropdownMenuItem(
            value: value,
            child: Text(value!, overflow: TextOverflow.ellipsis),
          ),
        for (final repo in available)
          DropdownMenuItem(
            value: repo.fullName,
            child: Text(repo.isPrivate ? '${repo.fullName} (privé)' : repo.fullName, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
