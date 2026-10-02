import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/translated.dart';
import '../../../core/utils/hex_color.dart';
import '../../../core/utils/slugify.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/image_source_sheet.dart';
import '../../../shared/widgets/multi_select_field.dart';
import '../../../shared/widgets/translated_field.dart';
import '../../content/data/reference_repository.dart';
import '../application/project_list_controller.dart';
import '../data/project.dart';
import '../data/project_repository.dart';
import '../../../shared/widgets/color_picker_field.dart';
import 'widgets/gallery_grid.dart';

const _maxImageBytes = 5 * 1024 * 1024;

/// Formulaire de création ou de modification d'un projet (§4.3) — la
/// ressource la plus complexe : relations, couverture, galerie avec
/// suppression ciblée. `id == null` : création.
class ProjectFormScreen extends ConsumerStatefulWidget {
  const ProjectFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  late Future<void> _future = _load();

  Translated _title = const Translated();
  Translated _projectContext = const Translated();
  Translated _realization = const Translated();
  Translated _result = const Translated();
  // Étude de cas : pas encore éditable ici, mais renvoyée telle quelle pour
  // ne pas être vidée à l'enregistrement.
  Translated _tagline = const Translated();
  Translated _role = const Translated();
  Translated _client = const Translated();
  Translated _platform = const Translated();
  List<KeyFigure> _keyFigures = const [];
  late final _slug = TextEditingController();
  late final _repoUrl = TextEditingController();
  late final _demoUrl = TextEditingController();
  late final _sortOrder = TextEditingController(text: '0');
  String? _accentColor;
  bool _isFeatured = false;
  bool _isOpenSource = false;
  ProjectStatus _status = ProjectStatus.published;
  List<int> _domainIds = [];
  List<int> _jobProfileIds = [];
  List<int> _technologyIds = [];
  List<int> _relatedProjectIds = [];

  String? _coverUrl;
  XFile? _coverPending;
  List<GalleryImage> _galleryImages = [];
  final List<XFile> _galleryPending = [];

  bool _dirty = false;
  bool _saving = false;
  bool _deleting = false;
  bool _removingCover = false;
  String? _removingGalleryId;
  double? _uploadProgress;
  String? _error;
  ValidationException? _validation;

  bool get _isEditing => widget.id != null;

  Future<void> _load() async {
    if (widget.id == null) {
      return;
    }
    final project = await ref.read(projectRepositoryProvider).get(widget.id!);
    _title = project.title;
    _projectContext = project.context;
    _realization = project.realization;
    _result = project.result;
    _tagline = project.tagline;
    _role = project.role;
    _client = project.client;
    _platform = project.platform;
    _keyFigures = project.keyFigures;
    _slug.text = project.slug;
    _repoUrl.text = project.repoUrl ?? '';
    _demoUrl.text = project.demoUrl ?? '';
    _sortOrder.text = '${project.sortOrder}';
    _accentColor = project.accentColor;
    _isFeatured = project.isFeatured;
    _isOpenSource = project.isOpenSource;
    _status = project.status;
    _domainIds = project.domains.map((d) => d.id).toList();
    _jobProfileIds = project.jobProfiles.map((j) => j.id).toList();
    _technologyIds = project.technologies.map((t) => t.id).toList();
    _relatedProjectIds = List.of(project.relatedProjectIds);
    _coverUrl = project.coverUrl;
    _galleryImages = List.of(project.gallery);
  }

