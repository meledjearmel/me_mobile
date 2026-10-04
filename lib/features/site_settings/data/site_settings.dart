import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/models/translated.dart';

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

/// Ma disponibilité affichée sur le site (badge de l'en-tête, fenêtre de contact).
enum AvailabilityStatus {
  available('available', 'Disponible'),
  from('from', 'À partir du'),
  unavailable('unavailable', 'Indisponible');

  const AvailabilityStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static AvailabilityStatus fromWire(String? value) =>
      values.firstWhere((s) => s.wireValue == value, orElse: () => AvailabilityStatus.available);
}

/// Visio d'un rendez-vous confirmé : un lien Jitsi unique, ou un lien fixe.
enum BookingVideoProvider {
  jitsi('jitsi', 'Jitsi'),
  link('link', 'Lien fixe');

  const BookingVideoProvider(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static BookingVideoProvider fromWire(String? value) => value == link.wireValue ? link : jitsi;
}

/// `GET|PATCH /v1/site-settings` : réglages de gestion du site (site, avis, CV,
/// notifications, rendez-vous). Les heures des rendez-vous sont celles d'Abidjan (UTC).
@immutable
class SiteSettings {
  const SiteSettings({
    this.contactOpensDrawer = true,
    this.testimonialVideoEnabled = false,
    this.availabilityStatus = AvailabilityStatus.available,
    this.availableFrom,
    this.blogEnabled = false,
    this.blogReactionsEnabled = false,
    this.blogCommentsEnabled = false,
    this.cvJobProfileId,
    this.cvSource = CvSource.uploaded,
    this.congratulationNotifyMinutes = 10,
    this.bookingEnabled = false,
    this.bookingMinNoticeHours = 24,
    this.bookingHorizonDays = 30,
    this.bookingBufferMinutes = 0,
    this.bookingVideoProvider = BookingVideoProvider.jitsi,
    this.bookingVideoLink,
    this.nowContent = const Translated(),
    this.nowUpdatedAt,
  });

  factory SiteSettings.fromJson(Map<String, dynamic> json) => SiteSettings(
    contactOpensDrawer: json['contact_opens_drawer'] as bool? ?? true,
    testimonialVideoEnabled: json['testimonial_video_enabled'] as bool? ?? false,
    availabilityStatus: AvailabilityStatus.fromWire(json['availability_status'] as String?),
    availableFrom: json['available_from'] == null ? null : DateTime.tryParse(json['available_from'] as String),
    blogEnabled: json['blog_enabled'] as bool? ?? false,
    blogReactionsEnabled: json['blog_reactions_enabled'] as bool? ?? false,
    blogCommentsEnabled: json['blog_comments_enabled'] as bool? ?? false,
    cvJobProfileId: json['cv_job_profile_id'] as int?,
    cvSource: CvSource.fromWire(json['cv_source'] as String?),
    congratulationNotifyMinutes: json['congratulation_notify_minutes'] as int? ?? 10,
    bookingEnabled: json['booking_enabled'] as bool? ?? false,
    bookingMinNoticeHours: json['booking_min_notice_hours'] as int? ?? 24,
    bookingHorizonDays: json['booking_horizon_days'] as int? ?? 30,
    bookingBufferMinutes: json['booking_buffer_minutes'] as int? ?? 0,
    bookingVideoProvider: BookingVideoProvider.fromWire(json['booking_video_provider'] as String?),
    bookingVideoLink: json['booking_video_link'] as String?,
    nowContent: Translated.fromJson(json['now_content']),
    nowUpdatedAt: json['now_updated_at'] == null ? null : DateTime.tryParse(json['now_updated_at'] as String)?.toLocal(),
  );

  /// Le bouton « Contact » ouvre le tiroir latéral (`true`) ou mène à la page Contact.
  final bool contactOpensDrawer;

  /// Les visiteurs peuvent joindre ou filmer une vidéo avec leur avis.
  final bool testimonialVideoEnabled;

  final AvailabilityStatus availabilityStatus;

  /// Date de disponibilité (statut `from`, date à venir) ; passée, le site
  /// affiche « disponible ».
  final DateTime? availableFrom;

  /// Le blog est affiché sur le site public.
  final bool blogEnabled;

  /// Les lecteurs peuvent réagir aux articles, sans compte.
  final bool blogReactionsEnabled;

  /// Les lecteurs peuvent commenter ; un commentaire n'apparaît qu'une fois approuvé.
  final bool blogCommentsEnabled;

  /// Profil métier dont le CV est proposé (`null` : le premier publié).
  final int? cvJobProfileId;

  /// Source prioritaire du CV, pour tout le site.
  final CvSource cvSource;

  /// Au plus une notification push de félicitations par motif sur ce nombre
  /// de minutes (0 = à chaque envoi).
  final int congratulationNotifyMinutes;

  final bool bookingEnabled;

  /// Délai minimum entre la demande et le rendez-vous (0 à 720 h).
  final int bookingMinNoticeHours;

  /// Jusqu'à combien de jours à l'avance réserver (1 à 365).
  final int bookingHorizonDays;

  /// Pause entre deux rendez-vous (0 à 240 min).
  final int bookingBufferMinutes;
  final BookingVideoProvider bookingVideoProvider;

  /// Lien fixe, utilisé quand [bookingVideoProvider] vaut `link`.
  final String? bookingVideoLink;

  /// Texte de la page « Now » : une ligne vide entre deux paragraphes, « - »
  /// en début de ligne pour une liste. Vide en français, la page est masquée.
  final Translated nowContent;

  /// Dernière modification de ce texte (lecture seule).
  final DateTime? nowUpdatedAt;

  Map<String, Object?> toJson() => {
    'contact_opens_drawer': contactOpensDrawer,
    'testimonial_video_enabled': testimonialVideoEnabled,
    'availability_status': availabilityStatus.wireValue,
    // Seulement avec le statut `from` : le serveur exige alors une date à venir.
    'available_from': availabilityStatus == AvailabilityStatus.from && availableFrom != null
        ? DateFormat('yyyy-MM-dd').format(availableFrom!)
        : null,
    'blog_enabled': blogEnabled,
    'blog_reactions_enabled': blogReactionsEnabled,
    'blog_comments_enabled': blogCommentsEnabled,
    'cv_job_profile_id': cvJobProfileId,
    'cv_source': cvSource.wireValue,
    'congratulation_notify_minutes': congratulationNotifyMinutes,
    'booking_enabled': bookingEnabled,
    'booking_min_notice_hours': bookingMinNoticeHours,
    'booking_horizon_days': bookingHorizonDays,
    'booking_buffer_minutes': bookingBufferMinutes,
    'booking_video_provider': bookingVideoProvider.wireValue,
    'booking_video_link': bookingVideoLink,
    'now_content': nowContent.toJson(),
  };
}
