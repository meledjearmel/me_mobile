import 'package:flutter/material.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/models/translated.dart';
import '../../../../shared/widgets/translated_field.dart';
import '../../data/project.dart';

/// Chiffres clés de l'étude de cas ([KeyFigure.maxCount] au plus) : valeur
/// courte et libellé bilingue, réordonnables. [errorFor] reçoit une clé de
/// validation Laravel (`key_figures.0.value`…).
class KeyFiguresEditor extends StatefulWidget {
  const KeyFiguresEditor({super.key, required this.value, required this.onChanged, this.errorFor});

  final List<KeyFigure> value;
  final ValueChanged<List<KeyFigure>> onChanged;
  final String? Function(String key)? errorFor;

  @override
  State<KeyFiguresEditor> createState() => _KeyFiguresEditorState();
}

class _KeyFiguresEditorState extends State<KeyFiguresEditor> {
  // Une clé stable par ligne : chaque champ garde son état en cas de réordonnancement.
  late List<_Entry> _entries = [for (final figure in widget.value) _Entry(figure)];

  @override
  void didUpdateWidget(KeyFiguresEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = [for (final entry in _entries) entry.figure];
    if (!_sameFigures(current, widget.value)) {
      _entries = [for (final figure in widget.value) _Entry(figure)];
    }
  }

  static bool _sameFigures(List<KeyFigure> a, List<KeyFigure> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  void _emit() => widget.onChanged([for (final entry in _entries) entry.figure]);

  void _update(int index, KeyFigure figure) {
    _entries[index].figure = figure;
    _emit();
  }

  void _add() {
    setState(() => _entries = [..._entries, _Entry(const KeyFigure(value: '', label: Translated()))]);
    _emit();
  }

  void _remove(int index) {
    setState(() => _entries = [..._entries]..removeAt(index));
    _emit();
  }

  void _move(int index, int delta) {
    final target = index + delta;
    setState(() {
      final entries = [..._entries];
      final moved = entries.removeAt(index);
      entries.insert(target, moved);
      _entries = entries;
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.appColors.muted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Chiffres clés (${_entries.length}/${KeyFigure.maxCount})', style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text('Affichés sous le résultat, dans cet ordre.', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        const SizedBox(height: 8),
        for (final (index, entry) in _entries.indexed)
          Padding(
            key: entry.key,
            padding: const EdgeInsets.only(bottom: 8),
            child: _KeyFigureRow(
              index: index,
              figure: entry.figure,
              onChanged: (figure) => _update(index, figure),
              onRemove: () => _remove(index),
              onMoveUp: index == 0 ? null : () => _move(index, -1),
              onMoveDown: index == _entries.length - 1 ? null : () => _move(index, 1),
              errorFor: (field) => widget.errorFor?.call('key_figures.$index.$field'),
            ),
          ),
        if (_entries.length < KeyFigure.maxCount)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un chiffre clé'),
            ),
          ),
      ],
    );
  }
}

class _Entry {
  _Entry(this.figure);

  final key = UniqueKey();
  KeyFigure figure;
}

class _KeyFigureRow extends StatefulWidget {
  const _KeyFigureRow({
    required this.index,
    required this.figure,
    required this.onChanged,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.errorFor,
  });

  final int index;
  final KeyFigure figure;
  final ValueChanged<KeyFigure> onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final String? Function(String field) errorFor;

  @override
  State<_KeyFigureRow> createState() => _KeyFigureRowState();
}

class _KeyFigureRowState extends State<_KeyFigureRow> {
  late final _value = TextEditingController(text: widget.figure.value);

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = widget.index + 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextField(
              controller: _value,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: 'Valeur du chiffre $number',
                hintText: '3×, 40 %, 12 k…',
                errorText: widget.errorFor('value'),
              ),
              onChanged: (value) => widget.onChanged(KeyFigure(value: value, label: widget.figure.label)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TranslatedField(
              label: 'Libellé du chiffre $number',
              value: widget.figure.label,
              maxLength: 80,
              errorFr: widget.errorFor('label.fr'),
              errorEn: widget.errorFor('label.en'),
              onChanged: (label) => widget.onChanged(KeyFigure(value: _value.text, label: label)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Monter le chiffre $number',
                onPressed: widget.onMoveUp,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                tooltip: 'Descendre le chiffre $number',
                onPressed: widget.onMoveDown,
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
              IconButton(
                tooltip: 'Retirer le chiffre $number',
                onPressed: widget.onRemove,
                icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
