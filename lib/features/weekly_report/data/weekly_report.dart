import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/utils/date_only.dart';
import '../../dashboard/data/dashboard.dart';

/// Demande passée par l'estimateur cette semaine, avec l'avis de l'IA.
typedef ReportEstimate = ({int id, String? subject, String? estimate, String? aiBilling, String? aiHours});

/// Page de candidature ouverte cette semaine.
typedef ReportApplication = ({int id, String company, String position, int views, int cvDownloads, bool firstTime});

/// Les 7 derniers jours (`report` de `GET /v1/weekly-report`).
@immutable
class WeeklyReport {
  const WeeklyReport({
    required this.from,
    required this.to,
    required this.visits,
    required this.visitors,
    required this.previousVisits,
    required this.change,
    required this.topContent,
    required this.sources,
    required this.requestsTotal,
    required this.contacts,
    required this.freelance,
    required this.hiring,
    required this.appointments,
    required this.upcomingAppointments,
    required this.estimates,
    required this.applicationsCreated,
    required this.applicationsViewed,
    required this.cvDownloads,
    required this.postsPublished,
    required this.comments,
    required this.reactions,
    required this.newSubscribers,
    required this.subscribers,
    required this.todo,
    this.highlights,
  });

  factory WeeklyReport.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>? ?? const {};
    final audience = json['audience'] as Map<String, dynamic>? ?? const {};
    final requests = json['requests'] as Map<String, dynamic>? ?? const {};
    final applications = json['applications'] as Map<String, dynamic>? ?? const {};
    final blog = json['blog'] as Map<String, dynamic>? ?? const {};
    // `todo` ne garde que les lignes non nulles ; un objet vide arrive en `[]`.
    final todo = json['todo'] is Map<String, dynamic>
        ? json['todo'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return WeeklyReport(
      from: parseDateOnly(period['from'] as String?),
      to: parseDateOnly(period['to'] as String?),
      visits: audience['visits'] as int? ?? 0,
      visitors: audience['visitors'] as int? ?? 0,
      previousVisits: audience['previous_visits'] as int? ?? 0,
      change: audience['change'] as int?,
      topContent: [
        for (final item in audience['top_content'] as List<dynamic>? ?? const [])
          TopContent.fromJson(item as Map<String, dynamic>),
      ],
      sources: [
        for (final item in audience['sources'] as List<dynamic>? ?? const [])
          CategoryCount.fromJson(item as Map<String, dynamic>),
      ],
      requestsTotal: requests['total'] as int? ?? 0,
      contacts: requests['contacts'] as int? ?? 0,
      freelance: requests['freelance'] as int? ?? 0,
      hiring: requests['hiring'] as int? ?? 0,
      appointments: requests['appointments'] as int? ?? 0,
      upcomingAppointments: requests['upcoming_appointments'] as int? ?? 0,
      estimates: [
        for (final e in (requests['estimates'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          (
            id: e['id'] as int,
            subject: e['subject'] as String?,
            estimate: e['estimate'] as String?,
            aiBilling: e['ai_billing'] as String?,
            aiHours: e['ai_hours'] as String?,
          ),
      ],
      applicationsCreated: applications['created'] as int? ?? 0,
      applicationsViewed: [
        for (final a in (applications['viewed'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          (
            id: a['id'] as int,
            company: a['company'] as String? ?? '',
            position: a['position'] as String? ?? '',
            views: a['views'] as int? ?? 0,
            cvDownloads: a['cv_downloads'] as int? ?? 0,
            firstTime: a['first_time'] as bool? ?? false,
          ),
      ],
      cvDownloads: json['cv_downloads'] as int? ?? 0,
      postsPublished: blog['published'] as int? ?? 0,
      comments: blog['comments'] as int? ?? 0,
      reactions: blog['reactions'] as int? ?? 0,
      newSubscribers: blog['new_subscribers'] as int? ?? 0,
      subscribers: blog['subscribers'] as int? ?? 0,
      todo: DashboardTodo.fromJson(todo),
      highlights: json['highlights'] is List
          ? [for (final h in json['highlights'] as List<dynamic>) h as String]
          : null,
    );
  }

  final DateTime? from;
  final DateTime? to;

  final int visits;
  final int visitors;
  final int previousVisits;

  /// Évolution des visites en % par rapport à la semaine d'avant ; `null` sans comparaison.
  final int? change;
  final List<TopContent> topContent;
  final List<CategoryCount> sources;

  final int requestsTotal;
  final int contacts;
  final int freelance;
  final int hiring;
  final int appointments;
  final int upcomingAppointments;
  final List<ReportEstimate> estimates;

  final int applicationsCreated;
  final List<ReportApplication> applicationsViewed;

  /// CV téléchargés, depuis le site et depuis les pages de candidature.
  final int cvDownloads;

  final int postsPublished;
  final int comments;
  final int reactions;
  final int newSubscribers;
  final int subscribers;

  /// Ce qui attend une action (les lignes à zéro sont omises par l'API).
  final DashboardTodo todo;

  /// Trois points à retenir rédigés par l'IA ; `null` si non demandés ou indisponibles.
  final List<String>? highlights;
}

/// Réponse de `GET /v1/weekly-report` : le rapport et ses réglages.
@immutable
class WeeklyReportState {
  const WeeklyReportState({required this.enabled, required this.report, this.sentAt});

  factory WeeklyReportState.fromJson(Map<String, dynamic> json) => WeeklyReportState(
    enabled: json['enabled'] as bool? ?? false,
    sentAt: DateTime.tryParse(json['sent_at'] as String? ?? '')?.toLocal(),
    report: WeeklyReport.fromJson(json['report'] as Map<String, dynamic>? ?? const {}),
  );

  /// Activé, il part chaque lundi matin à l'email du profil.
  final bool enabled;

  /// Dernier envoi.
  final DateTime? sentAt;
  final WeeklyReport report;
}

final weeklyReportRepositoryProvider = Provider<WeeklyReportRepository>(
  (ref) => WeeklyReportRepository(ref.watch(apiClientProvider)),
);

/// `GET|PUT /v1/weekly-report` et `POST /v1/weekly-report/send`.
class WeeklyReportRepository {
  const WeeklyReportRepository(this._api);

  final ApiClient _api;

  /// [highlights] : l'IA ajoute trois points à retenir (plus lent).
  Future<WeeklyReportState> get({bool highlights = false}) async {
    final json = await _api.get('/v1/weekly-report', query: {'highlights': highlights});
    return WeeklyReportState.fromJson(json as Map<String, dynamic>);
  }

  Future<bool> setEnabled(bool enabled) async {
    final json = await _api.put('/v1/weekly-report', data: {'enabled': enabled}) as Map<String, dynamic>;
    return json['enabled'] as bool? ?? enabled;
  }

  /// Envoie le rapport tout de suite, même désactivé. À n'appeler qu'après confirmation.
  /// Renvoie `sent`, ou `no_recipient` sans email sur le profil.
  Future<String> sendNow() async {
    final json =
        await _api.post('/v1/weekly-report/send', receiveTimeout: const Duration(seconds: 90)) as Map<String, dynamic>;
    return json['status'] as String? ?? 'sent';
  }
}
