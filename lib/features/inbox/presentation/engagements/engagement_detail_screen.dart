import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/form_layout.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/utils/relative_date.dart';
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
    final muted = theme.colorScheme.onSurfaceVariant;

    return FutureBuilder<Engagement>(
      future: _future,
      builder: (context, snapshot) {
        final engagement = snapshot.connectionState == ConnectionState.done && !snapshot.hasError
            ? snapshot.data
            : null;

        return Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true,
          appBar: GlassAppBar(
            actions: [
              if (engagement != null)
                IconButton(
                  tooltip: 'Supprimer',
                  onPressed: () => _delete(engagement),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              const SizedBox(width: 8),
            ],
          ),
          bottomNavigationBar: engagement == null
              ? null
              : BottomFade(
                  child: SafeArea(
                    minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 56,
                          child: IconButton.filledTonal(
                            tooltip: engagement.status == EngagementStatus.newRequest
                                ? 'Marquer comme traitée'
                                : 'Remettre en nouvelle',
                            onPressed: _updating ? null : () => _toggleHandled(engagement),
                            style: IconButton.styleFrom(backgroundColor: context.appColors.card),
                            icon: _updating
                                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(
                                    engagement.status == EngagementStatus.newRequest
                                        ? Icons.done_all_rounded
                                        : Icons.mark_email_unread_outlined,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => launchUrl(Uri.parse('mailto:${engagement.email}')),
                            icon: const Icon(Icons.email_outlined),
                            label: const Text('Contacter par e-mail'),
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
                  FilledButton(
                    onPressed: () => setState(() => _future = ref.read(engagementRepositoryProvider).get(widget.id)),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
            _ => _EngagementBody(engagement: engagement!, muted: muted),
          },
        );
      },
    );
  }
}

class _EngagementBody extends StatelessWidget {
  const _EngagementBody({required this.engagement, required this.muted});

  final Engagement engagement;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHiring = engagement.type == EngagementType.hiring;

    return ListView(
      padding: pageInsets(context),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              InitialsTile(engagement.name, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(engagement.name, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    SelectableText(engagement.email, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        KeyFacts(
          facts: [
            (value: isHiring ? 'Embauche' : 'Freelance', label: 'Type'),
            (value: engagement.status.label, label: 'Statut'),
            if (engagement.createdAt != null) (value: relativeDate(engagement.createdAt!), label: 'Reçue'),
          ],
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (engagement.subject?.isNotEmpty == true) ...[
                Text(engagement.subject!, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
              ],
              _Field(label: 'Société', value: engagement.company),
              _Field(label: 'Profil visé', value: engagement.jobProfile?.label.display),
              _Field(label: 'Budget', value: engagement.budget),
              _Field(label: 'Contrat', value: engagement.contract),
              _Field(label: 'Délai souhaité', value: engagement.timeline),
              if (isHiring)
                _Field(
                  label: 'CV envoyé',
                  value: engagement.cvSentAt != null ? fullDate(engagement.cvSentAt!) : 'Pas encore',
                ),
              if (engagement.createdAt != null)
                Text(fullDate(engagement.createdAt!), style: theme.textTheme.labelSmall?.copyWith(color: muted)),
            ],
          ),
        ),
        if (engagement.message?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Message', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SelectableText(engagement.message!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
              ],
            ),
          ),
        ],
      ],
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
