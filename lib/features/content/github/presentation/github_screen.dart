import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/form_layout.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../data/github_repositories.dart';

/// Dépôts GitHub présentés sur la page À propos : choix, ordre et
/// synchronisation. Sans sélection, le site choisit parmi mes dépôts publics.
class GitHubScreen extends ConsumerStatefulWidget {
  const GitHubScreen({super.key});

  @override
  ConsumerState<GitHubScreen> createState() => _GitHubScreenState();
}

class _GitHubScreenState extends ConsumerState<GitHubScreen> {
  late Future<GitHubSelection> _future = _load();
  GitHubSelection? _data;
  List<String> _selected = [];
  bool _dirty = false;
  bool _saving = false;
  bool _syncing = false;
  String? _error;

  Future<GitHubSelection> _load() async {
    final data = await ref.read(gitHubRepositoryProvider).get();
    _apply(data);
    return data;
  }

  void _apply(GitHubSelection data) {
    _data = data;
    _selected = [...data.selected];
    _dirty = false;
  }

  void _toggle(String fullName, bool selected) {
    setState(() {
      selected ? _selected.add(fullName) : _selected.remove(fullName);
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = await ref.read(gitHubRepositoryProvider).select(_selected);
      setState(() => _apply(data));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélection enregistrée.')));
      }
    } on ValidationException catch (e) {
      setState(() => _error = e.errors.values.expand((m) => m).firstOrNull ?? e.message);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      final data = await ref.read(gitHubRepositoryProvider).sync();
      // Garde une sélection en cours de modification.
      setState(() {
        final pending = _dirty ? _selected : null;
        _apply(data);
        if (pending != null) {
          _selected = pending;
          _dirty = true;
        }
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassAppBar(
        actions: [
          IconButton(
            tooltip: 'Synchroniser maintenant',
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      bottomNavigationBar: _data == null || !_dirty ? null : SaveBar(onPressed: _save, saving: _saving),
      body: FutureBuilder<GitHubSelection>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done && _data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && _data == null) {
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
          return _buildBody(context, _data!);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, GitHubSelection data) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final byName = {for (final repo in data.available) repo.fullName: repo};
    final unselected = data.available.where((r) => !_selected.contains(r.fullName)).toList();
    final full = _selected.length >= GitHubSelection.maxSelected;
    final insets = pageInsets(context, bottom: 120);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(insets.left, insets.top, insets.right, 0),
          sliver: SliverList.list(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: FormHeader(title: 'Dépôts GitHub', subtitle: 'Présentés sur la page À propos.'),
              ),
              const SizedBox(height: 12),
              Text(
                [
                  data.syncedAt == null ? 'Jamais synchronisé.' : 'Synchronisé ${relativeDate(data.syncedAt!)}.',
                  if (!data.hasToken) 'Sans jeton GitHub : ni contributions ni dépôts privés.',
                ].join(' '),
                style: muted,
              ),
              if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
              const SizedBox(height: 20),
              SectionHeader('Sélection (${_selected.length}/${GitHubSelection.maxSelected})'),
              const SizedBox(height: 4),
              Text(
                _selected.isEmpty
                    ? 'Aucune : le site choisit parmi vos dépôts publics.'
                    : 'Dans l\'ordre d\'affichage. Un dépôt privé s\'affiche sans lien.',
                style: muted,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: insets.left),
          sliver: SliverReorderableList(
            itemCount: _selected.length,
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                final item = _selected.removeAt(oldIndex);
                _selected.insert(newIndex, item);
                _dirty = true;
              });
            },
            itemBuilder: (context, index) {
              final name = _selected[index];
              final repo = byName[name];
              return Material(
                key: ValueKey(name),
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: const EdgeInsets.only(left: 4),
                  leading: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_indicator_rounded)),
                  title: Text(repo?.name ?? name),
                  subtitle: Text(repo == null ? 'Plus disponible sur GitHub' : _details(repo)),
                  trailing: IconButton(
                    tooltip: 'Retirer',
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    onPressed: () => _toggle(name, false),
                  ),
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(insets.left, 20, insets.right, insets.bottom),
          sliver: SliverList.list(
            children: [
              const SectionHeader('Disponibles'),
              const SizedBox(height: 8),
              if (unselected.isEmpty) Text('Aucun autre dépôt.', style: muted),
              for (final repo in unselected)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: false,
                  onChanged: full ? null : (_) => _toggle(repo.fullName, true),
                  title: Text(repo.fullName),
                  subtitle: Text(_details(repo)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _details(GitHubRepository repo) => [
    if (repo.language != null) repo.language!,
    '★ ${repo.stars}',
    if (repo.isPrivate) 'privé',
    if (repo.isContribution) 'contribution',
    if (repo.isArchived) 'archivé',
  ].join(' · ');
}
