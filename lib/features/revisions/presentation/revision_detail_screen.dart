import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/utils/relative_date.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/full_screen_image_viewer.dart';
import '../../../shared/widgets/glass.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/surfaces.dart';
import '../data/revision.dart';
import '../data/revision_repository.dart';

/// Détail d'une révision : avant / après par champ et par langue, puis
/// Appliquer ou Rejeter (avec confirmation). Renvoie `true` une fois traitée.
class RevisionDetailScreen extends ConsumerStatefulWidget {
  const RevisionDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<RevisionDetailScreen> createState() => _RevisionDetailScreenState();
}

class _RevisionDetailScreenState extends ConsumerState<RevisionDetailScreen> {
  late Future<Revision> _future = ref.read(revisionRepositoryProvider).get(widget.id);
  bool _deciding = false;
  String? _error;

  Future<void> _decide(Revision revision, {required bool apply}) async {
    final changed = revision.fields.any((f) => f.changedSince);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(apply ? 'Appliquer la révision ?' : 'Rejeter la révision ?'),
        content: Text(
          apply
              ? 'Le contenu sera mis à jour sur le site, en français et en anglais.'
                    '${changed ? '\n\nCertains champs ont changé depuis la proposition : ils seront écrasés.' : ''}'
              : 'La proposition sera écartée, le contenu reste tel quel.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(apply ? 'Appliquer' : 'Rejeter')),
        ],
      ),
    );
    if (!(confirmed ?? false)) {
      return;
    }

    setState(() {
      _deciding = true;
      _error = null;
    });
    try {
      final repository = ref.read(revisionRepositoryProvider);
      await (apply ? repository.apply(revision.id) : repository.reject(revision.id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apply ? 'Révision appliquée.' : 'Révision rejetée.')));
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      // 409 : déjà traitée ailleurs. On recharge pour montrer son statut.
      setState(() {
        _error = e.message;
        _future = ref.read(revisionRepositoryProvider).get(widget.id);
      });
    } finally {
      if (mounted) {
        setState(() => _deciding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: const GlassAppBar(),
      body: FutureBuilder<Revision>(
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
                  FilledButton(
                    onPressed: () => setState(() => _future = ref.read(revisionRepositoryProvider).get(widget.id)),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }
          return _buildBody(context, snapshot.data!);
        },
      ),
      bottomNavigationBar: FutureBuilder<Revision>(
        future: _future,
        builder: (context, snapshot) {
          final revision = snapshot.data;
          if (revision == null || revision.status != RevisionStatus.pending) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _deciding ? null : () => _decide(revision, apply: false),
                      child: const Text('Rejeter'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _deciding ? null : () => _decide(revision, apply: true),
                      child: _deciding
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Appliquer'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, Revision revision) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return ListView(
      padding: pageInsets(context, bottom: 120),
      children: [
        Text(revision.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          [
            revision.contentTypeLabel,
            if (revision.createdAt != null) 'proposée ${relativeDate(revision.createdAt!)}',
            if (revision.status != RevisionStatus.pending)
              revision.status == RevisionStatus.applied ? 'appliquée' : 'rejetée',
          ].join(' · '),
          style: muted,
        ),
        if (revision.draftedBy != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusBadge('IA · ${revision.draftedBy}', color: theme.colorScheme.tertiary),
          ),
        ],
        if (revision.summary.isNotEmpty) ...[const SizedBox(height: 12), Text(revision.summary)],
        if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
        const SizedBox(height: 20),
        if (revision.image != null) ...[_ImageProposal(image: revision.image!), const SizedBox(height: 12)],
        for (final field in revision.fields) ...[
          _FieldDiff(field: field, pending: revision.status == RevisionStatus.pending),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _FieldDiff extends StatelessWidget {
  const _FieldDiff({required this.field, required this.pending});

  final RevisionField field;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = field.field.replaceAll('_', ' ');

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${label[0].toUpperCase()}${label.substring(1)}', style: theme.textTheme.titleSmall),
              ),
              StatusBadge(field.locale.toUpperCase()),
            ],
          ),
          if (pending && field.changedSince) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ce champ a changé depuis la proposition.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _ValueBlock(label: 'Avant', value: field.before),
          if (pending && field.changedSince) ...[
            const SizedBox(height: 10),
            _ValueBlock(label: 'Actuel', value: field.current),
          ],
          const SizedBox(height: 10),
          _ValueBlock(label: 'Après', value: field.after, highlight: true),
        ],
      ),
    );
  }
}

/// Image proposée ; pour une couverture, l'actuelle à côté (avant / après).
class _ImageProposal extends StatelessWidget {
  const _ImageProposal({required this.image});

  final RevisionImage image;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showCurrent = image.isCover && image.currentUrl != null;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(image.isCover ? 'Image de couverture' : 'Image de galerie', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showCurrent) ...[
                Expanded(child: _ImageTile(label: 'Avant', url: image.currentUrl!)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: _ImageTile(label: image.isCover ? 'Après' : 'Ajoutée', url: image.url, highlight: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.label, required this.url, this.highlight = false});

  final String label;
  final String url;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: highlight
            ? theme.colorScheme.tertiary.withValues(alpha: 0.10)
            : theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => FullScreenImageViewer.open(context, url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueBlock extends StatelessWidget {
  const _ValueBlock({required this.label, required this.value, this.highlight = false});

  final String label;
  final Object? value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? theme.colorScheme.tertiary.withValues(alpha: 0.10)
            : theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          SelectableText(formatRevisionValue(value)),
        ],
      ),
    );
  }
}

/// Valeur lisible : texte tel quel, liste en puces, objet en « clé : valeur ».
String formatRevisionValue(Object? value) => switch (value) {
  null || '' => '(vide)',
  List<dynamic>() when value.isEmpty => '(vide)',
  List<dynamic>() => value.map((item) => '• ${_inline(item)}').join('\n'),
  Map<dynamic, dynamic>() => _inline(value),
  _ => '$value',
};

String _inline(Object? value) => switch (value) {
  Map<dynamic, dynamic>() =>
    value.entries
        .where((e) => e.value != null && e.value != '')
        .map((e) => '${e.key} : ${_inline(e.value)}')
        .join(' — '),
  List<dynamic>() => value.map(_inline).join(', '),
  null => '',
  _ => '$value',
};
