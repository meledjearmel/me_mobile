import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../content/github/data/github_repositories.dart';
import '../../data/project_draft.dart';
import '../../data/project_repository.dart';

/// « Pré-remplir avec l'IA » : un dépôt public (parmi ceux de `GET /v1/github`)
/// et/ou des notes. Renvoie la proposition, ou `null` si on ferme.
Future<ProjectDraft?> showAiDraftSheet(BuildContext context, {required List<GitHubRepository> repositories}) =>
    showModalBottomSheet<ProjectDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      // Le retour est bloqué pendant la génération (PopScope de [_AiDraftSheet]).
      builder: (context) => _AiDraftSheet(repositories: repositories.where((r) => !r.isPrivate).toList()),
    );

class _AiDraftSheet extends ConsumerStatefulWidget {
  const _AiDraftSheet({required this.repositories});

  /// Dépôts publics seulement : un dépôt privé est refusé par l'API.
  final List<GitHubRepository> repositories;

  @override
  ConsumerState<_AiDraftSheet> createState() => _AiDraftSheetState();
}

class _AiDraftSheetState extends ConsumerState<_AiDraftSheet> {
  static const maxNotes = 8000;

  String? _repository;
  final _notes = TextEditingController();
  bool _generating = false;
  String? _error;

  bool get _canGenerate => !_generating && (_repository != null || _notes.text.trim().isNotEmpty);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final draft = await ref
          .read(projectRepositoryProvider)
          .draftWithAi(githubRepository: _repository, notes: _notes.text);
      if (mounted) {
        Navigator.of(context).pop(draft);
      }
    } on ValidationException catch (e) {
      setState(() => _error = e.errors.values.expand((m) => m).firstOrNull ?? e.message);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return PopScope(
      canPop: !_generating,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pré-remplir avec l\'IA', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Propose les champs en français à partir d\'un dépôt public et/ou de tes notes. '
                'Rien n\'est enregistré avant que tu valides le formulaire.',
                style: muted,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _repository,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Dépôt GitHub public',
                  helperText: widget.repositories.isEmpty ? 'Aucun dépôt public synchronisé.' : null,
                ),
                items: [
                  const DropdownMenuItem<String?>(child: Text('Aucun')),
                  for (final repo in widget.repositories)
                    DropdownMenuItem(
                      value: repo.fullName,
                      child: Text(repo.fullName, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _generating ? null : (value) => setState(() => _repository = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                enabled: !_generating,
                minLines: 4,
                maxLines: 10,
                maxLength: maxNotes,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Besoin, client, dates, chiffres, choix techniques…',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[const SizedBox(height: 8), ErrorBanner(_error!)],
              const SizedBox(height: 16),
              if (_generating) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text('Génération en cours, cela peut prendre jusqu\'à une minute…', style: muted),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: _canGenerate ? _generate : null,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(_generating ? 'Génération…' : 'Générer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
