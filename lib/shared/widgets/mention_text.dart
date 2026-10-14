import 'package:flutter/material.dart';

import '../../features/blog/data/mentions.dart';

/// Texte dont les jetons `@[Titre](project:12)` s'affichent en puces
/// (icône du type + titre), jamais en jeton brut.
class MentionText extends StatelessWidget {
  const MentionText(this.text, {super.key, this.style, this.maxLines});

  final String text;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyMedium;
    final segments = parseMentions(text);

    // Texte tronqué (liste) : les puces ne se coupent pas, on garde du texte simple.
    if (maxLines != null) {
      return Text(stripMentions(text), style: base, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (final segment in segments)
            if (segment.mention == null)
              TextSpan(text: segment.text)
            else
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(segment.mention!.icon, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            segment.text,
                            style: base?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Contrôleur de saisie qui montre chaque jeton `@[Titre](type:id)` par son
/// seul titre, en couleur : la syntaxe reste dans le texte mais est rendue
/// invisible, pour ne jamais afficher le jeton brut pendant l'édition.
class MentionEditingController extends TextEditingController {
  MentionEditingController({super.text});

  static const _hidden = TextStyle(fontSize: 0.01, color: Color(0x00000000), letterSpacing: 0);

  /// Ajoute la mention à la position du curseur (à la fin s'il n'y en a pas).
  void insertMention(Mentionable mention) {
    final selection = this.selection;
    final at = selection.isValid ? selection.end : text.length;
    final before = text.substring(0, at);
    final needsSpace = before.isNotEmpty && !before.endsWith(' ') && !before.endsWith('\n');
    final inserted = '${needsSpace ? ' ' : ''}${mention.markup} ';
    value = TextEditingValue(
      text: before + inserted + text.substring(at),
      selection: TextSelection.collapsed(offset: at + inserted.length),
    );
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final accent = style?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600);
    final children = <TextSpan>[];
    for (final segment in parseMentions(text)) {
      final mention = segment.mention;
      if (mention == null) {
        children.add(TextSpan(text: segment.text));
        continue;
      }
      // Même nombre de caractères que le jeton : seul le titre est visible.
      children
        ..add(const TextSpan(text: '@[', style: _hidden))
        ..add(TextSpan(text: segment.text, style: accent))
        ..add(TextSpan(text: '](${mention.kind}:${mention.id})', style: _hidden));
    }
    return TextSpan(style: style, children: children);
  }
}
