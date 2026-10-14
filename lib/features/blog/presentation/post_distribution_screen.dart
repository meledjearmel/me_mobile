import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/utils/relative_date.dart';
import '../../../shared/widgets/form_layout.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/surfaces.dart';
import '../data/syndication.dart';

/// Diffusion d'un article : republication sur dev.to et Hashnode, et kit de
/// partage par réseau. Rien ne part sans action : la republication demande une
/// confirmation, et les réseaux s'ouvrent déjà remplis, sans publier à ta place.
class PostDistributionScreen extends ConsumerStatefulWidget {
  const PostDistributionScreen({super.key, required this.postId, required this.title, required this.isPublished});

  final int postId;
  final String title;

  /// Seul un article publié sur le site peut être republié.
  final bool isPublished;

  @override
  ConsumerState<PostDistributionScreen> createState() => _PostDistributionScreenState();
}

class _PostDistributionScreenState extends ConsumerState<PostDistributionScreen> {
  late Future<PostDistribution> _future = _load();
  SyndicationPlatform? _syndicating;

  String? _locale;
  final _texts = <String, Map<SocialNetwork, TextEditingController>>{};
  final _kits = <String, SocialKit>{};
  bool _textsDirty = false;
  bool _savingTexts = false;
  bool _generating = false;

  SyndicationRepository get _repository => ref.read(syndicationRepositoryProvider);

  Future<PostDistribution> _load() async {
    final distribution = await _repository.distribution(widget.postId);
    for (final MapEntry(key: locale, value: kit) in distribution.social.entries) {
      _setKit(locale, kit);
    }
    _locale ??= distribution.social.keys.firstOrNull;
    _textsDirty = false;
    return distribution;
  }

  void _setKit(String locale, SocialKit kit) {
    _kits[locale] = kit;
    final controllers = _texts.putIfAbsent(
      locale,
      () => {for (final network in SocialNetwork.values) network: TextEditingController()},
    );
    for (final network in SocialNetwork.values) {
      controllers[network]!.text = kit.texts[network] ?? '';
    }
  }

  @override
  void dispose() {
    for (final controllers in _texts.values) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _syndicate(SyndicationPlatform platform, PostSyndication? current) async {
    final update = current?.isPublished ?? false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(update ? 'Mettre à jour sur ${platform.label} ?' : 'Publier sur ${platform.label} ?'),
        content: Text(
          update
              ? 'La version republiée de « ${widget.title} » sera remplacée par celle du site.'
              : '« ${widget.title} » sera publié sur ${platform.label}, avec un lien canonique vers le site.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(update ? 'Mettre à jour' : 'Publier'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _syndicating = platform);
    try {
      final result = await _repository.syndicate(widget.postId, platform);
      _toast(result.isPublished ? 'Article republié sur ${platform.label}.' : 'Republication en cours.');
    } on ApiException catch (e) {
      // 422 : l'erreur renvoyée par la plateforme.
      _toast('${platform.label} : ${e.message}');
    } finally {
      if (mounted) {
        setState(() {
          _syndicating = null;
          _future = _load();
        });
      }
    }
  }

  Map<SocialNetwork, String> _currentTexts(String locale) => {
    for (final MapEntry(:key, :value) in _texts[locale]!.entries) key: value.text,
  };

  Future<SocialKit?> _saveTexts({bool quiet = false}) async {
    final locale = _locale!;
    setState(() => _savingTexts = true);
    try {
      final kit = await _repository.saveSocialTexts(widget.postId, locale, _currentTexts(locale));
      setState(() {
        _setKit(locale, kit);
        _textsDirty = false;
      });
      if (!quiet) {
        _toast('Textes enregistrés.');
      }
      return kit;
    } on ValidationException catch (e) {
      _toast(e.errors.values.expand((m) => m).firstOrNull ?? e.message);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) {
        setState(() => _savingTexts = false);
      }
    }
    return null;
  }

  Future<void> _generate() async {
    final locale = _locale!;
    if (_kits[locale]?.hasTexts ?? false) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Réécrire les textes ?'),
          content: const Text('L\'IA remplace les textes enregistrés pour cette langue.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Réécrire')),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }
    setState(() => _generating = true);
    try {
      final kit = await _repository.generateSocialTexts(widget.postId, locale);
      setState(() {
        _setKit(locale, kit);
        _textsDirty = false;
      });
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast('Copié.');
  }

