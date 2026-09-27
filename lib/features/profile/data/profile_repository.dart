import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/multipart.dart';
import '../../../core/models/translated.dart';
import 'profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(apiClientProvider)));

/// `GET|PATCH /v1/profile`, `DELETE /v1/profile/music`, `DELETE /v1/profile/cv/{fr|en}` (§4.3).
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
    MultipartFile? cvFileFr,
    MultipartFile? cvFileEn,
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
      if (cvFileFr != null) 'cv_file_fr': cvFileFr,
      if (cvFileEn != null) 'cv_file_en': cvFileEn,
    }, method: 'PATCH');

    final json = await _api.upload('/v1/profile', form, onProgress: onProgress);
    return Profile.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteMusic() => _api.delete('/v1/profile/music');

  /// [locale] : `'fr'` ou `'en'`.
  Future<void> deleteCv(String locale) => _api.delete('/v1/profile/cv/$locale');
}
