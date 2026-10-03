import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/app/theme/app_palette_variant.dart';
import 'package:me_mobile/app/theme/app_theme.dart';
import 'package:me_mobile/core/models/publication_status.dart';
import 'package:me_mobile/core/models/translated.dart';
import 'package:me_mobile/core/models/uploaded_file.dart';
import 'package:me_mobile/features/content/job_profiles/data/job_profile.dart';
import 'package:me_mobile/features/profile/application/profile_providers.dart';
import 'package:me_mobile/features/profile/data/profile.dart';
import 'package:me_mobile/features/profile/presentation/widgets/cv_settings_card.dart';

JobProfile _jobProfile(int id, String label, {CvFiles cvFiles = const CvFiles(), int sortOrder = 0}) => JobProfile(
  id: id,
  key: 'p$id',
  label: Translated(fr: label, en: label),
  description: const Translated(),
  heroTitle: const Translated(),
  heroWords: const Translated(),
  cvDescription: const Translated(),
  sortOrder: sortOrder,
  status: PublicationStatus.published,
  cvFiles: cvFiles,
);

final _mobile = _jobProfile(
  1,
  'Développeur mobile',
  cvFiles: const CvFiles(
    fr: UploadedFile(fileName: 'cv-armel-fr.pdf', url: 'https://armeldev.xyz/cv-fr.pdf'),
  ),
);
final _web = _jobProfile(2, 'Développeur web', sortOrder: 1);

class _Harness extends StatefulWidget {
  const _Harness({required this.jobProfileId, required this.source});

  final int? jobProfileId;
  final CvSource source;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late int? id = widget.jobProfileId;
  late CvSource source = widget.source;

  @override
  Widget build(BuildContext context) => CvSettingsCard(
    jobProfileId: id,
    source: source,
    onJobProfileChanged: (value) => setState(() => id = value),
    onSourceChanged: (value) => setState(() => source = value),
  );
}

Future<_HarnessState> _pump(WidgetTester tester, {int? jobProfileId, CvSource source = CvSource.uploaded}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        publishedJobProfilesProvider.overrideWith((ref) async => [_mobile, _web]),
      ],
      child: MaterialApp(
        theme: AppTheme.build(AppPaletteVariant.values.first, Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: _Harness(jobProfileId: jobProfileId, source: source),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<_HarnessState>(find.byType(_Harness));
}

void main() {
  testWidgets('profil choisi : affiche ses PDF, le repli de langue et l\'explication', (tester) async {
    await _pump(tester, jobProfileId: 1);

    expect(find.text('Développeur mobile'), findsOneWidget);
    expect(find.text('cv-armel-fr.pdf'), findsOneWidget);
    expect(find.text('aucun : repli sur le FR'), findsOneWidget);
    expect(find.text(cvSourceExplanation(CvSource.uploaded)), findsOneWidget);
  });

  testWidgets('sans PDF et source « importé » : note de repli sur le CV généré', (tester) async {
    final state = await _pump(tester, jobProfileId: 2);
    expect(find.text('Aucun PDF importé : le CV généré sera servi.'), findsOneWidget);

    await tester.tap(find.text('CV généré'));
    await tester.pumpAndSettle();

    expect(state.source, CvSource.generated);
    expect(find.text('Aucun PDF importé : le CV généré sera servi.'), findsNothing);
    expect(find.text(cvSourceExplanation(CvSource.generated)), findsOneWidget);
  });

  testWidgets('choisir « Automatique » renvoie null', (tester) async {
    final state = await _pump(tester, jobProfileId: 1);

    await tester.tap(find.text('Développeur mobile').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Automatique (premier profil publié)').last);
    await tester.pumpAndSettle();
    expect(state.id, isNull);
  });

  testWidgets('un profil choisi mais dépublié est signalé', (tester) async {
    await _pump(tester, jobProfileId: 99);

    expect(find.textContaining('n\'est plus publié'), findsOneWidget);
    // Le site se rabat sur le premier profil publié : ses PDF sont montrés.
    expect(find.text('cv-armel-fr.pdf'), findsOneWidget);
  });
}