  /// Ouvre le réseau avec le texte déjà rempli ; rien n'est publié sans toi.
  /// Les textes modifiés sont d'abord enregistrés, pour que le lien les reprenne.
  Future<void> _share(SocialNetwork network) async {
    final locale = _locale!;
    var kit = _kits[locale]!;
    if (_textsDirty) {
      kit = await _saveTexts(quiet: true) ?? kit;
    }
    final text = _texts[locale]![network]!.text.trim();
    if (network == SocialNetwork.whatsapp) {
      // Le statut WhatsApp n'a pas de lien de partage : la feuille du téléphone propose « Mon statut ».
      await SharePlus.instance.share(ShareParams(text: '${text.isEmpty ? widget.title : text} ${kit.url}'));
      return;
    }
    final link = kit.links[network];
    if (link != null && !await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication)) {
      _toast('Impossible d\'ouvrir ${network.label}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: _syndicating == null && !_generating,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: const GlassAppBar(),
        body: FutureBuilder<PostDistribution>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
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
            final distribution = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async {
                setState(() => _future = _load());
                await _future;
              },
              child: ListView(
                padding: pageInsets(context),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FormHeader(title: 'Diffusion', subtitle: widget.title),
                  ),
                  const SizedBox(height: 16),
                  Text('Republication', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final platform in SyndicationPlatform.values) ...[
                    _platformCard(platform, distribution.on(platform)),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 14),
                  Text('Kit de partage', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_locale == null)
                    Text(
                      'Pas de kit : l\'article n\'a pas encore de titre.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    )
                  else
                    ..._socialKit(context, distribution),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _platformCard(SyndicationPlatform platform, PostSyndication? syndication) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final busy = _syndicating == platform;

    return SurfaceCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(platform.label, style: theme.textTheme.titleSmall)),
              if (syndication == null)
                const StatusBadge('Pas encore')
              else
                StatusBadge(
                  syndication.statusLabel,
                  color: syndication.isFailed
                      ? theme.colorScheme.error
                      : syndication.isPublished
                      ? theme.colorScheme.primary
                      : null,
                ),
            ],
          ),
          if (syndication?.publishedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Le ${fullDate(syndication!.publishedAt!)}${syndication.locale == null ? '' : ' · ${syndication.locale!.toUpperCase()}'}',
              style: muted,
            ),
          ],
          if (syndication?.error != null) ...[
            const SizedBox(height: 6),
            Text(syndication!.error!, style: muted?.copyWith(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: !widget.isPublished || _syndicating != null ? null : () => _syndicate(platform, syndication),
                icon: busy
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.publish_rounded, size: 18),
                label: Text(syndication?.isPublished ?? false ? 'Mettre à jour' : 'Publier'),
              ),
              if (syndication?.externalUrl != null)
                OutlinedButton.icon(
                  onPressed: () =>
                      launchUrl(Uri.parse(syndication!.externalUrl!), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Voir'),
                ),
            ],
          ),
          if (!widget.isPublished) ...[
            const SizedBox(height: 6),
            Text('Publie d\'abord l\'article sur le site.', style: muted),
          ],
        ],
      ),
    );
  }

  List<Widget> _socialKit(BuildContext context, PostDistribution distribution) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final locale = _locale!;
    final kit = _kits[locale]!;
    final controllers = _texts[locale]!;

    return [
      if (distribution.social.length > 1) ...[
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final l in distribution.social.keys)
              ButtonSegment(value: l, label: Text(l == 'fr' ? 'Français' : 'Anglais')),
          ],
          selected: {locale},
          onSelectionChanged: _textsDirty ? null : (selection) => setState(() => _locale = selection.first),
        ),
        if (_textsDirty) Text('Enregistre les textes avant de changer de langue.', style: muted),
        const SizedBox(height: 10),
      ],
      SurfaceCard(
        radius: 20,
        child: Row(
          children: [
            Expanded(
              child: Text(kit.url, style: muted, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              tooltip: 'Copier le lien',
              onPressed: () => _copy(kit.url),
              icon: const Icon(Icons.link_rounded),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      for (final network in SocialNetwork.values) ...[
        SurfaceCard(
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(network.label, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: controllers[network],
                minLines: 2,
                maxLines: 10,
                maxLength: network.maxLength,
                enabled: !_generating,
                onChanged: (_) => setState(() => _textsDirty = true),
                decoration: const InputDecoration(hintText: 'Vide : le titre de l\'article.'),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    // Le texte suivi du lien, prêt à coller dans le réseau.
                    onPressed: () => _copy('${controllers[network]!.text.trim()}\n\n${kit.url}'.trim()),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copier'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.tonalIcon(
                    onPressed: _savingTexts || _generating ? null : () => _share(network),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(network == SocialNetwork.whatsapp ? 'Partager' : 'Ouvrir ${network.label}'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      if (_generating) ...[
        const LinearProgressIndicator(),
        const SizedBox(height: 8),
        Text('Rédaction en cours, cela peut prendre jusqu\'à une minute…', style: muted),
        const SizedBox(height: 8),
      ],
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _generating || _savingTexts ? null : _generate,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Rédiger avec l\'IA'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: !_textsDirty || _savingTexts ? null : _saveTexts,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Enregistrer'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text('Chaque réseau s\'ouvre avec le texte et le lien déjà remplis : c\'est toi qui publies.', style: muted),
    ];
  }
}
