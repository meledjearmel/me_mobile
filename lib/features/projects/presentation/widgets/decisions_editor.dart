import 'package:flutter/material.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/models/translated.dart';
import '../../../../shared/widgets/translated_field.dart';
import '../../data/project.dart';

/// Choix techniques argumentés ([Decision.maxCount] au plus) : le choix et sa
/// raison, bilingues, réordonnables. [errorFor] reçoit une clé de validation
/// Laravel (`decisions.0.choice.fr`…).
class DecisionsEditor extends StatefulWidget {
  const DecisionsEditor({super.key, required this.value, required this.onChanged, this.errorFor});

  final List<Decision> value;
  final ValueChanged<List<Decision>> onChanged;
  final String? Function(String key)? errorFor;

  @override
  State<DecisionsEditor> createState() => _DecisionsEditorState();
}

class _DecisionsEditorState extends State<DecisionsEditor> {
  // Une clé stable par ligne : chaque champ garde son état en cas de réordonnancement.
  late List<_Entry> _entries = [for (final decision in widget.value) _Entry(decision)];

  @override
  void didUpdateWidget(DecisionsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = [for (final entry in _entries) entry.decision];
    if (!_same(current, widget.value)) {
      _entries = [for (final decision in widget.value) _Entry(decision)];
    }
  }

  static bool _same(List<Decision> a, List<Decision> b) {
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

  void _emit() => widget.onChanged([for (final entry in _entries) entry.decision]);

  void _update(int index, Decision decision) {
    _entries[index].decision = decision;
    _emit();
  }

  void _add() {
    setState(() => _entries = [..._entries, _Entry(const Decision(choice: Translated(), reason: Translated()))]);
    _emit();
  }

  void _remove(int index) {
    setState(() => _entries = [..._entries]..removeAt(index));
    _emit();
  }

  void _move(int index, int delta) {
    setState(() {
      final entries = [..._entries];
      final moved = entries.removeAt(index);
      entries.insert(index + delta, moved);
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
        Text('Choix techniques (${_entries.length}/${Decision.maxCount})', style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          'Chaque choix avec sa raison, en français et en anglais.',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        const SizedBox(height: 8),
        for (final (index, entry) in _entries.indexed)
          Padding(
            key: entry.key,
            padding: const EdgeInsets.only(bottom: 8),
            child: _DecisionRow(
              index: index,
              decision: entry.decision,
              onChanged: (decision) => _update(index, decision),
              onRemove: () => _remove(index),
              onMoveUp: index == 0 ? null : () => _move(index, -1),
              onMoveDown: index == _entries.length - 1 ? null : () => _move(index, 1),
              errorFor: (field) => widget.errorFor?.call('decisions.$index.$field'),
            ),
          ),
        if (_entries.length < Decision.maxCount)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un choix technique'),
            ),
          ),
      ],
    );
  }
}

class _Entry {
  _Entry(this.decision);

  final key = UniqueKey();
  Decision decision;
}

class _DecisionRow extends StatelessWidget {
  const _DecisionRow({
    required this.index,
    required this.decision,
    required this.onChanged,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.errorFor,
  });

  final int index;
  final Decision decision;
  final ValueChanged<Decision> onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final String? Function(String field) errorFor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = index + 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TranslatedField(
              label: 'Choix $number',
              value: decision.choice,
              maxLength: 160,
              errorFr: errorFor('choice.fr'),
              errorEn: errorFor('choice.en'),
              onChanged: (choice) => onChanged(Decision(choice: choice, reason: decision.reason)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TranslatedField(
              label: 'Pourquoi ce choix',
              value: decision.reason,
              maxLines: 4,
              maxLength: 600,
              errorFr: errorFor('reason.fr'),
              errorEn: errorFor('reason.en'),
              onChanged: (reason) => onChanged(Decision(choice: decision.choice, reason: reason)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Monter le choix $number',
                onPressed: onMoveUp,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                tooltip: 'Descendre le choix $number',
                onPressed: onMoveDown,
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
              IconButton(
                tooltip: 'Retirer le choix $number',
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
