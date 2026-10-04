import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/env.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/form_layout.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../blog/presentation/post_form_screen.dart';
import '../../../dashboard/data/dashboard_repository.dart';
import '../../application/post_comment_list_controller.dart';
import '../../data/post_comment.dart';

/// Détail d'un commentaire : texte complet, article, approuver ou rejeter.
class CommentDetailScreen extends ConsumerStatefulWidget {
  const CommentDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<CommentDetailScreen> createState() => _CommentDetailScreenState();
}

class _CommentDetailScreenState extends ConsumerState<CommentDetailScreen> {
  late Future<PostComment> _future = ref.read(postCommentRepositoryProvider).get(widget.id);
  bool _updating = false;

  Future<void> _moderate(CommentStatus status) async {
    setState(() => _updating = true);
    try {
      final updated = await ref.read(postCommentRepositoryProvider).moderate(widget.id, status);
      ref.read(postCommentListProvider.notifier).updateItem((c) => c.id == widget.id, (c) => updated);
      ref.invalidate(dashboardProvider);
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

  Future<void> _delete(PostComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer le commentaire de « ${comment.authorName} » ?'),
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
      await ref.read(postCommentRepositoryProvider).delete(comment.id);
      ref.read(postCommentListProvider.notifier).removeItem((c) => c.id == comment.id);
      ref.invalidate(dashboardProvider);
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
    return FutureBuilder<PostComment>(
      future: _future,
      builder: (context, snapshot) {
        final comment = snapshot.connectionState == ConnectionState.done && !snapshot.hasError ? snapshot.data : null;

        return Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true,
          appBar: GlassAppBar(
            actions: [
              if (comment != null)
                IconButton(
                  tooltip: 'Supprimer',
                  onPressed: () => _delete(comment),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              const SizedBox(width: 8),
            ],
          ),
          bottomNavigationBar: comment == null
              ? null
              : BottomFade(
                  child: SafeArea(
                    minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _updating || comment.status == CommentStatus.rejected
                                ? null
                                : () => _moderate(CommentStatus.rejected),
                            icon: const Icon(Icons.visibility_off_outlined),
                            label: const Text('Rejeter'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _updating || comment.status == CommentStatus.approved
                                ? null
                                : () => _moderate(CommentStatus.approved),
                            icon: _updating
                                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.check_rounded),
                            label: const Text('Approuver'),
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
                    onPressed: () => setState(() => _future = ref.read(postCommentRepositoryProvider).get(widget.id)),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
            _ => _CommentBody(comment: comment!),
          },
        );
      },
    );
  }
}

class _CommentBody extends StatelessWidget {
  const _CommentBody({required this.comment});

  final PostComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return ListView(
      padding: pageInsets(context),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              InitialsTile(comment.authorName, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comment.authorName, style: theme.textTheme.headlineSmall),
                    if (comment.authorEmail?.isNotEmpty == true)
                      SelectableText(comment.authorEmail!, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        KeyFacts(
          facts: [
            (value: comment.status.label, label: 'Statut'),
            (value: comment.locale == 'en' ? 'Anglais' : 'Français', label: 'Langue'),
            if (comment.createdAt != null) (value: relativeDate(comment.createdAt!), label: 'Écrit'),
          ],
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(comment.body, style: theme.textTheme.bodyLarge?.copyWith(height: 1.55)),
              if (comment.createdAt != null) ...[
                const SizedBox(height: 12),
                Text(fullDate(comment.createdAt!), style: theme.textTheme.labelSmall?.copyWith(color: muted)),
              ],
            ],
          ),
        ),
        if (comment.postTitle != null) ...[
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Article', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(comment.postTitle!),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (comment.postId != null)
                      TextButton.icon(
                        onPressed: () =>
                            Navigator.of(context)
                                .push(MaterialPageRoute(builder: (context) => PostFormScreen(id: comment.postId))),
                        icon: const Icon(Icons.article_outlined),
                        label: const Text('Ouvrir l\'article'),
                      ),
                    if (comment.postSlug != null && comment.status == CommentStatus.approved)
                      TextButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse('${Env.siteUrl}/${comment.locale}/blog/${comment.postSlug}'),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Voir sur le site'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
