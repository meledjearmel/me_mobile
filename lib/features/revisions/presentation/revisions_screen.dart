import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/utils/relative_date.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/status_sheet.dart';
import '../../../shared/widgets/status_tones.dart';
import '../../../shared/widgets/surfaces.dart';
import '../data/revision.dart';
import '../data/revision_repository.dart';
import 'revision_detail_screen.dart';

final revisionListProvider = FutureProvider.autoDispose.family<List<Revision>, RevisionStatus>(
  (ref, status) => ref.watch(revisionRepositoryProvider).list(status),
);

/// « Révisions IA » : modifications de contenus publiés proposées par l'IA,
/// par statut. Rien ne change sur le site avant « Appliquer ».
class RevisionsScreen extends ConsumerStatefulWidget {
  const RevisionsScreen({super.key});

  @override
  ConsumerState<RevisionsScreen> createState() => _RevisionsScreenState();
}

class _RevisionsScreenState extends ConsumerState<RevisionsScreen> {
  RevisionStatus _status = RevisionStatus.pending;

  Future<void> _open(Revision revision) async {
    final decided = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (context) => RevisionDetailScreen(id: revision.id)));
    if (decided ?? false) {
      ref.invalidate(revisionListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final state = ref.watch(revisionListProvider(_status));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(),
      body: Builder(
        builder: (context) => RefreshIndicator(
          onRefresh: () => ref.refresh(revisionListProvider(_status).future),
          child: ListView(
            padding: pageInsets(context),
            children: [
              Text('Révisions IA', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text('Modifications de contenus en ligne proposées par l\'IA.', style: muted),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in RevisionStatus.values)
                    PillFilterChip(
                      label: status.label,
                      selected: _status == status,
                      onTap: () => setState(() => _status = status),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ...state.when(
                loading: () => const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (error, _) => [
                  Text(error is ApiException ? error.message : 'Erreur.'),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: () => ref.invalidate(revisionListProvider(_status)),
                      child: const Text('Réessayer'),
                    ),
                  ),
                ],
                data: (revisions) => revisions.isEmpty
                    ? [
                        Text(
                          _status == RevisionStatus.pending ? 'Aucune révision à relire.' : 'Aucune révision.',
                          style: muted,
                        ),
                      ]
                    : [
                        for (final revision in revisions) ...[
                          GestureDetector(
                            // Appui long : appliquer ou rejeter sans ouvrir la révision.
                            onLongPress: () => showStatusSheet(
                              context,
                              ref,
                              type: 'revision',
                              id: revision.id,
                              title: revision.title,
                              current: revision.status.wireValue,
                              options: [for (final s in RevisionStatus.values) (value: s.wireValue, label: s.label)],
                              onChanged: () => ref.invalidate(revisionListProvider),
                            ),
                            child: _RevisionTile(revision: revision, onTap: () => _open(revision)),
                          ),
                          const SizedBox(height: 10),
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

class _RevisionTile extends StatelessWidget {
  const _RevisionTile({required this.revision, required this.onTap});

  final Revision revision;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final date = revision.decidedAt ?? revision.createdAt;

    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(revision.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text([revision.contentTypeLabel, if (date != null) relativeDate(date)].join(' · '), style: muted),
          if (revision.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(revision.summary, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              TypedStatusBadge(type: 'revision', status: revision.status.wireValue, label: revision.status.label),
              if (revision.draftedBy != null)
                StatusBadge('IA · ${revision.draftedBy}', color: theme.colorScheme.tertiary),
            ],
          ),
        ],
      ),
    );
  }
}
