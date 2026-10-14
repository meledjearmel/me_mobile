import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../data/post.dart';
import '../../data/post_repository.dart';

/// « Rédiger avec l'IA » : une consigne, et l'IA rédige le passage qui suit le
/// texte déjà écrit. Renvoie le HTML proposé, ou `null` si on ferme.
Future<String?> showWritePostSheet(
  BuildContext context, {
  required String title,
  required String excerpt,
  required String draftHtml,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _WritePostSheet(title: title, excerpt: excerpt, draftHtml: draftHtml),
);

class _WritePostSheet extends ConsumerStatefulWidget {
  const _WritePostSheet({required this.title, required this.excerpt, required this.draftHtml});

  final String title;
  final String excerpt;
  final String draftHtml;

  @override
  ConsumerState<_WritePostSheet> createState() => _WritePostSheetState();
}

class _WritePostSheetState extends ConsumerState<_WritePostSheet> {
  final _instruction = TextEditingController();
  bool _generating = false;
  String? _error;
  String? _result;

  @override
  void dispose() {
    _instruction.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final html = await ref
          .read(postRepositoryProvider)
          .writeWithAi(
            instruction: _instruction.text,
            locale: 'fr',
            context: widget.draftHtml,
            title: widget.title,
            excerpt: widget.excerpt,
          );
      setState(() => _result = html);
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
              Text('Rédiger avec l\'IA', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                widget.draftHtml.trim().isEmpty
                    ? 'L\'IA rédige un premier passage d\'après ta consigne, le titre et le résumé.'
                    : 'L\'IA rédige la suite de ton premier jet d\'après ta consigne.',
                style: muted,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _instruction,
                enabled: !_generating,
                minLines: 2,
                maxLines: 5,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Consigne',
                  hintText: 'Une introduction qui pose le problème, un exemple de code…',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[const SizedBox(height: 8), ErrorBanner(_error!)],
              if (_generating) ...[const SizedBox(height: 8), const LinearProgressIndicator()],
              if (_result != null) ...[
                const SizedBox(height: 12),
                Text('Proposition', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(maxHeight: 240),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(child: Text(htmlToPlainText(_result!))),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _generating || _instruction.text.trim().isEmpty ? null : _generate,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(_result == null ? 'Rédiger' : 'Autre proposition'),
                    ),
                  ),
                  if (_result != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _generating ? null : () => Navigator.pop(context, _result),
                        child: const Text('Ajouter au texte'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
