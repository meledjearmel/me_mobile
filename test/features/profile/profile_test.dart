import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/features/profile/data/profile.dart';

void main() {
  test('parse un profil complet, avec CV et musique uploadés', () {
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
      'photo_url': 'https://me.armeldev.xyz/photo.jpg',
      'cv_photo_url': null,
      'music': {'file_name': 'ambient.mp3', 'url': 'https://me.armeldev.xyz/music/ambient.mp3'},
      'cv_files': {
        'fr': {'file_name': 'cv-fr.pdf', 'url': 'https://me.armeldev.xyz/cv/fr.pdf'},
        'en': null,
      },
    });

    expect(profile.name, 'Armel Meledje');
    expect(profile.headline.fr, 'Développeur');
    expect(profile.socialLinks.github, 'https://github.com/armel');
    expect(profile.socialLinks.linkedin, isNull);
    expect(profile.music!.fileName, 'ambient.mp3');
    expect(profile.cvFiles.fr!.fileName, 'cv-fr.pdf');
    expect(profile.cvFiles.en, isNull);
  });

  test('sans musique ni CV uploadés, sans réseaux sociaux : tout reste null proprement', () {
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
      'cv_files': null,
    });

    expect(profile.music, isNull);
    expect(profile.cvFiles.fr, isNull);
    expect(profile.cvFiles.en, isNull);
    expect(profile.socialLinks.github, isNull);
  });
}
