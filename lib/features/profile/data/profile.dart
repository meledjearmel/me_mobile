import 'package:flutter/foundation.dart';

import '../../../core/models/translated.dart';

@immutable
class SocialLinks {
  const SocialLinks({this.github, this.linkedin});

  factory SocialLinks.fromJson(Map<String, dynamic>? json) =>
      SocialLinks(github: json?['github'] as String?, linkedin: json?['linkedin'] as String?);

  final String? github;
  final String? linkedin;

  SocialLinks copyWith({String? github, String? linkedin}) =>
      SocialLinks(github: github ?? this.github, linkedin: linkedin ?? this.linkedin);
}

/// Fichier déjà uploadé (CV, musique) : nom d'origine + URL de téléchargement.
@immutable
class UploadedFile {
  const UploadedFile({required this.fileName, required this.url});

  static UploadedFile? fromJson(Map<String, dynamic>? json) =>
      json == null ? null : UploadedFile(fileName: json['file_name'] as String, url: json['url'] as String);

  final String fileName;
  final String url;
}

/// `cv_files.fr` / `cv_files.en` (§4.3). Sans fichier pour une langue, le CV
/// de l'autre langue sert de secours, sinon le CV est généré automatiquement.
@immutable
class CvFiles {
  const CvFiles({this.fr, this.en});

  factory CvFiles.fromJson(Map<String, dynamic>? json) => CvFiles(
        fr: UploadedFile.fromJson(json?['fr'] as Map<String, dynamic>?),
        en: UploadedFile.fromJson(json?['en'] as Map<String, dynamic>?),
      );

  final UploadedFile? fr;
  final UploadedFile? en;
}

@immutable
class Profile {
  const Profile({
    required this.name,
    required this.cvLastName,
    required this.cvFirstName,
    required this.headline,
    required this.bioShort,
    required this.bioFull,
    required this.email,
    required this.phone,
    required this.location,
    required this.socialLinks,
    required this.photoUrl,
    required this.cvPhotoUrl,
    required this.music,
    required this.cvFiles,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        name: json['name'] as String,
        cvLastName: json['cv_last_name'] as String?,
        cvFirstName: json['cv_first_name'] as String?,
        headline: Translated.fromJson(json['headline']),
        bioShort: Translated.fromJson(json['bio_short']),
        bioFull: Translated.fromJson(json['bio_full']),
        email: json['email'] as String,
        phone: json['phone'] as String?,
        location: json['location'] as String?,
        socialLinks: SocialLinks.fromJson(json['social_links'] as Map<String, dynamic>?),
        photoUrl: json['photo_url'] as String?,
        cvPhotoUrl: json['cv_photo_url'] as String?,
        music: UploadedFile.fromJson(json['music'] as Map<String, dynamic>?),
        cvFiles: CvFiles.fromJson(json['cv_files'] as Map<String, dynamic>?),
      );

  final String name;
  final String? cvLastName;
  final String? cvFirstName;
  final Translated headline;
  final Translated bioShort;
  final Translated bioFull;
  final String email;
  final String? phone;
  final String? location;
  final SocialLinks socialLinks;
  final String? photoUrl;
  final String? cvPhotoUrl;

  /// `null` : le site joue une piste par défaut.
  final UploadedFile? music;
  final CvFiles cvFiles;
}
