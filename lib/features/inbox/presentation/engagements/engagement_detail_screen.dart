import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../application/engagement_list_controller.dart';
import '../../data/engagement.dart';
import '../../data/engagement_repository.dart';

class EngagementDetailScreen extends ConsumerStatefulWidget {
  const EngagementDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<EngagementDetailScreen> createState() => _EngagementDetailScreenState();
}

class _EngagementDetailScreenState extends ConsumerState<EngagementDetailScreen> {
  late Future<Engagement> _future = ref.read(engagementRepositoryProvider).get(widget.id);
  bool _updating = false;

  Future<void> _toggleHandled(Engagement engagement) async {
    setState(() => _updating = true);
    try {
      final target = engagement.status == EngagementStatus.newRequest
          ? EngagementStatus.handled
          : EngagementStatus.newRequest;
      final updated = await ref.read(engagementRepositoryProvider).updateStatus(widget.id, target);
      ref.read(engagementListProvider.notifier).updateItem((e) => e.id == widget.id, (e) => updated);
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

  Future<void> _delete(Engagement engagement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer la demande de « ${engagement.name} » ?'),
        content: const Text('Elle part à la corbeille : vous pourrez la restaurer si besoin.'),
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
      await ref.read(engagementRepositoryProvider).delete(engagement.id);
      ref.read(engagementListProvider.notifier).removeItem((e) => e.id == engagement.id);
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
      appBar: AppBar(title: const Text('Demande de collaboration')),
      body: FutureBuilder<Engagement>(
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
                  FilledButton(
                    onPressed: () => setState(() => _future = ref.read(engagementRepositoryProvider).get(widget.id)),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final engagement = snapshot.data!;
          final isHiring = engagement.type == EngagementType.hiring;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(child: Text(engagement.name, style: theme.textTheme.headlineSmall)),
                  StatusBadge(
                    engagement.status.label,
                    prominent: engagement.status == EngagementStatus.newRequest,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(engagement.email, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
              if (engagement.createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  fullDate(engagement.createdAt!),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusBadge(isHiring ? 'Embauche' : 'Freelance'),
                  if (engagement.company?.isNotEmpty == true) StatusBadge(engagement.company!),
                  if (engagement.jobProfile != null) StatusBadge(engagement.jobProfile!.label.display),
                ],
              ),
              const SizedBox(height: 20),
              _Field(label: 'Sujet', value: engagement.subject),
              _Field(label: 'Budget', value: engagement.budget),
              _Field(label: 'Contrat', value: engagement.contract),
              _Field(label: 'Délai souhaité', value: engagement.timeline),
              if (isHiring)
                _Field(
                  label: 'CV envoyé',
                  value: engagement.cvSentAt != null ? fullDate(engagement.cvSentAt!) : 'Pas encore',
                ),
              if (engagement.message?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('Message', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(engagement.message!))),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse('mailto:${engagement.email}')),
                icon: const Icon(Icons.email_outlined),
                label: const Text('Contacter par e-mail'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _updating ? null : () => _toggleHandled(engagement),
                icon: _updating
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  engagement.status == EngagementStatus.newRequest ? 'Marquer comme traitée' : 'Remettre en nouvelle',
                ),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => _delete(engagement),
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

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value!)),
        ],
      ),
    );
  }
}
