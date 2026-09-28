import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/utils/slugify.dart';
import '../../../../shared/widgets/feedback.dart';
import '../data/technology_icon.dart';
import '../data/technology_icon_repository.dart';
import 'technology_logo.dart';

final technologyIconsProvider = FutureProvider.autoDispose<List<TechnologyIcon>>(
  (ref) => ref.watch(technologyIconRepositoryProvider).list(),
);

/// Choix du logo d'une technologie (§4.3) : bibliothèque existante, import depuis
/// le catalogue Iconify, ou envoi d'un SVG. Se ferme sur le [TechnologyIcon] choisi.
class TechnologyIconPickerScreen extends ConsumerWidget {
  const TechnologyIconPickerScreen({super.key, this.selectedSlug});

  final String? selectedSlug;

  Future<void> _uploadSvg(BuildContext context, WidgetRef ref) async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['svg']);
    if (files.isEmpty || !context.mounted) {
      return;
    }
    final file = files.single;
    final size = file.lengthSync() ?? await file.length();
    if (size != null && size > TechnologyIconRepository.maxUploadBytes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le fichier dépasse 200 Ko.')));
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    final repository = ref.read(technologyIconRepositoryProvider);
    final icon = await _askNameAndRun(
      context,
      ref,
      title: 'Envoyer ce logo',
      initialSlug: slugify(file.name.replaceFirst(RegExp(r'\.svg$', caseSensitive: false), '')),
      run: (slug, theme) => repository.upload(
        slug: slug,
        theme: theme,
        file: dio.MultipartFile.fromFileSync(file.path!, filename: file.name),
      ),
    );
    if (icon != null && context.mounted) {
      Navigator.of(context).pop(icon);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Logo'),
          actions: [
            IconButton(
              tooltip: 'Envoyer un SVG',
              onPressed: () => _uploadSvg(context, ref),
              icon: const Icon(Icons.upload_file_rounded),
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Bibliothèque'), Tab(text: 'Catalogue')]),
        ),
        body: TabBarView(
          children: [
            _LibraryTab(selectedSlug: selectedSlug),
            const _CatalogTab(),
          ],
        ),
      ),
    );
  }
}

/// Demande le nom (slug) et le thème du logo, exécute [run] et renvoie le logo
/// tel qu'il figure ensuite dans la bibliothèque. `null` : annulé.
Future<TechnologyIcon?> _askNameAndRun(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String initialSlug,
  required Future<void> Function(String slug, LogoTheme theme) run,
}) async {
  final slug = await showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(title: title, initialSlug: initialSlug, run: run),
  );
  if (slug == null) {
    return null;
  }
  ref.invalidate(technologyIconsProvider);
  try {
    final icons = await ref.read(technologyIconsProvider.future);
    return icons.firstWhere((i) => i.slug == slug, orElse: () => TechnologyIcon(slug: slug, lightUrl: null, darkUrl: null));
  } on ApiException {
    return TechnologyIcon(slug: slug, lightUrl: null, darkUrl: null);
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initialSlug, required this.run});

  final String title;
  final String initialSlug;
  final Future<void> Function(String slug, LogoTheme theme) run;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _slug = TextEditingController(text: widget.initialSlug);
  LogoTheme _theme = LogoTheme.both;
  bool _busy = false;
  String? _slugError;
  String? _error;

  @override
  void dispose() {
    _slug.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final slug = _slug.text.trim();
    if (!TechnologyIconRepository.isValidSlug(slug)) {
      setState(() => _slugError = 'Minuscules, chiffres et tirets ; sans « -light » ni « -dark » final.');
      return;
    }
    setState(() {
      _busy = true;
      _slugError = null;
      _error = null;
    });
    try {
      await widget.run(slug, _theme);
      if (mounted) {
        Navigator.of(context).pop(slug);
      }
    } on ValidationException catch (e) {
      setState(() {
        _slugError = e.errorFor('slug');
        _error = _slugError == null ? (e.errorFor('file') ?? e.errorFor('icon') ?? e.message) : null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 12)],
            TextField(
              controller: _slug,
              autocorrect: false,
              maxLength: TechnologyIconRepository.maxSlugLength,
              decoration: InputDecoration(labelText: 'Nom du logo (slug)', errorText: _slugError, errorMaxLines: 3),
            ),
            const SizedBox(height: 8),
            Text('Thème', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<LogoTheme>(
              showSelectedIcon: false,
              segments: [for (final theme in LogoTheme.values) ButtonSegment(value: theme, label: Text(theme.label))],
              selected: {_theme},
              onSelectionChanged: _busy ? null : (value) => setState(() => _theme = value.single),
            ),
            const SizedBox(height: 6),
            Text(
              _theme == LogoTheme.both
                  ? 'Un logo monochrome est décliné automatiquement en clair et sombre.'
                  : 'Ajoute seulement la variante ${_theme.label.toLowerCase()} ; reprenez le slug d\'un logo existant pour compléter.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Valider'),
        ),
      ],
    );
  }
}

