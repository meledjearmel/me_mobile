import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/utils/date_only.dart';
import '../../../core/utils/relative_date.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/surfaces.dart';
import '../data/commercial_document.dart';
import 'document_form_screen.dart';
import 'documents_list_screen.dart';
import 'widgets/document_mail_sheet.dart';
import 'widgets/document_status_badge.dart';

/// Fiche d'un devis, d'une proforma ou d'une facture, avec les actions de son
/// cycle. Tout ce qui envoie un e-mail, numérote ou change le statut est confirmé.
class DocumentDetailScreen extends ConsumerStatefulWidget {
  const DocumentDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  late Future<CommercialDocument> _future = _repository.get(widget.id);

  /// Action en cours, pour l'indicateur et pour bloquer les autres.
  String? _busy;

  CommercialDocumentRepository get _repository => ref.read(commercialDocumentRepositoryProvider);

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<bool> _confirm(String title, String content, String action, {bool destructive = false}) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(
              style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error) : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  /// Lance une action ; sa réponse (le document à jour) remplace la fiche.
  Future<void> _run(String action, Future<CommercialDocument> Function() task, String done) async {
    setState(() => _busy = action);
    try {
      final updated = await task();
      setState(() => _future = Future.value(updated));
      _toast(done);
    } on ValidationException catch (e) {
      _toast(e.errors.values.expand((m) => m).firstOrNull ?? e.message);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  Future<void> _edit(CommercialDocument document) async {
    final saved = await Navigator.of(context)
        .push<CommercialDocument>(MaterialPageRoute(builder: (context) => DocumentFormScreen(document: document)));
    if (saved != null) {
      setState(() => _future = Future.value(saved));
    }
  }

  Future<void> _issue(CommercialDocument document) async {
    if (await _confirm(
      'Émettre ce ${document.type.label.toLowerCase()} ?',
      'Il reçoit le numéro suivant (${document.type.prefix}-…) et ne se modifie plus. Rien n\'est envoyé au client.',
      'Émettre',
    )) {
      await _run('issue', () => _repository.issue(document.id), '${document.type.label} émis.');
    }
  }

  Future<void> _mail(CommercialDocument document, {required bool reminder}) async {
    if (document.clientEmail?.trim().isEmpty ?? true) {
      _toast('Ajoute l\'e-mail du client au document avant de l\'envoyer.');
      return;
    }
    final mail = await showDocumentMailSheet(context, document: document, reminder: reminder);
    if (mail == null) {
      return;
    }
    await _run(
      reminder ? 'remind' : 'send',
      () => reminder ? _repository.remind(document.id, mail) : _repository.send(document.id, mail),
      reminder ? 'Relance envoyée.' : '${document.type.label} envoyé au client.',
    );
  }

  Future<void> _dismissReminder(CommercialDocument document) => _run(
    'dismiss',
    () => _repository.dismissReminder(document.id),
    'Relance écartée : elle pourra être suggérée à nouveau.',
  );

  Future<void> _setStatus(CommercialDocument document, DocumentStatus status) async {
    final (title, content) = switch (status) {
      DocumentStatus.accepted => (
        'Marquer le devis comme accepté ?',
        document.engagementId == null
            ? 'Tu pourras ensuite le convertir en facture.'
            : 'La demande liée est aussi marquée gagnée pour ${formatMoney(document.total, document.currency)}.',
      ),
      DocumentStatus.declined => (
        'Marquer le devis comme refusé ?',
        document.engagementId == null ? 'Il ne sera plus relancé.' : 'La demande liée est aussi marquée perdue.',
      ),
      DocumentStatus.paid => ('Marquer comme payé ?', 'Le montant compte dans l\'encaissé des statistiques.'),
      _ => ('Annuler ${document.displayName} ?', 'Il reste dans la numérotation, mais ne vaut plus rien.'),
    };
    if (await _confirm(title, content, status.label, destructive: status == DocumentStatus.cancelled)) {
      await _run('status', () => _repository.setStatus(document.id, status), 'Statut : ${status.label.toLowerCase()}.');
    }
  }

  Future<void> _convert(CommercialDocument document, DocumentType type) async {
    if (!await _confirm(
      'Créer ${type == DocumentType.invoice ? 'une facture' : 'une proforma'} ?',
      'Un brouillon reprend le client, le projet et les lignes de ${document.displayName}.',
      'Créer',
    )) {
      return;
    }
    setState(() => _busy = 'convert');
    try {
      final created = await _repository.convert(document.id, type);
      if (mounted) {
        await Navigator.of(context)
            .pushReplacement(MaterialPageRoute<void>(builder: (context) => DocumentDetailScreen(id: created.id)));
      }
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  Future<void> _delete(CommercialDocument document) async {
    if (!await _confirm(
      'Supprimer ce brouillon ?',
      'Il n\'a pas encore de numéro : rien ne reste.',
      'Supprimer',
      destructive: true,
    )) {
      return;
    }
    try {
      await _repository.delete(document.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  /// Le PDF passe par la feuille de partage : ouvrir, enregistrer ou envoyer.
  Future<void> _pdf(CommercialDocument document) async {
    final box = context.findRenderObject() as RenderBox?;
    setState(() => _busy = 'pdf');
    try {
      final bytes = await _repository.pdf(document.id);
      final name = '${document.number ?? '${document.type.wireValue}-brouillon-${document.id}'}.pdf';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: name)],
          fileNameOverrides: [name],
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CommercialDocument>(
      future: _future,
      builder: (context, snapshot) {
        final document = snapshot.connectionState == ConnectionState.done && !snapshot.hasError ? snapshot.data : null;
        return PopScope(
          canPop: _busy == null,
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: GlassAppBar(
              actions: [
                if (document != null)
                  IconButton(
                    tooltip: 'PDF',
                    onPressed: _busy != null ? null : () => _pdf(document),
                    icon: _busy == 'pdf'
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf_outlined),
                  ),
                if (document != null && document.isDraft)
                  IconButton(
                    tooltip: 'Supprimer le brouillon',
                    onPressed: _busy != null ? null : () => _delete(document),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            body: switch (snapshot) {
              _ when snapshot.connectionState != ConnectionState.done => const Center(
                child: CircularProgressIndicator(),
              ),
              _ when snapshot.hasError => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(snapshot.error is ApiException ? (snapshot.error! as ApiException).message : 'Erreur.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(() => _future = _repository.get(widget.id)),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
              _ => _body(context, document!),
            },
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, CommercialDocument document) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final busy = _busy != null;
    final deadline = document.deadline;

    Widget busyIcon(String action, IconData icon) => _busy == action
        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(icon, size: 18);

    final history = [
      if (document.createdAt != null) ('Créé', document.createdAt!),
      if (document.issuedAt != null) ('Émis', document.issuedAt!),
      if (document.sentAt != null) ('Envoyé au client', document.sentAt!),
      if (document.lastRemindedAt != null)
        ('Relancé${document.remindersCount > 1 ? ' (${document.remindersCount} fois)' : ''}', document.lastRemindedAt!),
      if (document.acceptedAt != null) ('Accepté', document.acceptedAt!),
      if (document.declinedAt != null) ('Refusé', document.declinedAt!),
      if (document.paidAt != null) ('Payé', document.paidAt!),
    ];

    return ListView(
      padding: pageInsets(context),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FormHeader(title: document.displayName, subtitle: '${document.client} · ${document.title}'),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Align(alignment: Alignment.centerLeft, child: DocumentStatusBadge(document)),
        ),
        const SizedBox(height: 16),
        KeyFacts(
          facts: [
            (value: formatMoney(document.total, document.currency), label: 'Total HT'),
            if (document.depositPercent > 0)
              (
                value: formatMoney(document.depositAmount, document.currency),
                label: 'Acompte ${document.depositPercent} %',
              ),
            (
              value: deadline == null ? '—' : formatDateOnly(deadline),
              label: document.isQuote ? 'Valable jusqu\'au' : 'Échéance',
            ),
          ],
        ),
        if (document.hasReminder) ...[
          const SizedBox(height: 12),
          SurfaceCard(
            radius: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Relance suggérée',
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.tertiary),
                ),
                const SizedBox(height: 4),
                Text(
                  document.isQuote
                      ? 'Le client n\'a pas encore répondu au devis.'
                      : 'La facture n\'est pas payée à l\'échéance.',
                  style: muted,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: busy ? null : () => _mail(document, reminder: true),
                      icon: busyIcon('remind', Icons.notifications_active_outlined),
                      label: const Text('Relancer'),
                    ),
                    TextButton(onPressed: busy ? null : () => _dismissReminder(document), child: const Text('Écarter')),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Actions', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (document.isDraft) ...[
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _edit(document),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Modifier'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _issue(document),
                      icon: busyIcon('issue', Icons.verified_outlined),
                      label: const Text('Émettre'),
                    ),
                  ],
                  if (document.isDraft || (document.isOpen && document.sentAt == null))
                    FilledButton.icon(
                      onPressed: busy ? null : () => _mail(document, reminder: false),
                      icon: busyIcon('send', Icons.send_rounded),
                      label: const Text('Envoyer au client'),
                    ),
                  if (document.isOpen && document.sentAt != null && !document.hasReminder)
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _mail(document, reminder: true),
                      icon: busyIcon('remind', Icons.notifications_active_outlined),
                      label: const Text('Relancer'),
                    ),
                  for (final status in document.nextStatuses)
                    OutlinedButton(
                      onPressed: busy ? null : () => _setStatus(document, status),
                      child: Text(switch (status) {
                        DocumentStatus.accepted => 'Accepté',
                        DocumentStatus.declined => 'Refusé',
                        DocumentStatus.paid => 'Payé',
                        _ => 'Annuler le document',
                      }),
                    ),
                  if (document.type != DocumentType.invoice &&
                      !document.isDraft &&
                      document.status != DocumentStatus.cancelled &&
                      document.status != DocumentStatus.declined) ...[
                    if (document.isQuote)
                      TextButton.icon(
                        onPressed: busy ? null : () => _convert(document, DocumentType.proforma),
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: const Text('Créer une proforma'),
                      ),
                    TextButton.icon(
                      onPressed: busy ? null : () => _convert(document, DocumentType.invoice),
                      icon: busyIcon('convert', Icons.receipt_long_outlined),
                      label: const Text('Créer la facture'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (document.publicUrl != null) ...[
          const SizedBox(height: 12),
          SurfaceCard(
            radius: 22,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lien d\'acceptation en ligne', style: theme.textTheme.titleSmall),
                      Text(document.publicUrl!, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copier le lien',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: document.publicUrl!));
                    _toast('Lien copié.');
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        FormSection(
          title: 'Lignes',
          summary: '${document.lines.length}',
          children: [
            for (final line in document.lines)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.label, style: theme.textTheme.titleSmall),
                        if (line.description?.isNotEmpty == true) Text(line.description!, style: muted),
                        Text(
                          line.unit == LineUnit.flat
                              ? 'Forfait'
                              : '${line.quantity == line.quantity.roundToDouble() ? line.quantity.round() : line.quantity} '
                                    '${line.unit.short} × ${formatMoney(line.unitPrice, document.currency)}',
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(formatMoney(line.amount, document.currency)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        FormSection(
          title: 'Client',
          initiallyExpanded: false,
          children: [
            Text(document.clientName, style: theme.textTheme.titleSmall),
            if (document.clientCompany?.isNotEmpty == true) Text(document.clientCompany!),
            Text(document.clientEmail ?? 'Pas d\'e-mail : impossible d\'envoyer le document.', style: muted),
            if (document.clientAddress?.isNotEmpty == true) Text(document.clientAddress!, style: muted),
          ],
        ),
        if (document.paymentTerms?.isNotEmpty == true || document.notes?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          FormSection(
            title: 'Conditions et notes',
            initiallyExpanded: false,
            children: [
              if (document.paymentTerms?.isNotEmpty == true) Text(document.paymentTerms!),
              if (document.notes?.isNotEmpty == true) Text(document.notes!, style: muted),
            ],
          ),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 12),
          FormSection(
            title: 'Historique',
            children: [
              for (final (label, date) in history)
                Row(
                  children: [
                    Expanded(child: Text(label)),
                    Text(relativeDate(date), style: muted),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}
