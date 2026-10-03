import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/features/profile/data/profile.dart';

void main() {
  test('parse un profil complet, avec musique uploadée (le CV vit désormais sur les profils métier)', () {
    final profile = Profile.fromJson({
      'id': 1,
      'name': 'Armel Meledje',
      'cv_last_name': 'Meledje',
      'cv_first_name': 'Armel',
      'headline': {'fr': 'Développeur', 'en': 'Developer'},
      'bio_short': {'fr': 'Courte bio', 'en': 'Short bio'},
      'bio_full': {'fr': 'Longue bio', 'en': 'Full bio'},
      'email': 'armel@example.com',
      'phone': '+225 00 00 00 00',
      'location': 'Abidjan',
      'social_links': {'github': 'https://github.com/armel', 'linkedin': null},
      'photo_url': 'https://armeldev.xyz/photo.jpg',
      'cv_photo_url': null,
      'music': {'file_name': 'ambient.mp3', 'url': 'https://armeldev.xyz/music/ambient.mp3'},
    });

    expect(profile.name, 'Armel Meledje');
    expect(profile.headline.fr, 'Développeur');
    expect(profile.socialLinks.github, 'https://github.com/armel');
    expect(profile.socialLinks.linkedin, isNull);
    expect(profile.music!.fileName, 'ambient.mp3');
  });

  test('sans musique ni réseaux sociaux : tout reste null proprement', () {
    final profile = Profile.fromJson({
      'id': 1,
      'name': 'Armel Meledje',
      'cv_last_name': null,
      'cv_first_name': null,
      'headline': {'fr': '', 'en': ''},
      'bio_short': {'fr': '', 'en': ''},
      'bio_full': {'fr': '', 'en': ''},
      'email': 'armel@example.com',
      'phone': null,
      'location': null,
      'social_links': null,
      'photo_url': null,
      'cv_photo_url': null,
      'music': null,
    });

    expect(profile.music, isNull);
    expect(profile.socialLinks.github, isNull);
  });

  Map<String, dynamic> apiProfile(Map<String, dynamic> overrides) => {
    'id': 1,
    'name': 'Armel Meledje',
    'cv_last_name': null,
    'cv_first_name': null,
    'headline': {'fr': 'Développeur', 'en': 'Developer'},
    'bio_short': <String, dynamic>{},
    'bio_full': <String, dynamic>{},
    'email': 'armel@example.com',
    'phone': null,
    'location': null,
    'social_links': null,
    'congratulation_notify_minutes': 10,
    'cv_job_profile_id': null,
    'cv_source': 'generated',
    'photo_url': null,
    'cv_photo_url': null,
    'music': null,
    ...overrides,
  };

  test('lit la source prioritaire du CV et le profil métier par défaut', () {
    final profile = Profile.fromJson(apiProfile({'cv_source': 'uploaded', 'cv_job_profile_id': 3}));

    expect(profile.cvSource, CvSource.uploaded);
    expect(profile.cvJobProfileId, 3);
  });

  test('cv_source absent ou inconnu : CV généré', () {
    expect(Profile.fromJson(apiProfile({'cv_source': null})).cvSource, CvSource.generated);
    expect(Profile.fromJson(apiProfile({'cv_source': 'autre'})).cvSource, CvSource.generated);
  });

  test('social_links en tableau PHP vide [] et textes vides {} ne plantent pas', () {
    final profile = Profile.fromJson(apiProfile({'social_links': <dynamic>[]}));

    expect(profile.socialLinks.github, isNull);
    expect(profile.bioShort.isEmpty, isTrue);
  });
}
