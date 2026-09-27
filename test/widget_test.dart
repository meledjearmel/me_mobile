import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:me_mobile/app/app.dart';

void main() {
  testWidgets('Affiche l\'écran de démarrage au lancement', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MeAdminApp()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
