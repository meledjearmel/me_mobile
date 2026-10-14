import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/relative_date.dart';
import '../../../shared/widgets/resource_list_scaffold.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/surfaces.dart';
import '../application/mcp_activity_list_controller.dart';
import '../data/mcp_activity.dart';

/// Journal du serveur MCP : appels d'outils et de commandes, filtrables,
/// chargés page par page au défilement.
class McpActivityScreen extends ConsumerWidget {
  const McpActivityScreen({super.key});

  static const _periods = [(days: 1, label: '24 h'), (days: 7, label: '7 jours'), (days: 30, label: '30 jours')];

  /// Choix dans une liste (client ou outil) ; renvoie `''` pour « Tous ».
  static Future<String?> _pick(BuildContext context, String title, List<({String value, String label})> options) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(title, style: Theme.of(context).textTheme.titleLarge),
                ),
                ListTile(title: const Text('Tous'), onTap: () => Navigator.pop(context, '')),
                for (final option in options)
                  ListTile(
                    title: Text(option.label),
                    subtitle: option.label == option.value ? null : Text(option.value),
                    onTap: () => Navigator.pop(context, option.value),
                  ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mcpActivityListProvider);
    final notifier = ref.read(mcpActivityListProvider.notifier);
    final options = ref.watch(mcpActivityFilterOptionsProvider);
    final filters = state.value?.query.filters ?? const {};

    Widget choice(String key, Object value, String label) => ChoiceChip(
      label: Text(label),
      selected: filters[key] == value,
      showCheckmark: false,
      onSelected: (_) => notifier.setFilter(key, filters[key] == value ? null : value),
    );

    Widget pickerChip(String key, String label, String title, List<({String value, String label})> values) {
      final current = filters[key] as String?;
      final currentLabel = values.where((v) => v.value == current).firstOrNull?.label ?? current;
      return InputChip(
        label: Text(current == null ? label : currentLabel!),
        selected: current != null,
        showCheckmark: false,
        avatar: const Icon(Icons.arrow_drop_down_rounded, size: 18),
        onPressed: values.isEmpty
            ? null
            : () async {
                final picked = await _pick(context, title, values);
                if (picked != null) {
                  await notifier.setFilter(key, picked.isEmpty ? null : picked);
                }
              },
        onDeleted: current == null ? null : () => notifier.setFilter(key, null),
      );
    }

    return ResourceListScaffold<McpActivity>(
      title: 'Activité MCP',
      searchHint: 'Outil, titre ou erreur…',
      state: state,
      onSearch: notifier.setSearch,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      onRetry: () => ref.invalidate(mcpActivityListProvider),
      emptyIcon: Icons.smart_toy_outlined,
      emptyTitle: 'Aucun appel',
      emptyDescription: 'Rien dans le journal pour ces filtres (90 jours conservés).',
      filterChips: [
        choice('status', 'error', 'Erreurs'),
        choice('status', 'success', 'Réussis'),
        for (final period in _periods) choice('days', period.days, period.label),
        choice('kind', 'tool', 'Outils'),
        choice('kind', 'prompt', 'Commandes'),
        pickerChip('client', 'Client', 'Client', [for (final c in options.clients) (value: c, label: c)]),
        pickerChip('name', 'Outil', 'Outil ou commande', options.tools),
      ],
      itemBuilder: (context, activity) => _ActivityTile(activity),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile(this.activity);

  final McpActivity activity;

  void _showDetails(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final target = activity.target;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(activity.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              SelectableText('${activity.isPrompt ? 'Commande' : 'Outil'} ${activity.name}', style: muted),
              const SizedBox(height: 16),
              Text(
                [
                  activity.client,
                  if (activity.createdAt != null) fullDate(activity.createdAt!),
                  '${activity.durationMs} ms',
                ].join(' · '),
              ),
              if (target != null) ...[
                const SizedBox(height: 12),
                Text('Contenu visé', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                if (target.url == null)
                  Text(target.label)
                else
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => launchUrl(Uri.parse(target.url!), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(target.label),
                  ),
              ],
              if (activity.error != null) ...[
                const SizedBox(height: 12),
                Text('Erreur', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.error)),
                const SizedBox(height: 4),
                SelectableText(activity.error!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListCardTile(
      onTap: () => _showDetails(context),
      leading: IconTile(activity.isPrompt ? Icons.chat_bubble_outline_rounded : Icons.build_outlined),
      title: activity.title,
      subtitle: [activity.client, if (activity.target != null) activity.target!.label].join(' · '),
      meta: activity.createdAt == null ? null : relativeDate(activity.createdAt!),
      badge: activity.success ? null : StatusBadge('Erreur', color: scheme.error),
    );
  }
}
