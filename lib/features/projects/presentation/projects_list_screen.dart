import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/project_list_controller.dart';
import '../data/project.dart';
import 'project_form_screen.dart';

class ProjectsListScreen extends ConsumerStatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  ConsumerState<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends ConsumerState<ProjectsListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200) {
      ref.read(projectListProvider.notifier).loadMore();
    }
  }

  void _openForm({int? id}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => ProjectFormScreen(id: id)));
    ref.invalidate(projectListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Projets')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => ref.read(projectListProvider.notifier).setSearch(value),
              decoration: InputDecoration(
                hintText: 'Titre, slug…',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(projectListProvider.notifier).setSearch('');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'Publié',
                  isSelected: (state.value?.query.filters['status'] as String?) == 'published',
                  onTap: () => _toggleFilter('status', 'published'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Archivé',
                  isSelected: (state.value?.query.filters['status'] as String?) == 'archived',
                  onTap: () => _toggleFilter('status', 'archived'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'À la une',
                  isSelected: (state.value?.query.filters['is_featured'] as bool?) == true,
                  onTap: () => _toggleFilter('is_featured', true),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Open source',
                  isSelected: (state.value?.query.filters['is_open_source'] as bool?) == true,
                  onTap: () => _toggleFilter('is_open_source', true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Impossible de charger les projets.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => ref.invalidate(projectListProvider), child: const Text('Réessayer')),
                  ],
                ),
              ),
              data: (data) {
                if (data.items.isEmpty) {
                  return const Center(
                    child: ComingSoon(
                      icon: Icons.work_outline_rounded,
                      title: 'Aucun projet pour l\'instant',
                      description: 'Créez votre premier projet avec le bouton +.',
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(projectListProvider.notifier).refresh(),
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: data.items.length + (data.isLoadingMore ? 1 : 0),
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
                    itemBuilder: (context, index) {
                      if (index >= data.items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      final project = data.items[index];
                      return ListTile(
                        onTap: () => _openForm(id: project.id),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: theme.colorScheme.surfaceContainerHigh,
                          backgroundImage: project.coverUrl != null ? NetworkImage(project.coverUrl!) : null,
                          child: project.coverUrl == null
                              ? Icon(Icons.image_outlined, color: theme.colorScheme.onSurfaceVariant)
                              : null,
                        ),
                        title: Text(project.title.display, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(project.slug, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StatusBadge(
                              project.status.label,
                              prominent: project.status == ProjectStatus.published,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (project.isFeatured) const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                                if (project.isOpenSource)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(Icons.code_rounded, size: 16),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFilter(String key, Object value) {
    final current = Map<String, Object?>.from(ref.read(projectListProvider).value?.query.filters ?? const {});
    if (current[key] == value) {
      current.remove(key);
    } else {
      current[key] = value;
    }
    ref.read(projectListProvider.notifier).setFilters(current);
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant),
    );
  }
}
