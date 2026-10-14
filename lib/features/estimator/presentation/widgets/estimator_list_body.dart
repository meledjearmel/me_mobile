import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../shared/widgets/glass.dart';

/// Liste courte chargée en entier (grilles, types de projet, options) :
/// titre, tirer pour rafraîchir, chargement, erreur et état vide.
class EstimatorListBody<T> extends StatelessWidget {
  const EstimatorListBody({
    super.key,
    required this.title,
    required this.value,
    required this.onRefresh,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyText,
    this.subtitle,
    this.header,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final AsyncValue<List<T>> value;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final IconData emptyIcon;
  final String emptyText;

  /// Bloc sous le titre (bouton IA…).
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Builder(
      builder: (context) => RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: pageInsets(context),
          children: [
            Text(title, style: theme.textTheme.headlineMedium),
            if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: muted)],
            const SizedBox(height: 16),
            if (header != null) ...[header!, const SizedBox(height: 12)],
            ...value.when(
              skipLoadingOnRefresh: true,
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (error, _) => [
                Text(error is ApiException ? error.message : 'Erreur.'),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(onPressed: onRefresh, child: const Text('Réessayer')),
                ),
              ],
              data: (items) => items.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(emptyIcon, size: 40, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(emptyText, style: muted, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ]
                  : [
                      for (final (index, item) in items.indexed) ...[
                        if (index > 0) const SizedBox(height: 10),
                        itemBuilder(context, item),
                      ],
                    ],
            ),
            if (footer != null) ...[const SizedBox(height: 16), footer!],
          ],
        ),
      ),
    );
  }
}
