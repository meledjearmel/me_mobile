import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/status_badge.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Message')),
      body: FutureBuilder<Contact>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error is ApiException ? (snapshot.error! as ApiException).message : 'Erreur.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => setState(() => _future = _load()), child: const Text('Réessayer')),
                ],
              ),
            );
          }

          final contact = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(contact.name, style: theme.textTheme.headlineSmall),
                  ),
                  StatusBadge(contact.status.label, prominent: contact.status == ContactStatus.newMessage),
                ],
              ),
              const SizedBox(height: 4),
              Text(contact.email, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
              if (contact.createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  fullDate(contact.createdAt!),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 20),
              if (contact.subject?.isNotEmpty == true) ...[
                Text('Sujet', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(contact.subject!),
                const SizedBox(height: 16),
              ],
              Text('Message', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(contact.message),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _reply(contact),
                icon: const Icon(Icons.email_outlined),
                label: const Text('Répondre'),
              ),
              const SizedBox(height: 12),
              if (contact.status != ContactStatus.replied)
                OutlinedButton.icon(
                  onPressed: _updating ? null : _markReplied,
                  icon: _updating
                      ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Marquer comme répondu'),
                ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => _delete(contact),
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Supprimer'),
              ),
            ],
          );
        },
      ),
    );
  }
}
