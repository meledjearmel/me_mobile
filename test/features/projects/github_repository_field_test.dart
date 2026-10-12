import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/features/content/github/data/github_repositories.dart';
import 'package:me_mobile/features/projects/presentation/widgets/github_repository_field.dart';

const _repos = [
  GitHubRepository(
    fullName: 'meledjearmel/me',
    name: 'me',
    description: null,
    language: 'PHP',
    stars: 0,
    isPrivate: false,
    isArchived: false,
    isContribution: false,
  ),
  GitHubRepository(
    fullName: 'neocodesupport/fne-client',
    name: 'fne-client',
    description: null,
    language: null,
    stars: 0,
    isPrivate: true,
    isArchived: false,
    isContribution: true,
  ),
];

void main() {
  Future<List<String?>> pump(WidgetTester tester, String? value) async {
    final changes = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GitHubRepositoryField(available: _repos, value: value, onChanged: changes.add),
        ),
      ),
    );
    return changes;
  }

  testWidgets('propose Aucun, les dépôts (privé signalé) et renvoie le choix', (tester) async {
    final changes = await pump(tester, null);

    await tester.tap(find.text('Aucun'));
    await tester.pumpAndSettle();
    expect(find.text('meledjearmel/me'), findsOneWidget);
    await tester.tap(find.text('neocodesupport/fne-client (privé)'));
    await tester.pumpAndSettle();

    expect(changes, ['neocodesupport/fne-client']);
  });

  testWidgets('garde un dépôt enregistré absent de la synchronisation', (tester) async {
    await pump(tester, 'meledjearmel/ancien');

    expect(find.text('meledjearmel/ancien'), findsOneWidget);
  });
}