  @override
  void dispose() {
    _slug.dispose();
    _repoUrl.dispose();
    _demoUrl.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  Future<bool> _confirmDiscard() async {
    if (!_dirty) {
      return true;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner les modifications ?'),
        content: const Text('Vos changements non enregistrés seront perdus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuer l\'édition')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Abandonner')),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _handlePopAttempt() async {
    if (await _confirmDiscard() && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _generateSlug() {
    if (_title.fr.trim().isEmpty) {
      return;
    }
    setState(() => _slug.text = slugify(_title.fr));
    _markDirty();
  }

  Future<void> _pickCover() async {
    final source = await pickImageSource(context);
    if (source == null) {
      return;
    }
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1920, imageQuality: 85);
    if (file == null) {
      return;
    }
    final size = await file.length();
    if (size > _maxImageBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Image trop lourde (5 Mo maximum). Choisissez-en une autre.')));
      }
      return;
    }
    setState(() => _coverPending = file);
    _markDirty();
  }

  Future<void> _removeCover() async {
    setState(() => _removingCover = true);
    try {
      final updated = await ref.read(projectRepositoryProvider).deleteCover(widget.id!);
      setState(() => _coverUrl = updated.coverUrl);
      ref.read(projectListProvider.notifier).updateItem((p) => p.id == widget.id, (p) => updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _removingCover = false);
      }
    }
  }

  Future<void> _addGalleryImages() async {
    final source = await pickImageSource(context);
    if (source == null) {
      return;
    }
    final picker = ImagePicker();
    final files = source == ImageSource.gallery
        ? await picker.pickMultiImage(maxWidth: 1920, imageQuality: 85)
        : [if (await picker.pickImage(source: source, maxWidth: 1920, imageQuality: 85) case final file?) file];
    if (files.isEmpty) {
      return;
    }

    final accepted = <XFile>[];
    var rejected = 0;
    for (final file in files) {
      if (await file.length() > _maxImageBytes) {
        rejected++;
      } else {
        accepted.add(file);
      }
    }

    setState(() => _galleryPending.addAll(accepted));
    if (rejected > 0 && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$rejected image(s) trop lourde(s) (5 Mo maximum) ignorée(s).')));
    }
    if (accepted.isNotEmpty) {
      _markDirty();
    }
  }

  Future<void> _removeGalleryImage(String id) async {
    setState(() => _removingGalleryId = id);
    try {
      final updated = await ref.read(projectRepositoryProvider).deleteGalleryImage(widget.id!, id);
      setState(() => _galleryImages = updated.gallery);
      ref.read(projectListProvider.notifier).updateItem((p) => p.id == widget.id, (p) => updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _removingGalleryId = null);
      }
    }
  }

