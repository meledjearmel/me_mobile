import 'package:flutter/material.dart';

import '../../../../core/utils/hex_color.dart';
import '../../data/dashboard.dart';

/// Répartition par domaine (projets ou compétences) : barre colorée + compte.
class DomainDistributionList extends StatelessWidget {
  const DomainDistributionList({super.key, required this.items});

  final List<DomainCount> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final maxCount = items.map((i) => i.count).fold<int>(0, (a, b) => a > b ? a : b);
    final safeMax = maxCount == 0 ? 1 : maxCount;

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: item.count / safeMax,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation(parseHexColor(item.color)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 20, child: Text('${item.count}', textAlign: TextAlign.right)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Répartition des technologies par catégorie.
class CategoryDistributionList extends StatelessWidget {
  const CategoryDistributionList({super.key, required this.items});

  final List<CategoryCount> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${item.label} · ${item.count}',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