class _LibraryTab extends ConsumerStatefulWidget {
  const _LibraryTab({required this.selectedSlug});

  final String? selectedSlug;

  @override
  ConsumerState<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<_LibraryTab> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final icons = ref.watch(technologyIconsProvider);

    return icons.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error is ApiException ? error.message : 'Erreur.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => ref.invalidate(technologyIconsProvider), child: const Text('Réessayer')),
          ],
        ),
      ),
      data: (all) {
        final visible = [for (final icon in all) if (icon.slug.contains(_filter.toLowerCase())) icon];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                onChanged: (value) => setState(() => _filter = value.trim()),
                decoration: const InputDecoration(hintText: 'Filtrer la bibliothèque…', prefixIcon: Icon(Icons.search_rounded)),
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        all.isEmpty ? 'La bibliothèque est vide : importez un logo depuis le catalogue.' : 'Aucun logo.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 110,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final icon = visible[index];
                        final selected = icon.slug == widget.selectedSlug;
                        return Card(
                          shape: selected
                              ? RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                                )
                              : null,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.of(context).pop(icon),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TechnologyLogo(lightUrl: icon.lightUrl, darkUrl: icon.darkUrl, size: 44),
                                  const SizedBox(height: 6),
                                  Text(
                                    icon.slug,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _CatalogTab extends ConsumerStatefulWidget {
  const _CatalogTab();

  @override
  ConsumerState<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends ConsumerState<_CatalogTab> with AutomaticKeepAliveClientMixin {
  final _query = TextEditingController();
  Future<List<IconSearchResult>>? _results;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search() {
    final query = _query.text.trim();
    if (query.length < 2) {
      return;
    }
    setState(() => _results = ref.read(technologyIconRepositoryProvider).search(query));
  }

  Future<void> _import(IconSearchResult result) async {
    final repository = ref.read(technologyIconRepositoryProvider);
    final icon = await _askNameAndRun(
      context,
      ref,
      title: 'Importer « ${result.name} »',
      initialSlug: slugify(result.name),
      run: (slug, theme) => repository.import(icon: result.id, slug: slug, theme: theme),
    );
    if (icon != null && mounted) {
      Navigator.of(context).pop(icon);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Chercher un logo (2 lettres min.)…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(tooltip: 'Rechercher', onPressed: _search, icon: const Icon(Icons.arrow_forward_rounded)),
            ),
          ),
        ),
        Expanded(
          child: _results == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Cherchez dans les catalogues Logos, Devicon et Simple Icons, puis importez le logo dans votre bibliothèque.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : FutureBuilder<List<IconSearchResult>>(
                  future: _results,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      final error = snapshot.error;
                      return Center(child: Text(error is ApiException ? error.message : 'Erreur.'));
                    }
                    final results = snapshot.data!;
                    if (results.isEmpty) {
                      return const Center(child: Text('Aucun résultat.'));
                    }
                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final result = results[index];
                        return ListTile(
                          onTap: () => _import(result),
                          // Aperçu conseillé sur fond clair : la pastille garde les logos sombres lisibles.
                          leading: Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.all(4),
                            child: TechnologyLogo(lightUrl: result.previewUrl, darkUrl: result.previewUrl, size: 32),
                          ),
                          title: Text(result.name),
                          subtitle: Text(result.collection),
                          trailing: const Icon(Icons.download_rounded),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
