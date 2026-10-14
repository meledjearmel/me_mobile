import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/utils/relative_date.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/syndication.dart';

/// Republication des articles sur dev.to et Hashnode : mode, clé d'API, langue
/// et publication Hashnode. Les clés ne sont jamais affichées ni relues : un
/// champ laissé vide garde la clé enregistrée.
class SyndicationSettingsScreen extends ConsumerStatefulWidget {
  const SyndicationSettingsScreen({super.key});

  @override
  ConsumerState<SyndicationSettingsScreen> createState() => _SyndicationSettingsScreenState();
}

class _PlatformForm {
  _PlatformForm(PlatformSettings settings) : mode = settings.mode, locale = settings.locale;

  /// Après un enregistrement : repart des réglages renvoyés, champ de clé vidé.
  void reset(PlatformSettings settings) {
    mode = settings.mode;
    locale = settings.locale;
    clearKey = false;
    apiKey.clear();
  }

  SyndicationMode mode;
  String locale;
  bool clearKey = false;

  /// Toujours vide au chargement : la clé enregistrée n'est jamais renvoyée.
  final apiKey = TextEditingController();

  PlatformSettingsInput get input => (mode: mode, locale: locale, apiKey: apiKey.text, clearKey: clearKey);
}

class _SyndicationSettingsScreenState extends ConsumerState<SyndicationSettingsScreen> {
  late Future<void> _future = _load();

  late SyndicationSettings _settings;
  late _PlatformForm _devto;
  late _PlatformForm _hashnode;
  final _publicationId = TextEditingController();
  List<HashnodePublication>? _publications;
  bool _loadingPublications = false;

  bool _saving = false;
  String? _error;
  ValidationException? _validation;

  Future<void> _load() async {
    _apply(await ref.read(syndicationRepositoryProvider).settings());
  }

  bool _initialized = false;

  void _apply(SyndicationSettings settings) {
    _settings = settings;
    if (_initialized) {
      _devto.reset(settings.devto);
      _hashnode.reset(settings.hashnode);
    } else {
      _devto = _PlatformForm(settings.devto);
      _hashnode = _PlatformForm(settings.hashnode);
    }
    _publicationId.text = settings.hashnode.publicationId ?? '';
    _initialized = true;
  }

  @override
  void dispose() {
    if (_initialized) {
      _devto.apiKey.dispose();
      _hashnode.apiKey.dispose();
    }
    _publicationId.dispose();
    super.dispose();
  }

  Future<void> _loadPublications() async {
    setState(() => _loadingPublications = true);
    try {
      final publications = await ref.read(syndicationRepositoryProvider).hashnodePublications();
      setState(() => _publications = publications);
      if (publications.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune publication : enregistre d\'abord une clé Hashnode valide.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingPublications = false);
      }
    }
  }

  Future<void> _save() async {
    // Passer en automatique publie seul les prochains articles : on le confirme.
    final turningAuto = [
      if (_devto.mode == SyndicationMode.auto && _settings.devto.mode != SyndicationMode.auto) 'dev.to',
      if (_hashnode.mode == SyndicationMode.auto && _settings.hashnode.mode != SyndicationMode.auto) 'Hashnode',
    ];
    if (turningAuto.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Activer la republication automatique ?'),
          content: Text(
            'Chaque article publié à partir de maintenant partira tout seul sur ${turningAuto.join(' et ')}. '
            'Les articles déjà publiés ne sont pas concernés.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Activer')),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
      _validation = null;
    });
    try {
      final saved = await ref
          .read(syndicationRepositoryProvider)
          .saveSettings(devto: _devto.input, hashnode: _hashnode.input, hashnodePublicationId: _publicationId.text);
      setState(() => _apply(saved));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved.hashnodeError == null
                  ? 'Réglages enregistrés.'
                  : 'Réglages enregistrés. Hashnode : ${saved.hashnodeError}',
            ),
          ),
        );
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: const GlassAppBar(),
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: FormHeader(
                  title: 'Republication',
                  subtitle:
                      'Les articles publiés repartent sur dev.to et Hashnode avec un lien canonique vers le site.',
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
              _platformSection(SyndicationPlatform.devto, _devto),
              const SizedBox(height: 12),
              _platformSection(
                SyndicationPlatform.hashnode,
                _hashnode,
                extra: [
                  TextField(
                    controller: _publicationId,
                    decoration: InputDecoration(
                      labelText: 'Publication Hashnode',
                      helperText: 'Vide : la première publication du compte est retrouvée avec la clé.',
                      helperMaxLines: 2,
                      errorText: _validation?.errorFor('hashnode_publication_id'),
                      suffixIcon: IconButton(
                        tooltip: 'Choisir parmi mes publications',
                        onPressed: _loadingPublications ? null : _loadPublications,
                        icon: _loadingPublications
                            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.list_rounded),
                      ),
                    ),
                  ),
                  if (_publications?.isNotEmpty == true)
                    RadioGroup<String>(
                      groupValue: _publicationId.text,
                      onChanged: (id) => setState(() => _publicationId.text = id ?? ''),
                      child: Column(
                        children: [
                          for (final publication in _publications!)
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              value: publication.id,
                              title: Text(publication.title),
                              subtitle: Text(publication.url),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _platformSection(SyndicationPlatform platform, _PlatformForm form, {List<Widget> extra = const []}) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final saved = _settings.of(platform);
    final prefix = platform.wireValue;
    final v = _validation;

    return FormSection(
      title: platform.label,
      summary: form.mode.label,
      hasError: v?.hasErrorUnder(prefix) ?? false,
      children: [
        SegmentedButton<SyndicationMode>(
          showSelectedIcon: false,
          segments: [for (final m in SyndicationMode.values) ButtonSegment(value: m, label: Text(m.label))],
          selected: {form.mode},
          onSelectionChanged: (selection) => setState(() => form.mode = selection.first),
        ),
        Text(switch (form.mode) {
          SyndicationMode.off => 'Aucun article ne part sur ${platform.label}.',
          SyndicationMode.manual => 'Un article part avec le bouton de son écran « Diffusion ».',
          SyndicationMode.auto =>
            saved.mode == SyndicationMode.auto && saved.autoSince != null
                ? 'Chaque article publié depuis le ${fullDate(saved.autoSince!)} part tout seul.'
                : 'Chaque article publié à partir de l\'enregistrement partira tout seul.',
        }, style: muted),
        Row(
          children: [
            Text('Clé d\'API', style: theme.textTheme.labelLarge),
            const SizedBox(width: 8),
            StatusBadge(
              saved.hasKey && !form.clearKey ? 'Enregistrée' : 'Aucune',
              color: saved.hasKey && !form.clearKey ? theme.colorScheme.primary : null,
            ),
          ],
        ),
        TextField(
          controller: form.apiKey,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          enabled: !form.clearKey,
          decoration: InputDecoration(
            labelText: saved.hasKey ? 'Nouvelle clé (vide : garder l\'actuelle)' : 'Clé d\'API',
            errorText: v?.errorFor('${prefix}_api_key'),
          ),
        ),
        if (saved.hasKey)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: form.clearKey,
            title: const Text('Retirer la clé enregistrée'),
            onChanged: (value) => setState(() {
              form.clearKey = value ?? false;
              if (form.clearKey) {
                form.apiKey.clear();
              }
            }),
          ),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'fr', label: Text('Republier en français')),
            ButtonSegment(value: 'en', label: Text('En anglais')),
          ],
          selected: {form.locale},
          onSelectionChanged: (selection) => setState(() => form.locale = selection.first),
        ),
        ...extra,
      ],
    );
  }
}
