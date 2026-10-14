import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../data/commercial_document.dart';

/// Email d'envoi ([reminder] : de relance) : l'IA propose l'objet et le message,
/// tu les relis et les modifies, puis tu confirmes. Renvoie l'email validé,
/// ou `null` si on renonce. Rien n'est envoyé ici.
Future<DocumentMail?> showDocumentMailSheet(
  BuildContext context, {
  required CommercialDocument document,
  required bool reminder,
}) => showModalBottomSheet<DocumentMail>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _MailSheet(document: document, reminder: reminder),
);

class _MailSheet extends ConsumerStatefulWidget {
  const _MailSheet({required this.document, required this.reminder});

  final CommercialDocument document;
  final bool reminder;

  @override
  ConsumerState<_MailSheet> createState() => _MailSheetState();
}

class _MailSheetState extends ConsumerState<_MailSheet> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _suggesting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _suggest();
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _suggest() async {
    setState(() {
      _suggesting = true;
      _error = null;
    });
    try {
      final mail = await ref
          .read(commercialDocumentRepositoryProvider)
          .suggestMail(widget.document.id, reminder: widget.reminder);
      if (mounted) {
        setState(() {
          _subject.text = mail.subject;
          _message.text = mail.message;
        });
      }
    } on ApiException catch (e) {
      // L'IA indisponible n'empêche pas d'écrire le message soi-même.
      setState(() => _error = '${e.message} Tu peux écrire le message toi-même.');
    } finally {
      if (mounted) {
        setState(() => _suggesting = false);
      }
    }
  }

  Future<void> _confirm() async {
    final document = widget.document;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.reminder ? 'Envoyer la relance ?' : 'Envoyer ${document.displayName} ?'),
        content: Text(
          [
            'Un e-mail part tout de suite à ${document.clientEmail}, avec le PDF joint.',
            if (!widget.reminder && document.isDraft)
              'Le brouillon sera d\'abord émis : il reçoit son numéro et ne se modifie plus.',
            if (!widget.reminder && document.isQuote) 'Le client pourra accepter le devis en ligne.',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Envoyer')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop((subject: _subject.text.trim(), message: _message.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final ready = !_suggesting && _subject.text.trim().isNotEmpty && _message.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.reminder ? 'Relancer le client' : 'Envoyer au client', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('À ${widget.document.clientEmail} · relis le message avant l\'envoi.', style: muted),
            const SizedBox(height: 16),
            if (_suggesting) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text('L\'IA rédige l\'e-mail…', style: muted),
              const SizedBox(height: 12),
            ],
            if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 12)],
            TextField(
              controller: _subject,
              enabled: !_suggesting,
              maxLength: 150,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Objet'),
            ),
            TextField(
              controller: _message,
              enabled: !_suggesting,
              minLines: 6,
              maxLines: 14,
              maxLength: 5000,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _suggesting ? null : _suggest,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Autre proposition'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: ready ? _confirm : null,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Envoyer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
