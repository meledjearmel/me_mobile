import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_palette.dart';
import '../../../core/models/publication_status.dart';
import '../../../shared/widgets/resource_list_scaffold.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/post_list_controller.dart';
import '../data/post.dart';
import 'post_form_screen.dart';

class PostsListScreen extends ConsumerWidget {
  const PostsListScreen({super.key});

  void _openForm(BuildContext context, WidgetRef ref, {int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => PostFormScreen(id: id)));
    ref.invalidate(postListProvider);
  }

  static String _stateLabel(Post post) {
    if (post.status == PublicationStatus.draft) {
      return 'Brouillon';
    }
    if (post.isScheduled && post.publishedAt != null) {
      return 'Le ${DateFormat('d MMM', 'fr_FR').format(post.publishedAt!)}';
    }
    return 'En ligne';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(postListProvider);
    final notifier = ref.read(postListProvider.notifier);
    final currentStatus = state.value?.query.filters['status'] as String?;

    return ResourceListScaffold<Post>(
      title: 'Blog',
      searchHint: 'Titre, slug…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(postListProvider),
      onCreate: () => _openForm(context, ref),
      emptyIcon: Icons.article_outlined,
      emptyTitle: 'Aucun article pour l\'instant',
      emptyDescription: 'Lancez un brouillon avec le bouton +, puis rédigez-le dans l\'admin web.',
      filterChips: [
        for (final status in PublicationStatus.values)
          ChoiceChip(
            label: Text(status.label),
            selected: currentStatus == status.wireValue,
            onSelected: (_) =>
                notifier.setFilters(currentStatus == status.wireValue ? const {} : {'status': status.wireValue}),
            showCheckmark: false,
          ),
      ],
      itemBuilder: (context, post) => ListTile(
        onTap: () => _openForm(context, ref, id: post.id),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.square(
            dimension: 44,
            child: post.coverUrl != null
                ? Image.network(post.coverUrl!, fit: BoxFit.cover)
                : ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.article_outlined),
                  ),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(post.title.display, maxLines: 2, overflow: TextOverflow.ellipsis)),
            if (post.isFeatured)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.star_rounded, size: 18, color: context.appColors.accent),
              ),
          ],
        ),
        subtitle: Text(
          ['${post.readingMinutes} min de lecture', if (post.tags.isNotEmpty) post.tags.take(3).join(', ')].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: StatusBadge(_stateLabel(post), prominent: post.status == PublicationStatus.draft),
      ),
    );
  }
}
