import 'package:flutter/foundation.dart';

import '../../../core/models/translated.dart';
import '../../../core/models/uploaded_file.dart';

@immutable
class SocialLinks {
  const SocialLinks({this.github, this.linkedin});

  /// Tolère `null` et `[]` (tableau PHP vide) en plus de l'objet attendu.
  factory SocialLinks.fromJson(Object? json) => json is Map
      ? SocialLinks(github: json['github'] as String?, linkedin: json['linkedin'] as String?)
      : const SocialLinks();

  final String? github;
  final String? linkedin;

  SocialLinks copyWith({String? github, String? linkedin}) =>
      SocialLinks(github: github ?? this.github, linkedin: linkedin ?? this.linkedin);
}

/// Source du CV servi par le site : le PDF importé sur le profil métier, ou
/// le CV généré à partir du contenu.
enum CvSource {
  uploaded('uploaded', 'CV importé'),
  generated('generated', 'CV généré');

  const CvSource(this.wireValue, this.label);

  final String wireValue;
  final String label;

  /// Défaut côté serveur : `uploaded` (le CV généré sert alors de repli).
  static CvSource fromWire(String? value) => value == generated.wireValue ? generated : uploaded;
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
    required this.congratulationNotifyMinutes,
    this.cvJobProfileId,
    this.cvSource = CvSource.uploaded,
    this.testimonialVideoEnabled = false,
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
    socialLinks: SocialLinks.fromJson(json['social_links']),
    photoUrl: json['photo_url'] as String?,
    cvPhotoUrl: json['cv_photo_url'] as String?,
    music: json['music'] is Map<String, dynamic> ? UploadedFile.fromJson(json['music'] as Map<String, dynamic>) : null,
    congratulationNotifyMinutes: json['congratulation_notify_minutes'] as int? ?? 10,
    cvJobProfileId: json['cv_job_profile_id'] as int?,
    cvSource: CvSource.fromWire(json['cv_source'] as String?),
    testimonialVideoEnabled: json['testimonial_video_enabled'] as bool? ?? false,
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

  /// Au plus une notification push de félicitations par motif sur ce nombre
  /// de minutes (0 = à chaque envoi).
  final int congratulationNotifyMinutes;

  /// Profil métier dont le CV est proposé par défaut (`null` : aucun).
  final int? cvJobProfileId;

  /// Source prioritaire du CV, pour tout le site.
  final CvSource cvSource;

  /// Les visiteurs peuvent joindre ou filmer une vidéo avec leur avis.
  final bool testimonialVideoEnabled;
}
