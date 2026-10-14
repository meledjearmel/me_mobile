import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/env.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/models/publication_status.dart';
import '../../../core/models/translated.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/image_source_sheet.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../../shared/widgets/translated_field.dart';
import '../../profile/presentation/widgets/photo_picker_tile.dart';
import '../application/post_list_controller.dart';
import '../data/post.dart';
import '../data/post_repository.dart';
import 'post_distribution_screen.dart';
import 'widgets/write_post_sheet.dart';

const _maxTags = 8;

/// Gestion d'un article (§ blog). `id == null` : nouveau brouillon, lancé
/// depuis un premier jet. Le corps HTML se rédige dans l'admin web : un
/// article existant renvoie son corps tel quel.
class PostFormScreen extends ConsumerStatefulWidget {
  const PostFormScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends ConsumerState<PostFormScreen> {
  late Future<void> _future = _load();

  Post? _post;
  Translated _title = const Translated();
  late final _slug = TextEditingController();
  Translated _excerpt = const Translated();
  late final _draft = TextEditingController();
  List<String> _tags = [];
  late final _series = TextEditingController();
  late final _seriesPosition = TextEditingController();
  bool _isFeatured = false;
  PublicationStatus _status = PublicationStatus.draft;
  DateTime? _publishedAt;
  XFile? _coverPending;

  /// Le slug suit le titre tant qu'il n'a pas été modifié à la main.
  bool _slugEdited = false;

  /// Premier jet en HTML après « Rédiger avec l'IA » (garde titres, listes, code) ;
  /// `null` dès qu'on retouche le texte à la main, qui repart alors en paragraphes simples.
  String? _draftHtml;

  /// Images ajoutées au premier jet (adresses publiques), insérées à la fin du contenu.
  final List<String> _draftImages = [];
  bool _uploadingImage = false;

  /// Corps modifié dans l'app (traduction anglaise), envoyé à la place du corps chargé.
  Translated? _bodyOverride;
  double? _translateProgress;

  bool _dirty = false;
  bool _saving = false;
  bool _deleting = false;
  bool _removingCover = false;
  double? _uploadProgress;
  String? _error;
  ValidationException? _validation;

  bool get _isEditing => widget.id != null;

  Future<void> _load() async {
    if (widget.id == null) {
      return;
    }
    final post = await ref.read(postRepositoryProvider).get(widget.id!);
    _post = post;
    _title = post.title;
    _slug.text = post.slug;
    _slugEdited = true;
    _excerpt = post.excerpt;
    _tags = [...post.tags];
    _series.text = post.series ?? '';
    _seriesPosition.text = post.seriesPosition?.toString() ?? '';
    _isFeatured = post.isFeatured;
    _status = post.status;
    _publishedAt = post.publishedAt;
  }

  @override
  void dispose() {
    _slug.dispose();
    _draft.dispose();
    _series.dispose();
    _seriesPosition.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  String get _draftBodyHtml => [
    _draftHtml ?? plainTextToHtml(_draft.text),
    for (final url in _draftImages)
      '<figure><img src="${const HtmlEscape(HtmlEscapeMode.attribute).convert(url)}" alt=""></figure>',
  ].join();

  Future<void> _writeWithAi() async {
    final html = await showWritePostSheet(
      context,
      title: _title.fr,
      excerpt: _excerpt.fr,
      draftHtml: _draftHtml ?? plainTextToHtml(_draft.text),
    );
    if (html == null) {
      return;
    }
    setState(() {
      _draftHtml = '${_draftHtml ?? plainTextToHtml(_draft.text)}$html';
      _draft.text = htmlToPlainText(_draftHtml!);
    });
    _markDirty();
  }

  Future<void> _addDraftImage() async {
    final source = await pickImageSource(context);
    if (source == null) {
      return;
    }
    final file = await ImagePicker().pickImage(source: source, maxWidth: 2400, imageQuality: 85);
    if (file == null) {
      return;
    }
    if (await file.length() > 5 * 1024 * 1024) {
      _toast('Image trop lourde (5 Mo maximum).');
      return;
    }
    setState(() => _uploadingImage = true);
    try {
      final url = await ref
          .read(postRepositoryProvider)
          .uploadImage(await dio.MultipartFile.fromFile(file.path, filename: file.name));
      setState(() => _draftImages.add(url));
      _markDirty();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  /// Traduit le corps français en anglais, bloc par bloc ; à enregistrer ensuite.
  Future<void> _translateBody() async {
    final body = _bodyOverride ?? _post!.body;
    if (body.en.trim().isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remplacer la version anglaise ?'),
          content: const Text(
            'L\'IA traduit à nouveau tout le contenu français. Rien n\'est enregistré avant que tu valides.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Traduire')),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }
    setState(() => _translateProgress = 0);
    try {
      final english = await ref
          .read(postRepositoryProvider)
          .translateHtml(
            html: body.fr,
            sourceLocale: 'fr',
            targetLocale: 'en',
            onProgress: (done, total) {
              if (mounted && total > 0) {
                setState(() => _translateProgress = done / total);
              }
            },
          );
      setState(() => _bodyOverride = body.copyWith(en: english));
      _markDirty();
      _toast('Version anglaise prête : enregistre pour la garder.');
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) {
        setState(() => _translateProgress = null);
      }
    }
  }

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _handlePopAttempt() async {
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
    if (leave == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
      _uploadProgress = null;
    });
    final pending = _coverPending;
    try {
      final saved = await ref
          .read(postRepositoryProvider)
          .save(
            id: widget.id,
            title: _title,
            slug: _slug.text.trim(),
            excerpt: _excerpt,
            // Corps existant renvoyé tel quel (ou traduit) ; nouveau : le premier jet.
            body: _bodyOverride ?? _post?.body ?? Translated(fr: _draftBodyHtml),
            isFeatured: _isFeatured,
            status: _status,
            publishedAt: _publishedAt,
            tags: _tags,
            series: _series.text.trim().isEmpty ? null : _series.text.trim(),
            seriesPosition: int.tryParse(_seriesPosition.text.trim()),
            cover: pending == null ? null : await dio.MultipartFile.fromFile(pending.path, filename: pending.name),
            onProgress: pending == null
                ? null
                : (sent, total) {
                    if (total > 0 && mounted) {
                      setState(() => _uploadProgress = sent / total);
                    }
                  },
          );
      ref.invalidate(postListProvider);
      ref.invalidate(postTagsProvider);
      _dirty = false;
      if (!mounted) {
        return;
      }
      if (_isEditing) {
        Navigator.of(context).pop();
      } else {
        // Brouillon créé : on reste sur l'article pour l'ouvrir dans l'admin web.
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => PostFormScreen(id: saved.id)));
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Brouillon créé : terminez sa rédaction dans l\'admin web.')));
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

  Future<void> _removeCover() async {
    setState(() => _removingCover = true);
    try {
      final updated = await ref.read(postRepositoryProvider).deleteCover(widget.id!);
      setState(() => _post = updated);
      ref.invalidate(postListProvider);
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

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer l\'article « ${_title.display} » ?'),
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
      await ref.read(postRepositoryProvider).delete(widget.id!);
      ref.read(postListProvider.notifier).removeItem((p) => p.id == widget.id);
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

  Future<void> _pickPublishedAt() async {
    final now = DateTime.now();
    final initial = _publishedAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) {
      return;
    }
    setState(() => _publishedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
    _markDirty();
  }

  void _openAdmin() =>
      launchUrl(Uri.parse('${Env.siteUrl}/admin/posts/${widget.id}/edit'), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
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
            if (_isEditing) ...[
              IconButton(
                tooltip: 'Diffusion : republication et partage',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => PostDistributionScreen(
                      postId: widget.id!,
                      title: _title.display,
                      isPublished: _status == PublicationStatus.published,
                    ),
                  ),
                ),
                icon: const Icon(Icons.campaign_outlined),
              ),
              IconButton(
                tooltip: 'Rédiger dans l\'admin web',
                onPressed: _openAdmin,
                icon: const Icon(Icons.open_in_new_rounded),
              ),
              IconButton(
                tooltip: 'Supprimer',
                onPressed: _deleting ? null : _delete,
                icon: _deleting
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ],
        ),
        bottomNavigationBar: FutureBuilder<void>(
          future: _future,
          builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done && !snapshot.hasError
              ? SaveBar(
                  onPressed: _save,
                  saving: _saving,
                  progress: _uploadProgress,
                  label: _isEditing ? 'Enregistrer' : 'Créer le brouillon',
                )
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
            return _buildForm(context);
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final v = _validation;
    final post = _post;

    return ListView(
      padding: pageInsets(context, bottom: 120),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FormHeader(
            title: _isEditing ? 'Article' : 'Nouveau brouillon',
            subtitle: _isEditing ? null : 'Lancez l\'article ici, terminez sa rédaction dans l\'admin web.',
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
        if (v != null && v.errors.isEmpty) ...[ErrorBanner(v.message), const SizedBox(height: 16)],
        SurfaceCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TranslatedField(
                label: 'Titre (anglais facultatif)',
                value: _title,
                maxLength: 255,
                errorFr: v?.errorFor('title.fr'),
                errorEn: v?.errorFor('title.en'),
                onChanged: (value) {
                  setState(() {
                    _title = value;
                    if (!_slugEdited) {
                      _slug.text = slugify(value.fr);
                    }
                  });
                  _markDirty();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _slug,
                onChanged: (_) {
                  _slugEdited = true;
                  _markDirty();
                },
                decoration: InputDecoration(
                  labelText: 'Slug (adresse de l\'article)',
                  prefixText: '/blog/',
                  errorText: v?.errorFor('slug'),
                ),
              ),
              const SizedBox(height: 12),
              TranslatedField(
                label: 'Résumé (facultatif)',
                value: _excerpt,
                maxLines: 3,
                maxLength: 300,
                errorFr: v?.errorFor('excerpt.fr'),
                errorEn: v?.errorFor('excerpt.en'),
                onChanged: (value) {
                  setState(() => _excerpt = value);
                  _markDirty();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Contenu', style: theme.textTheme.labelLarge)),
                  if (post != null)
                    Text(
                      '${post.readingMinutes} min de lecture · ${post.viewsCount} lecture${post.viewsCount > 1 ? 's' : ''}',
                      style: muted,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (post == null) ...[
                TextField(
                  controller: _draft,
                  minLines: 5,
                  maxLines: 12,
                  onChanged: (_) {
                    // Une retouche à la main repasse le texte en paragraphes simples.
                    _draftHtml = null;
                    _markDirty();
                  },
                  decoration: InputDecoration(
                    labelText: 'Premier jet',
                    hintText: 'Idées, plan, premiers paragraphes…',
                    alignLabelWithHint: true,
                    helperText: _draftHtml != null
                        ? 'Mise en forme de l\'IA conservée ; une retouche ici la remplace par des paragraphes simples.'
                        : 'Une ligne vide sépare deux paragraphes. La mise en forme se fait dans l\'admin web.',
                    helperMaxLines: 2,
                    errorText: v?.errorFor('body.fr'),
                  ),
                ),
                if (_draftImages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final url in _draftImages)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(url, width: 88, height: 88, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Retirer du texte',
                                onPressed: () {
                                  setState(() => _draftImages.remove(url));
                                  _markDirty();
                                },
                                icon: const Icon(Icons.close_rounded, size: 16),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Les images sont ajoutées à la fin du contenu.', style: muted),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _writeWithAi,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Rédiger avec l\'IA'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _uploadingImage ? null : _addDraftImage,
                      icon: _uploadingImage
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add_photo_alternate_outlined, size: 18),
                      label: const Text('Ajouter une image'),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  htmlToPlainText(post.body.fr).isEmpty ? 'Aucun contenu.' : htmlToPlainText(post.body.fr),
                  maxLines: 12,
                  overflow: TextOverflow.fade,
                ),
                const SizedBox(height: 8),
                Text(
                  _bodyOverride != null
                      ? 'Version anglaise traduite par l\'IA : enregistre pour la garder.'
                      : post.body.en.trim().isEmpty
                      ? 'Pas encore de version anglaise.'
                      : 'Version anglaise rédigée.',
                  style: muted,
                ),
                if (_translateProgress != null) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _translateProgress),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (post.body.fr.trim().isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: _translateProgress != null || _saving ? null : _translateBody,
                        icon: const Icon(Icons.translate_rounded, size: 18),
                        label: Text(post.body.en.trim().isEmpty ? 'Traduire en anglais' : 'Retraduire en anglais'),
                      ),
                    FilledButton.tonalIcon(
                      onPressed: _openAdmin,
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Rédiger dans l\'admin web'),
                    ),
                    if (post.previewUrl != null)
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri.parse(post.previewUrl!), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Aperçu'),
                      ),
                  ],
                ),
                if (post.reactionsTotal > 0 || post.sharesCount > 0 || post.pendingCommentsCount > 0) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      for (final type in PostReactionType.values)
                        if ((post.reactions[type] ?? 0) > 0)
                          Tooltip(message: type.label, child: Text('${type.emoji} ${post.reactions[type]}')),
                      if (post.sharesCount > 0)
                        Tooltip(
                          message: [
                            for (final network in PostShareNetwork.values)
                              if ((post.shares[network] ?? 0) > 0) '${network.label} : ${post.shares[network]}',
                          ].join('\n'),
                          child: Text('↗ ${post.sharesCount} partage${post.sharesCount > 1 ? 's' : ''}'),
                        ),
                      if (post.pendingCommentsCount > 0)
                        Text(
                          '${post.pendingCommentsCount} commentaire${post.pendingCommentsCount > 1 ? 's' : ''} à modérer',
                          style: muted,
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 22,
          child: _TagsField(
            tags: _tags,
            error:
                v?.errorFor('tags') ??
                v?.errors.entries.where((e) => e.key.startsWith('tags.')).firstOrNull?.value.first,
            onChanged: (tags) {
              setState(() => _tags = tags);
              _markDirty();
            },
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Série (facultative)', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text('Une série inconnue est créée ; vide, l\'article sort de sa série.', style: muted),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _series,
                      maxLength: 80,
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(
                        labelText: 'Nom de la série',
                        counterText: '',
                        errorText: v?.errorFor('series'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _seriesPosition,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(labelText: 'Place', errorText: v?.errorFor('series_position')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PhotoPickerTile(
                label: 'Couverture',
                currentUrl: post?.coverUrl,
                pickedFile: _coverPending,
                onPicked: (file) {
                  setState(() => _coverPending = file);
                  _markDirty();
                },
              ),
              if (v?.errorFor('cover') != null)
                Text(v!.errorFor('cover')!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              if (post?.coverUrl != null && _coverPending == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _removingCover ? null : _removeCover,
                    icon: _removingCover
                        ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.delete_outline_rounded),
                    label: const Text('Retirer la couverture'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Publication', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<PublicationStatus>(
                segments: [for (final s in PublicationStatus.values) ButtonSegment(value: s, label: Text(s.label))],
                selected: {_status},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() => _status = selection.first);
                  _markDirty();
                },
              ),
              if (v?.errorFor('status') != null) ...[
                const SizedBox(height: 6),
                Text(
                  v!.errorFor('status')!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  _publishedAt == null
                      ? 'Date de parution : à la publication'
                      : 'Parution le ${DateFormat('d MMMM y \'à\' HH\'h\'mm', 'fr_FR').format(_publishedAt!)}',
                ),
                subtitle: Text(
                  v?.errorFor('published_at') ??
                      (_publishedAt != null && _publishedAt!.isAfter(DateTime.now())
                          ? 'Programmé : l\'article paraîtra à cette date.'
                          : 'Une date future programme l\'article.'),
                ),
                trailing: _publishedAt == null
                    ? null
                    : IconButton(
                        tooltip: 'Effacer la date',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          setState(() => _publishedAt = null);
                          _markDirty();
                        },
                      ),
                onTap: _pickPublishedAt,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('À la une'),
                value: _isFeatured,
                onChanged: (value) {
                  setState(() => _isFeatured = value);
                  _markDirty();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tags de l'article (8 au plus), avec les tags existants en suggestion.
class _TagsField extends ConsumerStatefulWidget {
  const _TagsField({required this.tags, required this.onChanged, this.error});

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final String? error;

  @override
  ConsumerState<_TagsField> createState() => _TagsFieldState();
}

class _TagsFieldState extends ConsumerState<_TagsField> {
  TextEditingController? _input;

  void _add(String raw) {
    final tag = raw.trim();
    final exists = widget.tags.any((t) => t.toLowerCase() == tag.toLowerCase());
    if (tag.isEmpty || tag.length > 40 || exists || widget.tags.length >= _maxTags) {
      return;
    }
    widget.onChanged([...widget.tags, tag]);
    _input?.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final known = ref.watch(postTagsProvider).asData?.value ?? const <String>[];
    final full = widget.tags.length >= _maxTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tags', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        if (widget.tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in widget.tags)
                InputChip(label: Text(tag), onDeleted: () => widget.onChanged([...widget.tags]..remove(tag))),
            ],
          ),
        const SizedBox(height: 8),
        Autocomplete<String>(
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) {
              return const [];
            }
            return known.where((t) => t.toLowerCase().contains(query) && !widget.tags.contains(t)).take(6);
          },
          onSelected: _add,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            _input = controller;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !full,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                _add(value);
                focusNode.requestFocus();
              },
              decoration: InputDecoration(
                labelText: full ? '8 tags au maximum' : 'Ajouter un tag',
                helperText: 'Les tags inconnus sont créés à l\'enregistrement.',
                errorText: widget.error,
                counterText: '',
                suffixIcon: IconButton(
                  tooltip: 'Ajouter',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: full ? null : () => _add(controller.text),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
