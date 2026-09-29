import 'package:flutter/material.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../data/dashboard.dart';
import '../../data/health_labels.dart';

/// Liste « à compléter » (§4.1). Un brouillon ou un manque doit rester visible
/// sans être anxiogène : icône neutre, pas de rouge alarmant.
class HealthChecklist extends StatelessWidget {
  const HealthChecklist({super.key, required this.items, required this.onTap});

  final List<HealthItem> items;
  final ValueChanged<HealthItem> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = items.where((i) => !i.ok).toList();

    if (pending.isEmpty) {
      return SurfaceCard(
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: context.appColors.success),
            const SizedBox(width: 12),
            const Expanded(child: Text('Tout est à jour, rien à compléter pour l\'instant.')),
          ],
        ),
      );
    }

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final (index, item) in pending.indexed) ...[
            if (index > 0) const Divider(height: 1, indent: 56, endIndent: 16),
            ListTile(
              onTap: () => onTap(item),
              leading: Icon(Icons.radio_button_unchecked_rounded, color: theme.colorScheme.onSurfaceVariant),
              title: Text(healthLabels[item.key]?.title ?? item.key, style: theme.textTheme.bodyMedium),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.count > 0)
                    Text(
                      '${item.count}',
                      style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
