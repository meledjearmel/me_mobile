import 'package:flutter/material.dart';

/// Projets montrés sur la page, dans l'ordre : on en ajoute, on les glisse
/// pour les réordonner, on les retire. [max] au plus.
class OrderedProjectsField extends StatelessWidget {
  const OrderedProjectsField({
    super.key,
    required this.options,
    required this.selectedIds,
    required this.onChanged,
    this.max = 6,
    this.error,
  });

  final List<({int id, String label})> options;
  final List<int> selectedIds;
  final ValueChanged<List<int>> onChanged;
  final int max;
  final String? error;

  String _labelOf(int id) => options.where((o) => o.id == id).firstOrNull?.label ?? 'Projet #$id';

  Future<void> _add(BuildContext context) async {
    final remaining = options.where((o) => !selectedIds.contains(o.id)).toList();
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: remaining.isEmpty
              ? const Center(child: Text('Tous les projets sont déjà ajoutés.'))
              : ListView(
                  children: [
                    for (final option in remaining)
                      ListTile(
                        leading: const Icon(Icons.work_outline_rounded),
                        title: Text(option.label),
                        onTap: () => Navigator.pop(context, option.id),
                      ),
                  ],
                ),
        ),
      ),
    );
    if (picked != null) {
      onChanged([...selectedIds, picked]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Projets montrés (${selectedIds.length}/$max)', style: theme.textTheme.labelLarge)),
            TextButton.icon(
              onPressed: selectedIds.length >= max || options.isEmpty ? null : () => _add(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        if (selectedIds.isEmpty)
          Text('Aucun projet : la page n\'en montrera pas.', style: muted)
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (oldIndex, newIndex) {
              final ids = [...selectedIds];
              ids.insert(newIndex, ids.removeAt(oldIndex));
              onChanged(ids);
            },
            children: [
              for (final (index, id) in selectedIds.indexed)
                ListTile(
                  key: ValueKey(id),
                  contentPadding: EdgeInsets.zero,
                  leading: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_indicator_rounded)),
                  title: Text('${index + 1}. ${_labelOf(id)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    tooltip: 'Retirer',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => onChanged([...selectedIds]..remove(id)),
                  ),
                ),
            ],
          ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        ],
      ],
    );
  }
}
