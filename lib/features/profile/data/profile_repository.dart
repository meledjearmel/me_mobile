import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/multipart.dart';
import '../../../core/models/translated.dart';
import 'profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(apiClientProvider)));

/// `GET|PATCH /v1/profile`, `DELETE /v1/profile/music` (§4.3).
///
/// Le CV PDF n'est plus attaché ici : il vit sur chaque profil métier
/// (`JobProfileRepository`), puisque le CV généré est ciblé par profil.
///
/// Ressource unique : la modification valide **le formulaire complet** (§3.5),
/// toujours renvoyer tous les champs, même inchangés.
class ProfileRepository {
  const ProfileRepository(this._api);

  final ApiClient _api;

  Future<Profile> get() async => Profile.fromJson(await _api.get('/v1/profile') as Map<String, dynamic>);

  /// `_method=PATCH` en `POST` multipart (§3.4) : seul moyen d'envoyer un
  /// fichier, que la requête en contienne un ou non.
  Future<Profile> update({
    required String name,
    required String? cvLastName,
    required String? cvFirstName,
    required Translated headline,
    required Translated bioShort,
    required Translated bioFull,
    required String email,
    required String? phone,
    required String? location,
    required SocialLinks socialLinks,
    MultipartFile? photo,
    MultipartFile? cvPhoto,
    MultipartFile? music,
    int? congratulationNotifyMinutes,
    CvSource? cvSource,
    int? cvJobProfileId,
    bool clearCvJobProfile = false,
    bool? testimonialVideoEnabled,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = buildFormData({
      'name': name,
      'cv_last_name': cvLastName,
      'cv_first_name': cvFirstName,
      'headline': headline,
      'bio_short': bioShort,
      'bio_full': bioFull,
      'email': email,
      'phone': phone,
      'location': location,
      'social_links': {'github': socialLinks.github, 'linkedin': socialLinks.linkedin},
      if (photo != null) 'photo': photo,
      if (cvPhoto != null) 'cv_photo': cvPhoto,
      if (music != null) 'music': music,
      if (congratulationNotifyMinutes != null) 'congratulation_notify_minutes': congratulationNotifyMinutes,
      // Facultatifs (`sometimes`) : absents, l'API garde la valeur actuelle.
      if (cvSource != null) 'cv_source': cvSource.wireValue,
      if (cvJobProfileId != null || clearCvJobProfile) 'cv_job_profile_id': cvJobProfileId,
      if (testimonialVideoEnabled != null) 'testimonial_video_enabled': testimonialVideoEnabled,
    }, method: 'PATCH');

    final json = await _api.upload('/v1/profile', form, onProgress: onProgress);
    return Profile.fromJson(json as Map<String, dynamic>);
  }

  /// Change seulement le délai des notifications de félicitations : le reste
  /// du profil est renvoyé tel quel (formulaire complet, §3.5).
  Future<Profile> updateCongratulationNotifyMinutes(Profile profile, int minutes) => update(
    name: profile.name,
    cvLastName: profile.cvLastName,
    cvFirstName: profile.cvFirstName,
    headline: profile.headline,
    bioShort: profile.bioShort,
    bioFull: profile.bioFull,
    email: profile.email,
    phone: profile.phone,
    location: profile.location,
    socialLinks: profile.socialLinks,
    congratulationNotifyMinutes: minutes,
  );

  Future<void> deleteMusic() => _api.delete('/v1/profile/music');
}
