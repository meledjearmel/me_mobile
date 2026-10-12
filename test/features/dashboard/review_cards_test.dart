import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/app/theme/app_palette_variant.dart';
import 'package:me_mobile/app/theme/app_theme.dart';
import 'package:me_mobile/features/dashboard/data/dashboard.dart';
import 'package:me_mobile/features/dashboard/presentation/widgets/review_cards.dart';

void main() {
  test('todo : brouillons et révisions, hors total de la boîte de réception', () {
    final todo = DashboardTodo.fromJson({
      'contacts': 1,
      'engagements': 0,
      'testimonials': 0,
      'project_drafts': 2,
      'post_drafts': 1,
      'content_drafts': 4,
      'revisions': 3,
    });

    expect(todo.drafts, 7);
    expect(todo.revisions, 3);
    expect(todo.total, 1);
    expect(DashboardTodo.fromJson({}).drafts, 0);
  });

  testWidgets('cartes Brouillons et Révisions ; la feuille détaille les brouillons', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(AppPaletteVariant.values.first, Brightness.light),
          home: const Scaffold(
            body: ReviewCards(
              todo: DashboardTodo(
                contacts: 0,
                engagements: 0,
                testimonials: 0,
                projectDrafts: 2,
                postDrafts: 1,
                contentDrafts: 4,
                revisions: 3,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Brouillons à relire'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Révisions à relire'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Brouillons à relire'));
    await tester.pumpAndSettle();

    expect(find.text('Projets'), findsOneWidget);
    expect(find.text('Articles'), findsOneWidget);
    expect(find.text('Autres contenus (4)'), findsOneWidget);
    expect(find.text('Compétences'), findsOneWidget);
  });
}
