import 'package:flutter/material.dart';

import '../../../../core/utils/relative_date.dart';
import '../../../../shared/widgets/surfaces.dart';

typedef RecentItem = ({int id, String title, String subtitle, bool isNew, DateTime? at});

/// Les derniers éléments d'une ressource de la boîte de réception (§4.1),
/// en cartes séparées : initiales, nom, extrait, date et point or si non lu.
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
        SectionHeader(title, actionLabel: items.isEmpty ? null : 'Voir tout', onAction: onSeeAll),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(emptyLabel, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
        else
          for (final (index, item) in items.indexed) ...[
            if (index > 0) const SizedBox(height: 8),
            RecentTile(item: item, onTap: () => onTapItem(item.id)),
          ],
      ],
    );
  }
}

class RecentTile extends StatelessWidget {
  const RecentTile({super.key, required this.item, required this.onTap});

  final RecentItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListCardTile(
      onTap: onTap,
      leading: InitialsTile(item.title),
      title: item.title,
      unread: item.isNew,
      meta: item.at == null ? null : relativeDate(item.at!),
      subtitle: item.subtitle,
    );
  }
}