  void _removePendingGalleryImage(int index) {
    setState(() => _galleryPending.removeAt(index));
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
      _uploadProgress = null;
    });
    try {
      await ref
          .read(projectRepositoryProvider)
          .save(
            id: widget.id,
            title: _title,
            slug: _slug.text.trim(),
            context: _projectContext,
            realization: _realization,
            result: _result,
            tagline: _tagline,
            role: _role,
            client: _client,
            platform: _platform,
            keyFigures: _keyFigures,
            accentColor: _accentColor?.isEmpty ?? true ? null : _accentColor,
            repoUrl: _repoUrl.text.trim().isEmpty ? null : _repoUrl.text.trim(),
            demoUrl: _demoUrl.text.trim().isEmpty ? null : _demoUrl.text.trim(),
            isFeatured: _isFeatured,
            isOpenSource: _isOpenSource,
            status: _status,
            sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
            domains: _domainIds,
            jobProfiles: _jobProfileIds,
            technologies: _technologyIds,
            relatedProjects: _relatedProjectIds,
            cover: _coverPending == null
                ? null
                : dio.MultipartFile.fromFileSync(_coverPending!.path, filename: _coverPending!.name),
            gallery: [for (final f in _galleryPending) dio.MultipartFile.fromFileSync(f.path, filename: f.name)],
            onProgress: (sent, total) {
              if (total > 0 && mounted) {
                setState(() => _uploadProgress = sent / total);
              }
            },
          );
      ref.invalidate(projectListProvider);
      _dirty = false;
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ValidationException catch (e) {
      setState(() => _validation = e);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer le projet « ${_title.display} » ?'),
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
    setState(() => _deleting = true);
    try {
      await ref.read(projectRepositoryProvider).delete(widget.id!);
      ref.read(projectListProvider.notifier).removeItem((p) => p.id == widget.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _validation;

    final domains = ref.watch(domainsRefProvider);
    final jobProfiles = ref.watch(jobProfilesRefProvider);
    final technologies = ref.watch(technologiesRefProvider);
    final relatedProjects = ref.watch(projectsLiteRefProvider);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handlePopAttempt();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: GlassAppBar(
          actions: [
            if (_isEditing)
              IconButton(
                tooltip: 'Supprimer',
                onPressed: _deleting ? null : _delete,
                icon: _deleting
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline_rounded),
              ),
            const SizedBox(width: 8),
          ],
        ),
        bottomNavigationBar: FutureBuilder<void>(
          future: _future,
          // Pas d'enregistrement tant que le formulaire n'est pas chargé.
          builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done && !snapshot.hasError
              ? SaveBar(onPressed: _save, saving: _saving, progress: _uploadProgress)
              : const SizedBox.shrink(),
        ),
        body: FutureBuilder<void>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
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

            bool anyError(List<String> keys) => keys.any((key) => v?.errorFor(key) != null);
            final galleryCount = _galleryImages.length + _galleryPending.length;
            const gap = SizedBox(height: 12);

            return ListView(
              padding: pageInsets(context),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FormHeader(
                    title: _isEditing && _title.display.isNotEmpty ? _title.display : 'Nouveau projet',
                    subtitle: _isEditing ? 'Projet' : 'Complète au moins le titre et le slug',
                  ),
                ),
                const SizedBox(height: 16),
                KeyFacts(
                  facts: [
                    (value: _status.label, label: 'Statut'),
                    (value: '${_technologyIds.length}', label: 'Technologies'),
                    (value: '$galleryCount', label: 'Images'),
                  ],
                ),
                const SizedBox(height: 12),
                if (_error != null) ...[ErrorBanner(_error!), gap],
                FormSection(
                  title: 'Couverture',
                  children: [
                    _CoverPicker(
                      url: _coverUrl,
                      pending: _coverPending,
                      onPick: _pickCover,
                      onRemove: _isEditing && _coverUrl != null && _coverPending == null ? _removeCover : null,
                      removing: _removingCover,
                    ),
                  ],
                ),
                gap,
                FormSection(
                  title: 'Général',
                  hasError: anyError(['title.fr', 'title.en', 'slug']),
                  children: [
                    TranslatedField(
                      label: 'Titre',
                      value: _title,
                      maxLength: 255,
                      errorFr: v?.errorFor('title.fr'),
                      errorEn: v?.errorFor('title.en'),
                      onChanged: (value) {
                        setState(() => _title = value);
                        _markDirty();
                      },
                    ),
                    TextField(
                      controller: _slug,
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(
                        labelText: 'Slug',
                        errorText: v?.errorFor('slug'),
                        suffixIcon: IconButton(
                          tooltip: 'Générer depuis le titre FR',
                          icon: const Icon(Icons.auto_fix_high_rounded),
                          onPressed: _generateSlug,
                        ),
                      ),
                    ),
                    SegmentedButton<ProjectStatus>(
                      segments: const [
                        ButtonSegment(value: ProjectStatus.published, label: Text('Publié')),
                        ButtonSegment(value: ProjectStatus.archived, label: Text('Archivé')),
                      ],
                      selected: {_status},
                      onSelectionChanged: (selection) {
                        setState(() => _status = selection.first);
                        _markDirty();
                      },
                    ),
                    Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('À la une'),
                          value: _isFeatured,
                          onChanged: (value) {
                            setState(() => _isFeatured = value);
                            _markDirty();
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Open source'),
                          value: _isOpenSource,
                          onChanged: (value) {
                            setState(() => _isOpenSource = value);
                            _markDirty();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                gap,
                FormSection(
                  title: 'Description',
                  hasError: anyError([
                    'context.fr',
                    'context.en',
                    'realization.fr',
                    'realization.en',
                    'result.fr',
                    'result.en',
                  ]),
                  children: [
                    TranslatedField(
                      label: 'Contexte',
                      value: _projectContext,
                      maxLines: 5,
                      errorFr: v?.errorFor('context.fr'),
                      errorEn: v?.errorFor('context.en'),
                      onChanged: (value) {
                        setState(() => _projectContext = value);
                        _markDirty();
                      },
                    ),
                    TranslatedField(
                      label: 'Réalisation',
                      value: _realization,
                      maxLines: 5,
                      errorFr: v?.errorFor('realization.fr'),
                      errorEn: v?.errorFor('realization.en'),
                      onChanged: (value) {
                        setState(() => _realization = value);
                        _markDirty();
                      },
                    ),
                    TranslatedField(
                      label: 'Résultat',
                      value: _result,
                      maxLines: 5,
                      errorFr: v?.errorFor('result.fr'),
                      errorEn: v?.errorFor('result.en'),
                      onChanged: (value) {
                        setState(() => _result = value);
                        _markDirty();
                      },
                    ),
                  ],
                ),
                gap,
                FormSection(
                  title: 'Classement',
                  summary:
                      '${_domainIds.length + _jobProfileIds.length + _technologyIds.length + _relatedProjectIds.length}',
                  initiallyExpanded: false,
                  children: [
                    domains.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) =>
                          Text('Domaines indisponibles : ${error is ApiException ? error.message : error}'),
                      data: (list) => MultiSelectField(
                        label: 'Domaines',
                        options: [
                          for (final d in list) (id: d.id, label: d.label.display, color: parseHexColor(d.color)),
                        ],
                        selectedIds: _domainIds,
                        onChanged: (ids) {
                          setState(() => _domainIds = ids);
                          _markDirty();
                        },
                      ),
                    ),
                    jobProfiles.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => const SizedBox.shrink(),
                      data: (list) => MultiSelectField(
                        label: 'Profils métier',
                        options: [for (final p in list) (id: p.id, label: p.label.display, color: null)],
                        selectedIds: _jobProfileIds,
                        onChanged: (ids) {
                          setState(() => _jobProfileIds = ids);
                          _markDirty();
                        },
                      ),
                    ),
                    technologies.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => const SizedBox.shrink(),
                      data: (list) => MultiSelectField(
                        label: 'Technologies',
                        options: [for (final t in list) (id: t.id, label: t.name, color: null)],
                        selectedIds: _technologyIds,
                        onChanged: (ids) {
                          setState(() => _technologyIds = ids);
                          _markDirty();
                        },
                      ),
                    ),
                    relatedProjects.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => const SizedBox.shrink(),
                      data: (list) => MultiSelectField(
                        label: 'Projets liés',
                        options: [
                          for (final p in list)
                            if (p.id != widget.id) (id: p.id, label: p.title.display, color: null),
                        ],
                        selectedIds: _relatedProjectIds,
                        onChanged: (ids) {
                          setState(() => _relatedProjectIds = ids);
                          _markDirty();
                        },
                      ),
                    ),
                  ],
                ),
                gap,
                FormSection(
                  title: 'Galerie',
                  summary: '$galleryCount',
                  initiallyExpanded: false,
                  children: [
                    GalleryGrid(
                      images: _galleryImages,
                      pendingFiles: _galleryPending,
                      onAdd: _addGalleryImages,
                      onRemove: _removeGalleryImage,
                      onRemovePending: _removePendingGalleryImage,
                      removingId: _removingGalleryId,
                    ),
                  ],
                ),
                gap,
                FormSection(
                  title: 'Liens et affichage',
                  initiallyExpanded: false,
                  hasError: anyError(['accent_color', 'repo_url', 'demo_url', 'sort_order']),
                  children: [
                    ColorPickerField(
                      value: _accentColor,
                      error: v?.errorFor('accent_color'),
                      onChanged: (value) {
                        setState(() => _accentColor = value);
                        _markDirty();
                      },
                    ),
                    TextField(
                      controller: _repoUrl,
                      keyboardType: TextInputType.url,
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(labelText: 'Dépôt de code (URL)', errorText: v?.errorFor('repo_url')),
                    ),
                    TextField(
                      controller: _demoUrl,
                      keyboardType: TextInputType.url,
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(labelText: 'Démo (URL)', errorText: v?.errorFor('demo_url')),
                    ),
                    TextField(
                      controller: _sortOrder,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(
                        labelText: 'Ordre d\'affichage',
                        errorText: v?.errorFor('sort_order'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.url,
    required this.pending,
    required this.onPick,
    required this.onRemove,
    required this.removing,
  });

  final String? url;
  final XFile? pending;
  final VoidCallback onPick;
  final Future<void> Function()? onRemove;
  final bool removing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onPick,
              child: pending != null
                  ? Image.file(File(pending!.path), fit: BoxFit.cover)
                  : url != null
                  ? Image.network(
                      url!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _placeholder(theme),
                    )
                  : _placeholder(theme),
            ),
          ),
          if (onRemove != null)
            Positioned(
              right: 8,
              top: 8,
              child: IconButton.filledTonal(
                onPressed: removing ? null : onRemove,
                icon: removing
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(ThemeData theme) => Container(
    color: theme.colorScheme.surfaceContainerHigh,
    alignment: Alignment.center,
    child: Icon(Icons.add_photo_alternate_outlined, size: 32, color: theme.colorScheme.onSurfaceVariant),
  );
}
