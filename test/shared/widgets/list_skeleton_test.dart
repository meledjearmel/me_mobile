import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/shared/widgets/list_skeleton.dart';

void main() {
  testWidgets('affiche le nombre de lignes demandé et reste silencieux pour les lecteurs d\'écran', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ListSkeleton(itemCount: 4))),
    );

    // Une pulsation continue tourne : un seul pump (pas pumpAndSettle, qui
    // n'aboutirait jamais avec une AnimationController en boucle infinie).
    await tester.pump();

    expect(find.byType(Divider), findsNWidgets(3));
    expect(find.bySemanticsLabel('Chargement en cours'), findsOneWidget);
  });
}
