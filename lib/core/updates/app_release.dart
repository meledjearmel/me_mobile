import 'dart:io';

import 'package:crypto/crypto.dart';

/// Version de l'app publiée côté portfolio (`GET /v1/app/latest`).
class AppRelease {
  const AppRelease({
    required this.id,
    required this.versionName,
    required this.buildNumber,
    required this.notes,
    required this.size,
    required this.sha256,
    required this.downloadUrl,
    this.publishedAt,
  });

  factory AppRelease.fromJson(Map<String, dynamic> json) => AppRelease(
    id: json['id'] as int,
    versionName: json['version_name'] as String,
    buildNumber: json['build_number'] as int,
    notes: json['notes'] as String? ?? '',
    size: json['size'] as int? ?? 0,
    sha256: json['sha256'] as String,
    downloadUrl: json['download_url'] as String,
    publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
  );

  final int id;
  final String versionName;
  final int buildNumber;
  final String notes;

  /// Taille de l'APK en octets.
  final int size;
  final String sha256;

  /// URL signée valable 30 minutes, sans en-tête d'authentification.
  final String downloadUrl;
  final DateTime? publishedAt;

  /// Seul le numéro de build compte : le nom de version est purement affiché.
  bool isNewerThan(int installedBuildNumber) => buildNumber > installedBuildNumber;
}

/// Numéro de build installé, tel que `package_info_plus` le renvoie (texte).
/// Une valeur illisible vaut 0 : toute version publiée sera alors proposée.
int parseBuildNumber(String raw) => int.tryParse(raw.trim()) ?? 0;

/// Vrai si l'empreinte SHA-256 de [file] vaut [expected] (casse ignorée).
Future<bool> fileMatchesSha256(File file, String expected) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString() == expected.trim().toLowerCase();
}
