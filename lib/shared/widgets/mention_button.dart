import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/models/translated.dart';
import '../../features/blog/data/mentions.dart';

/// « @ Mentionner » sous un champ bilingue : cherche un projet, un article,
/// une technologie ou une expérience et ajoute `@[Nom](type:id)` à la fin du
/// texte, dans la ou les langues choisies. Le site en fait un lien.
class MentionButton extends StatelessWidget {
  const MentionButton({super.key, required this.value, required this.onChanged});

  final Translated value;
  final ValueChanged<Translated> onChanged;

  static String _append(String text, String markup) {
    if (text.trim().isEmpty) {
      return markup;
    }
    return text.endsWith(' ') || text.endsWith('\n') ? '$text$markup' : '$text $markup';
  }

  Future<void> _pick(BuildContext context) async {
    final result = await showModalBottomSheet<({Mentionable item, Set<String> locales})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _MentionSheet(),
    );
    if (result == null) {
      return;
    }
    final markup = result.item.markup;
    onChanged(
      Translated(
        fr: result.locales.contains('fr') ? _append(value.fr, markup) : value.fr,
        en: result.locales.contains('en') ? _append(value.en, markup) : value.en,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _pick(context),
        icon: const Icon(Icons.alternate_email_rounded, size: 18),
        label: const Text('Mentionner'),
      ),
    );
  }
}

class _MentionSheet extends ConsumerStatefulWidget {
  const _MentionSheet();

  @override
  ConsumerState<_MentionSheet> createState() => _MentionSheetState();
}

class _MentionSheetState extends ConsumerState<_MentionSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  late Future<List<Mentionable>> _results = _search('');
  Set<String> _locales = {'fr', 'en'};

  Future<List<Mentionable>> _search(String query) => ref.read(mentionRepositoryProvider).search(query);

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _results = _search(value.trim()));
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Mentionner', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _query,
                      autofocus: true,
                      onChanged: _onQueryChanged,
                      decoration: const InputDecoration(
                        hintText: 'Projet, article, technologie, expérience…',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('Ajouter en', style: muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SegmentedButton<String>(
                            multiSelectionEnabled: true,
                            emptySelectionAllowed: false,
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(value: 'fr', label: Text('Français')),
                              ButtonSegment(value: 'en', label: Text('Anglais')),
                            ],
                            selected: _locales,
                            onSelectionChanged: (selection) => setState(() => _locales = selection),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Mentionable>>(
                  future: _results,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      final error = snapshot.error;
                      return Center(child: Text(error is ApiException ? error.message : 'Recherche indisponible.'));
                    }
                    final items = snapshot.data!;
                    if (items.isEmpty) {
                      return Center(child: Text('Aucun résultat.', style: muted));
                    }
                    return ListView(
                      children: [
                        for (final item in items)
                          ListTile(
                            leading: Icon(item.icon),
                            title: Text(item.label),
                            subtitle: Text(
                              [item.kindLabel, if (item.hint?.isNotEmpty == true) item.hint!].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.pop(context, (item: item, locales: _locales)),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
