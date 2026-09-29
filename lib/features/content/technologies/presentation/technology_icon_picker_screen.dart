import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/utils/slugify.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/surfaces.dart';
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
        extendBodyBehindAppBar: true,
        appBar: GlassHeader(
          height: 120,
          child: Builder(
            builder: (context) => IconButtonTheme(
              data: IconButtonThemeData(style: GlassAppBar.roundButtonStyle(context)),
              child: Column(
                children: [
                  SizedBox(
                    height: GlassAppBar.toolbarHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          Expanded(
                            child: Text(
                              'Logo',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Envoyer un SVG',
                            onPressed: () => _uploadSvg(context, ref),
                            icon: const Icon(Icons.upload_file_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SegmentedTabs(
                      controller: DefaultTabController.of(context),
                      labels: const ['Bibliothèque', 'Catalogue'],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    return icons.firstWhere(
      (i) => i.slug == slug,
      orElse: () => TechnologyIcon(slug: slug, lightUrl: null, darkUrl: null),
    );
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
  final _filterController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

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
        final visible = [
          for (final icon in all)
            if (icon.slug.contains(_filter.toLowerCase())) icon,
        ];
        final insets = pageInsets(context);
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, insets.top, 16, 12),
              sliver: SliverToBoxAdapter(
                child: SearchPill(
                  controller: _filterController,
                  hintText: 'Filtrer la bibliothèque…',
                  onChanged: (value) => setState(() => _filter = value.trim()),
                  onSubmitted: (value) => setState(() => _filter = value.trim()),
                ),
              ),
            ),
            if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      all.isEmpty ? 'La bibliothèque est vide : importez un logo depuis le catalogue.' : 'Aucun logo.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, insets.bottom),
                sliver: SliverGrid.builder(
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
                    return Material(
                      color: context.appColors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: selected ? BorderSide(color: context.appColors.accent, width: 2) : BorderSide.none,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
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

    final insets = pageInsets(context);

    Widget message(String text) => SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      ),
    );

    return FutureBuilder<List<IconSearchResult>>(
      future: _results,
      builder: (context, snapshot) {
        final Widget content;
        if (_results == null) {
          content = message(
            'Cherchez dans les catalogues Logos, Devicon et Simple Icons, puis importez le logo dans votre bibliothèque.',
          );
        } else if (snapshot.connectionState != ConnectionState.done) {
          content = const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasError) {
          final error = snapshot.error;
          content = message(error is ApiException ? error.message : 'Erreur.');
        } else if (snapshot.data!.isEmpty) {
          content = message('Aucun résultat.');
        } else {
          final results = snapshot.data!;
          content = SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, insets.bottom),
            sliver: SliverList.separated(
              itemCount: results.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final result = results[index];
                return ListCardTile(
                  onTap: () => _import(result),
                  // Aperçu conseillé sur fond clair : la pastille garde les logos sombres lisibles.
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.all(6),
                    child: TechnologyLogo(lightUrl: result.previewUrl, darkUrl: result.previewUrl, size: 30),
                  ),
                  title: result.name,
                  subtitle: result.collection,
                  badge: const Icon(Icons.download_rounded, size: 18),
                );
              },
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, insets.top, 16, 12),
              sliver: SliverToBoxAdapter(
                child: SearchPill(
                  controller: _query,
                  hintText: 'Chercher un logo (2 lettres min.)…',
                  onSubmitted: (_) => _search(),
                ),
              ),
            ),
            content,
          ],
        );
      },
    );
  }
}
