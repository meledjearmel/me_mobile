import 'package:flutter/material.dart';

typedef SelectableOption = ({int id, String label, Color? color});

/// Sélecteur à choix multiples (domaines, technologies, profils métier,
/// projets liés…) : puces des éléments choisis + feuille de recherche.
class MultiSelectField extends StatelessWidget {
  const MultiSelectField({
    super.key,
    required this.label,
    required this.options,
    required this.selectedIds,
    required this.onChanged,
    this.emptyLabel = 'Aucun disponible pour l\'instant',
  });

  final String label;
  final List<SelectableOption> options;
  final List<int> selectedIds;
  final ValueChanged<List<int>> onChanged;
  final String emptyLabel;

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PickerSheet(label: label, options: options, initiallySelected: selectedIds),
    );
    if (result != null) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = options.where((o) => selectedIds.contains(o.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: options.isEmpty ? null : () => _openPicker(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(selected.isEmpty ? 'Ajouter' : 'Modifier'),
            ),
          ],
        ),
        if (options.isEmpty)
          Text(emptyLabel, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
        else if (selected.isEmpty)
          Text('Aucun sélectionné', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in selected)
                Chip(
                  avatar: option.color != null ? CircleAvatar(backgroundColor: option.color) : null,
                  label: Text(option.label),
                  onDeleted: () => onChanged([...selectedIds]..remove(option.id)),
                ),
            ],
          ),
      ],
    );
  }
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({required this.label, required this.options, required this.initiallySelected});

  final String label;
  final List<SelectableOption> options;
  final List<int> initiallySelected;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late final _selected = {...widget.initiallySelected};
  var _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options
        .where((o) => o.label.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(child: Text(widget.label, style: Theme.of(context).textTheme.titleMedium)),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selected.toList()),
                    child: const Text('Valider'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (value) => setState(() => _search = value),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Rechercher…'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final option = filtered[index];
                  return CheckboxListTile(
                    value: _selected.contains(option.id),
                    title: Text(option.label),
                    secondary: option.color != null ? CircleAvatar(backgroundColor: option.color, radius: 10) : null,
                    onChanged: (checked) => setState(() {
                      if (checked ?? false) {
                        _selected.add(option.id);
                      } else {
                        _selected.remove(option.id);
                      }
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
