import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/hex_color.dart';

const _presetColors = [
  '#71B7F4',
  '#FC9073',
  '#FFDA3F',
  '#22C55E',
  '#A855F7',
  '#EF4444',
  '#F97316',
  '#0EA5E9',
];

/// Sélecteur de couleur d'accent (`#RRGGBB`) : nuances prédéfinies + saisie
/// manuelle de l'hexadécimal (§4.3).
class ColorPickerField extends StatefulWidget {
  const ColorPickerField({super.key, required this.value, required this.onChanged, this.error});

  final String? value;
  final ValueChanged<String?> onChanged;
  final String? error;

  @override
  State<ColorPickerField> createState() => _ColorPickerFieldState();
}

class _ColorPickerFieldState extends State<ColorPickerField> {
  late final _controller = TextEditingController(text: widget.value ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isValid = widget.value == null || RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(widget.value!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Couleur d\'accent', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final hex in _presetColors)
              GestureDetector(
                onTap: () {
                  _controller.text = hex;
                  widget.onChanged(hex);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: parseHexColor(hex),
                    shape: BoxShape.circle,
                    border: widget.value?.toUpperCase() == hex
                        ? Border.all(color: theme.colorScheme.onSurface, width: 2)
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          maxLength: 7,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]'))],
          onChanged: (value) => widget.onChanged(value.isEmpty ? null : value),
          decoration: InputDecoration(
            hintText: '#RRGGBB',
            errorText: widget.error ?? (isValid ? null : 'Format attendu : #RRGGBB'),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: CircleAvatar(
                radius: 10,
                backgroundColor: isValid && widget.value != null ? parseHexColor(widget.value!) : theme.colorScheme.surfaceContainerHigh,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
