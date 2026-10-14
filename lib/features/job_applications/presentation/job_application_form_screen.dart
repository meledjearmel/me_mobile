import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/date_field.dart';
import '../../../shared/widgets/mention_button.dart';
import '../../../shared/widgets/mention_text.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../content/data/reference_repository.dart';
import '../application/job_application_list_controller.dart';
import '../data/job_application.dart';
import '../data/job_application_repository.dart';
import 'widgets/job_application_ai_sheet.dart';
import 'widgets/ordered_projects_field.dart';

/// Création ou modification d'une page de candidature. `id == null` : création.
/// Renvoie la candidature enregistrée en fermant l'écran, ou [deleted] après une suppression.
class JobApplicationFormScreen extends ConsumerStatefulWidget {
  const JobApplicationFormScreen({super.key, this.id});

  final int? id;

  /// Résultat de l'écran quand la candidature a été supprimée.
  static const deleted = #deleted;

  @override
  ConsumerState<JobApplicationFormScreen> createState() => _JobApplicationFormScreenState();
}

class _JobApplicationFormScreenState extends ConsumerState<JobApplicationFormScreen> {
  late Future<void> _future = _load();

  final _company = TextEditingController();
  final _contactName = TextEditingController();
  final _position = TextEditingController();
  final _intro = MentionEditingController();
  final _postingUrl = TextEditingController();
  final _postingText = TextEditingController();
  final _notes = TextEditingController();
  int? _jobProfileId;
  String _locale = 'fr';
  JobApplicationStatus _status = JobApplicationStatus.draft;
  DateTime? _expiresOn;
  List<int> _projectIds = const [];
  String _titleForDelete = '';

  /// Explication de l'IA après « Préparer avec l'IA ».
  String? _aiReasoning;

  bool _dirty = false;
  bool _saving = false;
  bool _deleting = false;
  String? _error;
  ValidationException? _validation;

  bool get _isEditing => widget.id != null;

  Future<void> _load() async {
    if (widget.id == null) {
      return;
    }
    final application = await ref.read(jobApplicationRepositoryProvider).get(widget.id!);
    _company.text = application.company;
    _contactName.text = application.contactName ?? '';
    _position.text = application.position;
    _intro.text = application.intro;
    _postingUrl.text = application.jobPostingUrl ?? '';
    _postingText.text = application.jobPostingText ?? '';
    _notes.text = application.notes ?? '';
    _jobProfileId = application.jobProfileId;
    _locale = application.locale;
    _status = application.status;
    _expiresOn = application.expiresOn;
    _projectIds = application.projectIds;
    _titleForDelete = application.company;
  }

