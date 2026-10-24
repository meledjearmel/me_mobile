import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../application/proposal_list_controller.dart';
import '../data/proposal.dart';
import '../data/proposal_repository.dart';

/// Création ou modification d'une proposition freelance. `id == null` : création.
/// Renvoie la proposition enregistrée en fermant l'écran, ou [deleted] après une suppression.
class ProposalFormScreen extends ConsumerStatefulWidget {
  const ProposalFormScreen({super.key, this.id});

  final int? id;

  /// Résultat de l'écran quand la proposition a été supprimée.
  static const deleted = #deleted;

  @override
  ConsumerState<ProposalFormScreen> createState() => _ProposalFormScreenState();
}

class _ProposalFormScreenState extends ConsumerState<ProposalFormScreen> {
  late Future<void> _future = _load();

  final _jobTitle = TextEditingController();
  final _clientName = TextEditingController();
  final _jobUrl = TextEditingController();
  final _jobPosting = TextEditingController();
  final _body = TextEditingController();
  final _screeningAnswers = TextEditingController();
  final _bid = TextEditingController();
  final _connects = TextEditingController();
  final _notes = TextEditingController();
  ProposalPlatform _platform = ProposalPlatform.upwork;
  String _locale = 'fr';
  ProposalStatus _status = ProposalStatus.draft;
  String? _draftedBy;

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
    final proposal = await ref.read(proposalRepositoryProvider).get(widget.id!);
    _jobTitle.text = proposal.jobTitle;
    _clientName.text = proposal.clientName ?? '';
    _jobUrl.text = proposal.jobUrl ?? '';
    _jobPosting.text = proposal.jobPosting ?? '';
    _body.text = proposal.body;
    _screeningAnswers.text = proposal.screeningAnswers ?? '';
    _bid.text = proposal.bid ?? '';
    _connects.text = proposal.connects?.toString() ?? '';
    _notes.text = proposal.notes ?? '';
    _platform = proposal.platform;
    _locale = proposal.locale;
    _status = proposal.status;
    _draftedBy = proposal.draftedBy;
  }

  @override
  void dispose() {
    for (final controller in [
      _jobTitle,
      _clientName,
      _jobUrl,
      _jobPosting,
      _body,
      _screeningAnswers,
      _bid,
      _connects,
      _notes,
    ]) {
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

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    try {
      final saved = await ref
          .read(proposalRepositoryProvider)
          .save(
            id: widget.id,
            platform: _platform,
            locale: _locale,
            jobTitle: _jobTitle.text.trim(),
            clientName: _clientName.text,
            jobUrl: _jobUrl.text,
            jobPosting: _jobPosting.text,
            body: _body.text.trim(),
            screeningAnswers: _screeningAnswers.text,
            bid: _bid.text,
            connects: int.tryParse(_connects.text.trim()),
            status: _status,
            notes: _notes.text,
          );
      ref.invalidate(proposalListProvider);
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
        title: const Text('Supprimer cette proposition ?'),
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
      await ref.read(proposalRepositoryProvider).delete(widget.id!);
      ref.read(proposalListProvider.notifier).removeItem((p) => p.id == widget.id);
      if (mounted) {
        _dirty = false;
        Navigator.of(context).pop(ProposalFormScreen.deleted);
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

  Widget _multiline(
    TextEditingController controller, {
    required String field,
    required String label,
    String? helper,
    int minLines = 4,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) => _markDirty(),
      minLines: minLines,
      maxLines: 16,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        alignLabelWithHint: true,
        errorText: _validation?.errorFor(field),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final v = _validation;

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
                    title: _isEditing ? 'Modifier la proposition' : 'Nouvelle proposition',
                    subtitle: _isEditing && _draftedBy?.isNotEmpty == true ? 'Rédigée par $_draftedBy' : null,
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
                FormSection(
                  title: 'Offre',
                  hasError: [
                    'platform',
                    'locale',
                    'job_title',
                    'client_name',
                    'job_url',
                    'job_posting',
                  ].any((k) => v?.errorFor(k) != null),
                  children: [
                    DropdownButtonFormField<ProposalPlatform>(
                      initialValue: _platform,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'Plateforme', errorText: v?.errorFor('platform')),
                      items: [
                        for (final platform in ProposalPlatform.values)
                          DropdownMenuItem(value: platform, child: Text(platform.label)),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _platform = value);
                          _markDirty();
                        }
                      },
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
                    if (v?.errorFor('locale') != null)
                      Text(v!.errorFor('locale')!, style: muted?.copyWith(color: theme.colorScheme.error)),
                    TextField(
                      controller: _jobTitle,
                      onChanged: (_) => _markDirty(),
                      maxLength: 255,
                      decoration: InputDecoration(labelText: 'Titre de l\'offre', errorText: v?.errorFor('job_title')),
                    ),
                    TextField(
                      controller: _clientName,
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(
                        labelText: 'Client (facultatif)',
                        helperText: 'Son prénom se trouve souvent dans les avis de son historique (“Thanks John!”).',
                        helperMaxLines: 2,
                        errorText: v?.errorFor('client_name'),
                      ),
                    ),
                    TextField(
                      controller: _jobUrl,
                      keyboardType: TextInputType.url,
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(labelText: 'Adresse de l\'offre', errorText: v?.errorFor('job_url')),
                    ),
                    _multiline(_jobPosting, field: 'job_posting', label: 'Texte de l\'annonce'),
                  ],
                ),
                const SizedBox(height: 12),
                FormSection(
                  title: 'Proposition',
                  hasError: ['body', 'screening_answers'].any((k) => v?.errorFor(k) != null),
                  children: [
                    _multiline(
                      _body,
                      field: 'body',
                      label: 'Texte',
                      helper: 'Collez la version réellement envoyée : c\'est elle qui sert d\'exemple à l\'IA.',
                      minLines: 6,
                      maxLength: 10000,
                    ),
                    _multiline(_screeningAnswers, field: 'screening_answers', label: 'Réponses aux questions'),
                  ],
                ),
                const SizedBox(height: 12),
                FormSection(
                  title: 'Suivi',
                  hasError: ['bid', 'connects', 'status', 'notes'].any((k) => v?.errorFor(k) != null),
                  children: [
                    DropdownButtonFormField<ProposalStatus>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'Statut', errorText: v?.errorFor('status')),
                      items: [
                        for (final status in ProposalStatus.values)
                          DropdownMenuItem(value: status, child: Text(status.label)),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _status = value);
                          _markDirty();
                        }
                      },
                    ),
                    TextField(
                      controller: _bid,
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(
                        labelText: 'Tarif proposé',
                        hintText: '40 \$/h, 1 200 € au forfait…',
                        errorText: v?.errorFor('bid'),
                      ),
                    ),
                    TextField(
                      controller: _connects,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(
                        labelText: 'Connects',
                        helperText: 'De 0 à 500.',
                        errorText: v?.errorFor('connects'),
                      ),
                    ),
                    _multiline(_notes, field: 'notes', label: 'Notes privées', minLines: 2),
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
