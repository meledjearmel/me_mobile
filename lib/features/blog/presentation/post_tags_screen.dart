import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/translated.dart';
import '../../../shared/widgets/resource_list_scaffold.dart';
import '../application/blog_admin_controllers.dart';
import '../application/post_list_controller.dart';
import '../data/blog_admin.dart';
import '../data/post_repository.dart';

/// Tags du blog : corriger la traduction anglaise (faite par IA à la
/// création) ou supprimer un tag. Les tags se créent depuis les articles.
class PostTagsScreen extends ConsumerWidget {
  const PostTagsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, PostTag tag) async {
    final updated = await showDialog<PostTag>(
      context: context,
      builder: (context) => _TagDialog(tag: tag),
    );
    if (updated != null) {
      ref.read(postTagListProvider.notifier).updateItem((t) => t.id == tag.id, (t) => updated);
      ref.invalidate(postTagsProvider);
      ref.invalidate(postListProvider);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, PostTag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer le tag « ${tag.name.display} » ?'),
        content: Text(
          tag.postsCount == 0
              ? 'Suppression définitive.'
              : 'Suppression définitive : il sera retiré de ${tag.postsCount} article${tag.postsCount > 1 ? 's' : ''}.',
        ),
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
      await ref.read(blogAdminRepositoryProvider).deleteTag(tag.id);
      ref.read(postTagListProvider.notifier).removeItem((t) => t.id == tag.id);
      ref.invalidate(postTagsProvider);
      ref.invalidate(postListProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(postTagListProvider);
    final notifier = ref.read(postTagListProvider.notifier);

    return ResourceListScaffold<PostTag>(
      title: 'Tags du blog',
      searchHint: 'Nom, slug…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(postTagListProvider),
      emptyIcon: Icons.sell_outlined,
      emptyTitle: 'Aucun tag pour l\'instant',
      emptyDescription: 'Les tags se créent en les ajoutant à un article.',
      itemBuilder: (context, tag) => ListTile(
        onTap: () => _edit(context, ref, tag),
        leading: const Icon(Icons.sell_outlined),
        title: Text(tag.name.fr),
        subtitle: Text(
          '${tag.name.en.isEmpty ? 'Pas de traduction' : 'EN : ${tag.name.en}'} · '
          '${tag.postsCount} article${tag.postsCount > 1 ? 's' : ''}',
        ),
        trailing: IconButton(
          tooltip: 'Supprimer',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => _delete(context, ref, tag),
        ),
      ),
    );
  }
}

class _TagDialog extends ConsumerStatefulWidget {
  const _TagDialog({required this.tag});

  final PostTag tag;

  @override
  ConsumerState<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends ConsumerState<_TagDialog> {
  late final _fr = TextEditingController(text: widget.tag.name.fr);
  late final _en = TextEditingController(text: widget.tag.name.en);
  bool _saving = false;
  ValidationException? _validation;
  String? _error;

  @override
  void dispose() {
    _fr.dispose();
    _en.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _validation = null;
      _error = null;
    });
    try {
      final updated = await ref
          .read(blogAdminRepositoryProvider)
          .updateTag(widget.tag.id, Translated(fr: _fr.text.trim(), en: _en.text.trim()));
      if (mounted) {
        Navigator.pop(context, updated);
      }
    } on ValidationException catch (e) {
      setState(() => _validation = e);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _validation;
    return AlertDialog(
      title: const Text('Modifier le tag'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _fr,
            maxLength: 40,
            decoration: InputDecoration(labelText: 'Nom en français', errorText: v?.errorFor('name.fr')),
          ),
          TextField(
            controller: _en,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: 'Nom en anglais',
              helperText: 'Traduit par IA à la création.',
              errorText: v?.errorFor('name.en') ?? _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
