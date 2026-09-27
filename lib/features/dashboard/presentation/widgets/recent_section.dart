import 'package:flutter/material.dart';

import '../../../../core/utils/relative_date.dart';

typedef RecentItem = ({int id, String title, String subtitle, bool isNew, DateTime? at});

/// Les 5 derniers éléments d'une ressource de la boîte de réception (§4.1).
class RecentSection extends StatelessWidget {
  const RecentSection({
    super.key,
    required this.title,
    required this.items,
    required this.onTapItem,
    required this.onSeeAll,
    required this.emptyLabel,
  });

  final String title;
  final List<RecentItem> items;
  final ValueChanged<int> onTapItem;
  final VoidCallback onSeeAll;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const Spacer(),
            if (items.isNotEmpty)
              TextButton(onPressed: onSeeAll, child: const Text('Voir tout')),
          ],
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(emptyLabel, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (index, item) in items.indexed) ...[
                  if (index > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    dense: true,
                    onTap: () => onTapItem(item.id),
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: item.isNew ? FontWeight.w700 : FontWeight.w400),
                    ),
                    subtitle: Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: item.at == null
                        ? null
                        : Text(relativeDate(item.at!), style: theme.textTheme.bodySmall),
                    leading: SizedBox(
                      width: 12,
                      child: item.isNew ? Icon(Icons.circle, size: 8, color: theme.colorScheme.primary) : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