  @override
  void dispose() {
    for (final controller in [_company, _contactName, _position, _intro, _postingUrl, _postingText, _notes]) {
      controller.dispose();
    }
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

  Future<void> _prepareWithAi() async {
    final result = await showJobApplicationAiSheet(context, initialPosting: _postingText.text, initialLocale: _locale);
    if (result == null) {
      return;
    }
    final draft = result.draft;
    setState(() {
      _company.text = draft.company;
      _contactName.text = draft.contactName ?? '';
      _position.text = draft.position;
      _intro.text = draft.intro;
      _postingText.text = result.posting;
      _locale = result.locale;
      _projectIds = draft.projectIds.take(6).toList();
      _jobProfileId = draft.jobProfileId ?? _jobProfileId;
      _aiReasoning = draft.reasoning;
    });
    _markDirty();
  }

  Future<void> _insertMention() async {
    final mention = await showMentionPicker(context);
    if (mention != null) {
      _intro.insertMention(mention);
      _markDirty();
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    try {
      final saved = await ref
          .read(jobApplicationRepositoryProvider)
          .save(
            id: widget.id,
            company: _company.text.trim(),
            contactName: _contactName.text,
            position: _position.text.trim(),
            jobProfileId: _jobProfileId,
            locale: _locale,
            intro: _intro.text.trim(),
            jobPostingUrl: _postingUrl.text,
            jobPostingText: _postingText.text,
            notes: _notes.text,
            status: _status,
            expiresOn: _expiresOn,
            projectIds: _projectIds,
          );
      ref.invalidate(jobApplicationListProvider);
      _dirty = false;
      if (mounted) {
        Navigator.of(context).pop(saved);
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

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer la candidature « $_titleForDelete » ?'),
        content: const Text('Le lien envoyé à l\'entreprise ne répondra plus.'),
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
      await ref.read(jobApplicationRepositoryProvider).delete(widget.id!);
      ref.read(jobApplicationListProvider.notifier).removeItem((a) => a.id == widget.id);
      if (mounted) {
        _dirty = false;
        Navigator.of(context).pop(JobApplicationFormScreen.deleted);
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
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final v = _validation;
    final projects = ref.watch(projectsLiteRefProvider).value ?? const [];
    final profiles = ref.watch(jobProfilesRefProvider).value ?? const [];

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
            IconButton(
              tooltip: 'Préparer avec l\'IA',
              onPressed: _saving ? null : _prepareWithAi,
              icon: const Icon(Icons.auto_awesome_rounded),
            ),
            if (_isEditing)
              IconButton(
                tooltip: 'Supprimer',
                onPressed: _deleting ? null : _delete,
                icon: _deleting
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        bottomNavigationBar: FutureBuilder<void>(
          future: _future,
          builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done && !snapshot.hasError
              ? SaveBar(onPressed: _save, saving: _saving)
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

            return ListView(
              padding: pageInsets(context),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FormHeader(
                    title: _isEditing ? 'Modifier la candidature' : 'Nouvelle candidature',
                    subtitle: _isEditing ? null : 'Astuce : ✦ en haut prépare la page à partir d\'une offre.',
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
                if (_aiReasoning != null) ...[
                  SurfaceCard(
                    radius: 22,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 20, color: theme.colorScheme.tertiary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_aiReasoning!, style: muted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FormSection(
                  title: 'Entreprise et poste',
                  hasError: ['company', 'contact_name', 'position', 'locale'].any((k) => v?.errorFor(k) != null),
                  children: [
                    TextField(
                      controller: _company,
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(labelText: 'Entreprise', errorText: v?.errorFor('company')),
                    ),
                    TextField(
                      controller: _position,
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(labelText: 'Poste', errorText: v?.errorFor('position')),
                    ),
                    TextField(
                      controller: _contactName,
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(
                        labelText: 'Contact (facultatif)',
                        errorText: v?.errorFor('contact_name'),
                      ),
                    ),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'fr', label: Text('Français')),
                        ButtonSegment(value: 'en', label: Text('Anglais')),
                      ],
                      selected: {_locale},
                      onSelectionChanged: (selection) {
                        setState(() => _locale = selection.first);
                        _markDirty();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FormSection(
                  title: 'Mot d\'accompagnement',
                  hasError: v?.errorFor('intro') != null,
                  children: [
                    TextField(
                      controller: _intro,
                      onChanged: (_) => _markDirty(),
                      minLines: 6,
                      maxLines: 16,
                      maxLength: 5000,
                      decoration: InputDecoration(
                        labelText: 'Texte',
                        helperText: 'Paragraphes séparés par une ligne vide. Les mentions deviennent des liens.',
                        helperMaxLines: 2,
                        alignLabelWithHint: true,
                        errorText: v?.errorFor('intro'),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _insertMention,
                        icon: const Icon(Icons.alternate_email_rounded, size: 18),
                        label: const Text('Mentionner'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FormSection(
                  title: 'Projets et CV',
                  summary: '${_projectIds.length}',
                  hasError: v?.errorFor('project_ids') != null || v?.errorFor('job_profile_id') != null,
                  children: [
                    OrderedProjectsField(
                      options: [for (final p in projects) (id: p.id, label: p.title.display)],
                      selectedIds: _projectIds,
                      error: v?.errorFor('project_ids'),
                      onChanged: (ids) {
                        setState(() => _projectIds = ids);
                        _markDirty();
                      },
                    ),
                    DropdownButtonFormField<int?>(
                      initialValue: _jobProfileId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Profil métier du CV',
                        helperText: 'Aucun : la page ne propose pas de CV.',
                        errorText: v?.errorFor('job_profile_id'),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(child: Text('Aucun')),
                        for (final profile in profiles)
                          DropdownMenuItem(value: profile.id, child: Text(profile.label.display)),
                      ],
                      onChanged: (value) {
                        setState(() => _jobProfileId = value);
                        _markDirty();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FormSection(
                  title: 'Offre',
                  initiallyExpanded: false,
                  hasError: v?.errorFor('job_posting_url') != null || v?.errorFor('job_posting_text') != null,
                  children: [
                    TextField(
                      controller: _postingUrl,
                      keyboardType: TextInputType.url,
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(
                        labelText: 'Adresse de l\'offre',
                        errorText: v?.errorFor('job_posting_url'),
                      ),
                    ),
                    TextField(
                      controller: _postingText,
                      onChanged: (_) => _markDirty(),
                      minLines: 4,
                      maxLines: 12,
                      maxLength: 20000,
                      decoration: InputDecoration(
                        labelText: 'Texte de l\'offre',
                        helperText: 'Sert aussi à adapter le CV.',
                        alignLabelWithHint: true,
                        errorText: v?.errorFor('job_posting_text'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FormSection(
                  title: 'Publication',
                  hasError: ['status', 'expires_on', 'notes'].any((k) => v?.errorFor(k) != null),
                  children: [
                    SegmentedButton<JobApplicationStatus>(
                      showSelectedIcon: false,
                      segments: [
                        for (final status in JobApplicationStatus.values)
                          ButtonSegment(value: status, label: Text(status.label)),
                      ],
                      selected: {_status},
                      onSelectionChanged: (selection) {
                        setState(() => _status = selection.first);
                        _markDirty();
                      },
                    ),
                    Text(switch (_status) {
                      JobApplicationStatus.draft => 'Le lien ne répond pas encore.',
                      JobApplicationStatus.active => 'Le lien est ouvert à qui le reçoit.',
                      JobApplicationStatus.archived => 'Le lien est coupé.',
                    }, style: muted),
                    DateField(
                      label: 'Ouverte jusqu\'au',
                      value: _expiresOn,
                      allowClear: true,
                      emptyLabel: 'Sans limite',
                      error: v?.errorFor('expires_on'),
                      onChanged: (date) {
                        setState(() => _expiresOn = date);
                        _markDirty();
                      },
                    ),
                    Text('La page reste ouverte jusqu\'à la fin de ce jour.', style: muted),
                    TextField(
                      controller: _notes,
                      onChanged: (_) => _markDirty(),
                      minLines: 2,
                      maxLines: 6,
                      maxLength: 5000,
                      decoration: InputDecoration(
                        labelText: 'Notes privées',
                        helperText: 'Jamais affichées sur la page.',
                        alignLabelWithHint: true,
                        errorText: v?.errorFor('notes'),
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
