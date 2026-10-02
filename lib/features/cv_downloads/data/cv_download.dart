import 'package:flutter/foundation.dart';

import '../../../core/models/translated.dart';
import '../../profile/data/profile.dart';

/// Appareil du visiteur, d'après son navigateur.
enum CvDownloadDevice {
  desktop('desktop', 'Ordinateur'),
  mobile('mobile', 'Mobile'),
  tablet('tablet', 'Tablette');

  const CvDownloadDevice(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static CvDownloadDevice? fromWire(String? value) {
    for (final device in values) {
      if (device.wireValue == value) return device;
    }
    return null;
  }
}

/// Un téléchargement du CV depuis le site (`GET /v1/cv-downloads`). Pays et
/// ville viennent de la base GeoLite2 et peuvent manquer.
@immutable
class CvDownload {
  const CvDownload({
    required this.id,
    required this.jobProfileId,
    required this.jobProfileLabel,
    required this.locale,
    required this.source,
    required this.email,
    required this.countryCode,
    required this.country,
    required this.city,
    required this.referrerHost,
    required this.utmSource,
    required this.utmMedium,
    required this.utmCampaign,
    required this.origin,
    required this.device,
    required this.createdAt,
  });

  factory CvDownload.fromJson(Map<String, dynamic> json) => CvDownload(
    id: json['id'] as int,
    jobProfileId: json['job_profile_id'] as int?,
    // `null` si le profil métier a été supprimé.
    jobProfileLabel: json['job_profile_label'] == null ? null : Translated.fromJson(json['job_profile_label']),
    locale: json['locale'] as String? ?? 'fr',
    source: CvSource.fromWire(json['source'] as String?),
    email: json['email'] as String?,
    countryCode: json['country_code'] as String?,
    country: json['country'] as String?,
    city: json['city'] as String?,
    referrerHost: json['referrer_host'] as String?,
    utmSource: json['utm_source'] as String?,
    utmMedium: json['utm_medium'] as String?,
    utmCampaign: json['utm_campaign'] as String?,
    origin: json['origin'] as String? ?? 'direct',
    device: CvDownloadDevice.fromWire(json['device'] as String?),
    createdAt: json['created_at'] == null ? null : DateTime.tryParse(json['created_at'] as String),
  );

  final int id;
  final int? jobProfileId;
  final Translated? jobProfileLabel;

  /// `fr` ou `en`.
  final String locale;
  final CvSource source;

  /// Laissé (facultativement) par le visiteur.
  final String? email;
  final String? countryCode;
  final String? country;
  final String? city;

  /// Site d'arrivée du visiteur (`linkedin.com`…), `null` pour un accès direct.
  final String? referrerHost;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;

  /// Provenance résumée : la campagne, sinon le site d'origine, sinon `direct`.
  final String origin;
  final CvDownloadDevice? device;
  final DateTime? createdAt;

  /// « Abidjan, Côte d'Ivoire », ou ce qui est connu des deux.
  String? get place {
    final parts = [city, country].whereType<String>().where((p) => p.trim().isNotEmpty);
    return parts.isEmpty ? null : parts.join(', ');
  }
}
