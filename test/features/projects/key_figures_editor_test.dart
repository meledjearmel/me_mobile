import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/app/theme/app_palette_variant.dart';
import 'package:me_mobile/app/theme/app_theme.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/features/projects/data/project.dart';
import 'package:me_mobile/features/projects/presentation/widgets/key_figures_editor.dart';
import 'package:me_mobile/shared/widgets/translated_field.dart';

Widget _host(Widget child) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.build(AppPaletteVariant.values.first, Brightness.light),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

/// Tient la liste comme le ferait le formulaire.
class _Harness extends StatefulWidget {
  const _Harness({required this.initial, required this.onChanged, this.errors = const {}});

  final List<KeyFigure> initial;
  final ValueChanged<List<KeyFigure>> onChanged;
  final Map<String, String> errors;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late var _figures = widget.initial;

  @override
  Widget build(BuildContext context) => KeyFiguresEditor(
    value: _figures,
    errorFor: (key) => widget.errors[key],
    onChanged: (figures) {
      setState(() => _figures = figures);
      widget.onChanged(figures);
    },
  );
}

void main() {
  const fast = KeyFigure(
    value: '3×',
    label: Translated(fr: 'plus rapide', en: 'faster'),
  );
  const cheap = KeyFigure(
    value: '40 %',
    label: Translated(fr: 'de coûts en moins', en: 'lower costs'),
  );

  testWidgets('ajoute un chiffre et le remplit en FR puis en EN', (tester) async {
    var last = <KeyFigure>[];
    await tester.pumpWidget(_host(_Harness(initial: const [], onChanged: (f) => last = f)));

    expect(find.text('Chiffres clés (0/4)'), findsOneWidget);
    await tester.tap(find.text('Ajouter un chiffre clé'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Valeur du chiffre 1'), '12 k');
    await tester.enterText(find.widgetWithText(TextField, 'Français'), 'utilisateurs');
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'English'), 'users');
    await tester.pump();

    expect(last, const [
      KeyFigure(
        value: '12 k',
        label: Translated(fr: 'utilisateurs', en: 'users'),
      ),
    ]);
    expect(find.text('Chiffres clés (1/4)'), findsOneWidget);
  });

  testWidgets('réordonne et retire, en gardant chaque valeur avec sa ligne', (tester) async {
    var last = <KeyFigure>[];
    await tester.pumpWidget(_host(_Harness(initial: const [fast, cheap], onChanged: (f) => last = f)));

    await tester.tap(find.byTooltip('Descendre le chiffre 1'));
    await tester.pumpAndSettle();
    expect(last, const [cheap, fast]);
    // Le champ de la ligne déplacée suit (clé stable par ligne).
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Valeur du chiffre 1')).controller!.text, '40 %');

    await tester.tap(find.byTooltip('Retirer le chiffre 1'));
    await tester.pumpAndSettle();
    expect(last, const [fast]);
  });

  testWidgets('masque l\'ajout à 4 chiffres et affiche les erreurs du serveur', (tester) async {
    await tester.pumpWidget(
      _host(
        _Harness(
          initial: const [fast, cheap, fast, cheap],
          onChanged: (_) {},
          errors: const {'key_figures.1.value': 'La valeur est trop longue.'},
        ),
      ),
    );

    expect(find.text('Ajouter un chiffre clé'), findsNothing);
    expect(find.text('La valeur est trop longue.'), findsOneWidget);
  });

  testWidgets('champ facultatif vide : aucun avertissement ; une seule langue : l\'autre est signalée', (tester) async {
    Widget field(Translated value) =>
        _host(TranslatedField(label: 'Accroche', value: value, optional: true, onChanged: (_) {}));

    await tester.pumpWidget(field(const Translated()));
    expect(find.text('Vide dans cette langue.'), findsNothing);

    await tester.pumpWidget(field(const Translated(en: 'A tagline')));
    expect(find.text('Vide dans cette langue.'), findsOneWidget);
  });
}
