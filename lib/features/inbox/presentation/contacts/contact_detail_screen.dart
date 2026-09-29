import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/form_layout.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/utils/relative_date.dart';
import '../../application/contact_list_controller.dart';
import '../../data/contact.dart';
import '../../data/contact_repository.dart';

/// Détail d'un message de contact. Un statut `new` passe automatiquement à
/// `read` côté serveur dès l'ouverture (§4.2).
class ContactDetailScreen extends ConsumerStatefulWidget {
  const ContactDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends ConsumerState<ContactDetailScreen> {
  late Future<Contact> _future = _load();
  bool _updating = false;

  Future<Contact> _load() async {
    final contact = await ref.read(contactRepositoryProvider).get(widget.id);
    // Le serveur vient de passer ce message à `read` : la liste doit suivre.
    ref.read(contactListProvider.notifier).updateItem((c) => c.id == widget.id, (c) => contact);
    return contact;
  }

  Future<void> _markReplied() async {
    setState(() => _updating = true);
    try {
      final updated = await ref.read(contactRepositoryProvider).updateStatus(widget.id, ContactStatus.replied);
      ref.read(contactListProvider.notifier).updateItem((c) => c.id == widget.id, (c) => updated);
      setState(() => _future = Future.value(updated));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _reply(Contact contact) async {
    final subject = Uri.encodeComponent(
      contact.subject?.isNotEmpty == true ? 'Re: ${contact.subject}' : 'Re: votre message',
    );
    final uri = Uri.parse('mailto:${contact.email}?subject=$subject');
    final opened = await launchUrl(uri);
    if (!opened) {
      return;
    }
    if (contact.status != ContactStatus.replied && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Marquer comme répondu ?'),
          content: const Text('Le message passera au statut « Répondu ».'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Pas maintenant')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Marquer comme répondu')),
          ],
        ),
      );
      if (confirmed == true) {
        await _markReplied();
      }
    }
  }

  Future<void> _delete(Contact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer le message de « ${contact.name} » ?'),
        content: const Text('Il part à la corbeille : vous pourrez le restaurer si besoin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(contactRepositoryProvider).delete(contact.id);
      ref.read(contactListProvider.notifier).removeItem((c) => c.id == contact.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return FutureBuilder<Contact>(
      future: _future,
      builder: (context, snapshot) {
        final contact = snapshot.connectionState == ConnectionState.done && !snapshot.hasError ? snapshot.data : null;

        return Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true,
          appBar: GlassAppBar(
            actions: [
              if (contact != null)
                IconButton(
                  tooltip: 'Supprimer',
                  onPressed: () => _delete(contact),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              const SizedBox(width: 8),
            ],
          ),
          bottomNavigationBar: contact == null
              ? null
              : BottomFade(
                  child: SafeArea(
                    minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        if (contact.status != ContactStatus.replied) ...[
                          SizedBox.square(
                            dimension: 56,
                            child: IconButton.filledTonal(
                              tooltip: 'Marquer comme répondu',
                              onPressed: _updating ? null : _markReplied,
                              style: IconButton.styleFrom(backgroundColor: context.appColors.card),
                              icon: _updating
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.done_all_rounded),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _reply(contact),
                            icon: const Icon(Icons.reply_rounded),
                            label: const Text('Répondre'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          body: switch (snapshot) {
            _ when snapshot.connectionState != ConnectionState.done => const Center(child: CircularProgressIndicator()),
            _ when snapshot.hasError => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error is ApiException ? (snapshot.error! as ApiException).message : 'Erreur.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => setState(() => _future = _load()), child: const Text('Réessayer')),
                ],
              ),
            ),
            _ => PageListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      InitialsTile(contact!.name, size: 52),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(contact.name, style: theme.textTheme.headlineSmall),
                            const SizedBox(height: 2),
                            SelectableText(contact.email, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                KeyFacts(
                  facts: [
                    (value: contact.status.label, label: 'Statut'),
                    if (contact.createdAt != null) (value: relativeDate(contact.createdAt!), label: 'Reçu'),
                  ],
                ),
                const SizedBox(height: 12),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (contact.subject?.isNotEmpty == true) ...[
                        Text(contact.subject!, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 10),
                      ],
                      SelectableText(contact.message, style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
                      if (contact.createdAt != null) ...[
                        const SizedBox(height: 14),
                        Text(fullDate(contact.createdAt!), style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          },
        );
      },
    );
  }
}
