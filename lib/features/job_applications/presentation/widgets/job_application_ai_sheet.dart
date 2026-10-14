import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../data/job_application.dart';
import '../../data/job_application_repository.dart';

typedef JobApplicationAiResult = ({JobApplicationDraft draft, String posting, String locale});

/// « Préparer avec l'IA » : le texte de l'offre et la langue de la page.
/// Renvoie la proposition et le texte de l'offre, ou `null` si on ferme.
Future<JobApplicationAiResult?> showJobApplicationAiSheet(
  BuildContext context, {
  required String initialPosting,
  required String initialLocale,
}) => showModalBottomSheet<JobApplicationAiResult>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  // Le retour est bloqué pendant la génération (PopScope de la feuille).
  builder: (context) => _AiSheet(initialPosting: initialPosting, initialLocale: initialLocale),
);

class _AiSheet extends ConsumerStatefulWidget {
  const _AiSheet({required this.initialPosting, required this.initialLocale});

  final String initialPosting;
  final String initialLocale;

  @override
  ConsumerState<_AiSheet> createState() => _AiSheetState();
}

class _AiSheetState extends ConsumerState<_AiSheet> {
  static const minPosting = 50;
  static const maxPosting = 20000;

  late final _posting = TextEditingController(text: widget.initialPosting);
  late String _locale = widget.initialLocale;
  bool _generating = false;
  String? _error;

  bool get _canGenerate => !_generating && _posting.text.trim().length >= minPosting;

  @override
  void dispose() {
    _posting.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final draft = await ref
          .read(jobApplicationRepositoryProvider)
          .draftWithAi(jobPosting: _posting.text, locale: _locale);
      if (mounted) {
        Navigator.of(context).pop((draft: draft, posting: _posting.text.trim(), locale: _locale));
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
              Text('Préparer avec l\'IA', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Colle le texte de l\'offre : l\'IA propose l\'entreprise, le poste, le mot d\'accompagnement, '
                'les projets à montrer et le profil métier du CV. Rien n\'est enregistré avant que tu valides.',
                style: muted,
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'fr', label: Text('Page en français')),
                  ButtonSegment(value: 'en', label: Text('En anglais')),
                ],
                selected: {_locale},
                onSelectionChanged: _generating ? null : (selection) => setState(() => _locale = selection.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _posting,
                enabled: !_generating,
                minLines: 6,
                maxLines: 14,
                maxLength: maxPosting,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Texte de l\'offre',
                  helperText: '50 caractères au moins.',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[const SizedBox(height: 8), ErrorBanner(_error!)],
              const SizedBox(height: 16),
              if (_generating) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text('Préparation en cours, cela peut prendre jusqu\'à une minute…', style: muted),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: _canGenerate ? _generate : null,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(_generating ? 'Préparation…' : 'Préparer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
