import 'package:flutter/foundation.dart';

/// Fichier déjà uploadé (CV, musique) : nom d'origine + URL de téléchargement.
@immutable
class UploadedFile {
  const UploadedFile({required this.fileName, required this.url});

  static UploadedFile? fromJson(Map<String, dynamic>? json) =>
      json == null ? null : UploadedFile(fileName: json['file_name'] as String, url: json['url'] as String);

  final String fileName;
  final String url;
}

/// `cv_files.fr` / `cv_files.en` : CV PDF uploadé par langue, sur le profil
/// métier concerné. Sans fichier pour une langue, le CV de l'autre langue
/// sert de secours, sinon le CV est généré automatiquement.
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
