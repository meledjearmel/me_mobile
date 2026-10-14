import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Tableau de bord (`GET /dashboard`, §4.1). Le contrat exact des tableaux
/// imbriqués (`daily`, `top_pages`, `distribution.*`, `recent.*`) vient du
/// cahier des charges : la spec générée (Scramble) les réduit à tort en
/// `array of string`, elle ne sait pas inférer un tableau hétérogène.
@immutable
class Dashboard {
  const Dashboard({
    required this.todo,
    required this.visits,
    required this.content,
    required this.distribution,
    required this.health,
    required this.recent,
    this.cvDownloads = const DashboardCvDownloads(),
    this.conversions = const DashboardConversions(),
    this.blog = const DashboardBlog(),
    this.estimator = const DashboardEstimator(),
    this.outcomes = const DashboardOutcomes(),
    this.appointments = const DashboardAppointments(),
    this.billing = const DashboardBilling(),
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
    todo: DashboardTodo.fromJson(json['todo'] as Map<String, dynamic>),
    visits: DashboardVisits.fromJson(json['visits'] as Map<String, dynamic>),
    content: DashboardContent.fromJson(json['content'] as Map<String, dynamic>),
    distribution: DashboardDistribution.fromJson(json['distribution'] as Map<String, dynamic>),
    health: [for (final item in json['health'] as List<dynamic>) HealthItem.fromJson(item as Map<String, dynamic>)],
    recent: DashboardRecent.fromJson(json['recent'] as Map<String, dynamic>),
    cvDownloads: json['cv_downloads'] is Map<String, dynamic>
        ? DashboardCvDownloads.fromJson(json['cv_downloads'] as Map<String, dynamic>)
        : const DashboardCvDownloads(),
    conversions: json['conversions'] is Map<String, dynamic>
        ? DashboardConversions.fromJson(json['conversions'] as Map<String, dynamic>)
        : const DashboardConversions(),
    blog: json['blog'] is Map<String, dynamic>
        ? DashboardBlog.fromJson(json['blog'] as Map<String, dynamic>)
        : const DashboardBlog(),
    estimator: json['estimator'] is Map<String, dynamic>
        ? DashboardEstimator.fromJson(json['estimator'] as Map<String, dynamic>)
        : const DashboardEstimator(),
    outcomes: json['outcomes'] is Map<String, dynamic>
        ? DashboardOutcomes.fromJson(json['outcomes'] as Map<String, dynamic>)
        : const DashboardOutcomes(),
    appointments: json['appointments'] is Map<String, dynamic>
        ? DashboardAppointments.fromJson(json['appointments'] as Map<String, dynamic>)
        : const DashboardAppointments(),
    billing: json['billing'] is Map<String, dynamic>
        ? DashboardBilling.fromJson(json['billing'] as Map<String, dynamic>)
        : const DashboardBilling(),
  );

  final DashboardTodo todo;
  final DashboardVisits visits;
  final DashboardContent content;
  final DashboardDistribution distribution;
  final List<HealthItem> health;
  final DashboardRecent recent;
  final DashboardCvDownloads cvDownloads;
  final DashboardConversions conversions;
  final DashboardBlog blog;
  final DashboardEstimator estimator;
  final DashboardOutcomes outcomes;
  final DashboardAppointments appointments;
  final DashboardBilling billing;
}

/// Engagement des lecteurs du blog. Lectures, réactions et commentaires au
/// total ne dépendent pas de la période ; le reste la suit.
@immutable
class DashboardBlog {
  const DashboardBlog({
    this.periodDays = 30,
    this.since,
    this.viewsTotal = 0,
    this.reactionsTotal = 0,
    this.reactionsPeriod = 0,
    this.reactionsByType = const [],
    this.sharesTotal = 0,
    this.sharesPeriod = 0,
    this.sharesByNetwork = const [],
    this.commentsTotal = 0,
    this.commentsPeriod = 0,
    this.commentsPending = 0,
    this.commentsApproved = 0,
    this.commentsRejected = 0,
    this.topPosts = const [],
  });

  factory DashboardBlog.fromJson(Map<String, dynamic> json) {
    final reactions = json['reactions'] as Map<String, dynamic>? ?? const {};
    final comments = json['comments'] as Map<String, dynamic>? ?? const {};
    final shares = json['shares'] as Map<String, dynamic>? ?? const {};
    return DashboardBlog(
      periodDays: json['period_days'] as int?,
      since: _parseDate(json['since']),
      viewsTotal: json['views_total'] as int? ?? 0,
      reactionsTotal: reactions['total'] as int? ?? 0,
      reactionsPeriod: reactions['period'] as int? ?? 0,
      reactionsByType: [
        for (final item in reactions['by_type'] as List<dynamic>? ?? const [])
          CategoryCount.fromJson(item as Map<String, dynamic>),
      ],
      sharesTotal: shares['total'] as int? ?? 0,
      sharesPeriod: shares['period'] as int? ?? 0,
      sharesByNetwork: [
        for (final item in shares['by_network'] as List<dynamic>? ?? const [])
          CategoryCount.fromJson(item as Map<String, dynamic>),
      ],
      commentsTotal: comments['total'] as int? ?? 0,
      commentsPeriod: comments['period'] as int? ?? 0,
      commentsPending: comments['pending'] as int? ?? 0,
      commentsApproved: comments['approved'] as int? ?? 0,
      commentsRejected: comments['rejected'] as int? ?? 0,
      topPosts: [
        for (final item in json['top_posts'] as List<dynamic>? ?? const [])
          BlogTopPost.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  final int? periodDays;
  final DateTime? since;

  /// Lectures de tous les articles, depuis le début.
  final int viewsTotal;
  final int reactionsTotal;
  final int reactionsPeriod;

  /// Sur la période : `label` vaut `like`, `love`, `fire`, `idea` ou `think`.
  final List<CategoryCount> reactionsByType;
  final int sharesTotal;
  final int sharesPeriod;

  /// Sur la période : `label` vaut `linkedin`, `x`, `whatsapp`, `facebook`,
  /// `email`, `copy` ou `native`.
  final List<CategoryCount> sharesByNetwork;
  final int commentsTotal;
  final int commentsPeriod;
  final int commentsPending;
  final int commentsApproved;
  final int commentsRejected;

  /// Les 5 articles les plus engagés sur la période.
  final List<BlogTopPost> topPosts;

  String get periodLabel => describePeriod(periodDays, since);
}

/// Article parmi les plus engagés (un partage pèse comme deux réactions, un
/// commentaire comme trois).
@immutable
class BlogTopPost {
  const BlogTopPost({
    required this.id,
    required this.title,
    required this.url,
    required this.views,
    required this.reactions,
    this.shares = 0,
    required this.comments,
  });

  factory BlogTopPost.fromJson(Map<String, dynamic> json) => BlogTopPost(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    url: json['url'] as String? ?? '',
    views: json['views'] as int? ?? 0,
    reactions: json['reactions'] as int? ?? 0,
    shares: json['shares'] as int? ?? 0,
    comments: json['comments'] as int? ?? 0,
  );

  final int id;
  final String title;
  final String url;

  /// Lectures depuis le début.
  final int views;

  /// Réactions et commentaires sur la période.
  final int reactions;
  final int shares;
  final int comments;
}

/// Objectifs atteints sur la période, rapportés aux visiteurs uniques.
@immutable
class DashboardConversions {
  const DashboardConversions({this.periodDays = 30, this.since, this.visitors = 0, this.goals = const []});

  factory DashboardConversions.fromJson(Map<String, dynamic> json) => DashboardConversions(
    periodDays: json['period_days'] as int?,
    since: _parseDate(json['since']),
    visitors: json['visitors'] as int? ?? 0,
    goals: [
      for (final item in json['goals'] as List<dynamic>? ?? const [])
        ConversionGoal.fromJson(item as Map<String, dynamic>),
    ],
  );

  /// `null` pour la période « tout ».
  final int? periodDays;

  /// Début de la période (première donnée pour « tout »).
  final DateTime? since;

  String get periodLabel => describePeriod(periodDays, since);
  final int visitors;
  final List<ConversionGoal> goals;
}

/// Montants des estimations d'une devise, sur la période.
@immutable
class EstimatorCurrencyTotal {
  const EstimatorCurrencyTotal({
    required this.currency,
    required this.count,
    required this.priceMin,
    required this.priceMax,
    required this.averageMin,
    required this.averageMax,
  });

  factory EstimatorCurrencyTotal.fromJson(Map<String, dynamic> json) => EstimatorCurrencyTotal(
    currency: json['currency'] as String? ?? '',
    count: json['count'] as int? ?? 0,
    priceMin: json['price_min'] as int? ?? 0,
    priceMax: json['price_max'] as int? ?? 0,
    averageMin: json['average_min'] as int? ?? 0,
    averageMax: json['average_max'] as int? ?? 0,
  );

  final String currency;
  final int count;

  /// Somme des fourchettes affichées aux visiteurs.
  final int priceMin;
  final int priceMax;

  /// Fourchette moyenne d'une estimation.
  final int averageMin;
  final int averageMax;
}

/// Estimateur de projet sur la période (bloc `estimator`). La spec générée
/// réduit ses listes à des chaînes : le contrat suit `DashboardReport::estimator`.
@immutable
class DashboardEstimator {
  const DashboardEstimator({
    this.periodDays = 30,
    this.since,
    this.pageVisitors = 0,
    this.requests = 0,
    this.conversionRate = 0,
    this.byCurrency = const [],
    this.fixed = 0,
    this.hourly = 0,
    this.projectTypes = const [],
    this.features = const [],
    this.rateGrids = const [],
    this.aiAnalysed = 0,
    this.aiHoursGapPercent,
  });

  factory DashboardEstimator.fromJson(Map<String, dynamic> json) {
    List<CategoryCount> counts(String key) => [
      for (final item in json[key] as List<dynamic>? ?? const []) CategoryCount.fromJson(item as Map<String, dynamic>),
    ];
    final billing = json['billing'] as Map<String, dynamic>? ?? const {};
    final aiGap = json['ai_gap'] as Map<String, dynamic>? ?? const {};
    return DashboardEstimator(
      periodDays: json['period_days'] as int?,
      since: _parseDate(json['since']),
      pageVisitors: json['page_visitors'] as int? ?? 0,
      requests: json['requests'] as int? ?? 0,
      conversionRate: (json['conversion_rate'] as num?)?.toDouble() ?? 0,
      byCurrency: [
        for (final item in json['by_currency'] as List<dynamic>? ?? const [])
          EstimatorCurrencyTotal.fromJson(item as Map<String, dynamic>),
      ],
      fixed: billing['fixed'] as int? ?? 0,
      hourly: billing['hourly'] as int? ?? 0,
      projectTypes: counts('project_types'),
      features: counts('features'),
      rateGrids: counts('rate_grids'),
      aiAnalysed: aiGap['analysed'] as int? ?? 0,
      aiHoursGapPercent: (aiGap['hours_gap_percent'] as num?)?.toDouble(),
    );
  }

  /// `null` pour la période « tout ».
  final int? periodDays;
  final DateTime? since;

  String get periodLabel => describePeriod(periodDays, since);

  /// Visiteurs uniques de la page de l'estimateur.
  final int pageVisitors;

  /// Demandes envoyées avec une estimation.
  final int requests;

  /// Demandes rapportées aux visiteurs de la page, en %.
  final double conversionRate;
  final List<EstimatorCurrencyTotal> byCurrency;

  /// Estimations au forfait et à l'heure.
  final int fixed;
  final int hourly;

  /// Six plus fréquents de chaque, du plus au moins demandé.
  final List<CategoryCount> projectTypes;
  final List<CategoryCount> features;
  final List<CategoryCount> rateGrids;

  /// Demandes analysées par l'IA.
  final int aiAnalysed;

  /// Écart moyen entre les heures de l'IA et celles affichées, en % ;
  /// positif : l'IA estime plus d'heures. `null` sans analyse.
  final double? aiHoursGapPercent;

  bool get isEmpty => pageVisitors == 0 && requests == 0;
}

/// Demandes signées dans une devise, sur la période.
typedef OutcomeCurrencyTotal = ({String currency, int count, int amount, int average});

/// Issue des demandes décidées sur la période (bloc `outcomes`).
@immutable
class DashboardOutcomes {
  const DashboardOutcomes({
    this.periodDays = 30,
    this.won = 0,
    this.lost = 0,
    this.winRate,
    this.byCurrency = const [],
    this.compared = 0,
    this.estimateGapPercent,
  });

  factory DashboardOutcomes.fromJson(Map<String, dynamic> json) {
    final gap = json['estimate_gap'] as Map<String, dynamic>? ?? const {};
    return DashboardOutcomes(
      periodDays: json['period_days'] as int?,
      won: json['won'] as int? ?? 0,
      lost: json['lost'] as int? ?? 0,
      winRate: (json['win_rate'] as num?)?.toDouble(),
      byCurrency: [
        for (final item in (json['by_currency'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          (
            currency: item['currency'] as String? ?? '',
            count: item['count'] as int? ?? 0,
            amount: item['amount'] as int? ?? 0,
            average: item['average'] as int? ?? 0,
          ),
      ],
      compared: gap['compared'] as int? ?? 0,
      estimateGapPercent: (gap['gap_percent'] as num?)?.toDouble(),
    );
  }

  final int? periodDays;
  final int won;
  final int lost;

  /// Part des demandes gagnées parmi celles décidées, en % ; `null` sans décision.
  final double? winRate;

  /// Montants signés par devise, du plus gros au plus petit.
  final List<OutcomeCurrencyTotal> byCurrency;

  /// Demandes signées comparées à leur estimation (même devise).
  final int compared;

  /// Écart moyen entre le montant signé et le milieu de l'estimation, en % ;
  /// positif : signé au-dessus de l'estimation.
  final double? estimateGapPercent;

  bool get isEmpty => won == 0 && lost == 0;
}

/// Demandes de rendez-vous reçues sur la période (bloc `appointments`).
@immutable
class DashboardAppointments {
  const DashboardAppointments({
    this.periodDays = 30,
    this.total = 0,
    this.pending = 0,
    this.confirmed = 0,
    this.declined = 0,
    this.cancelled = 0,
    this.confirmationRate,
    this.responseHours,
    this.byType = const [],
    this.byLocation = const [],
  });

  factory DashboardAppointments.fromJson(Map<String, dynamic> json) {
    final status = json['by_status'] as Map<String, dynamic>? ?? const {};
    List<CategoryCount> counts(String key) => [
      for (final item in json[key] as List<dynamic>? ?? const []) CategoryCount.fromJson(item as Map<String, dynamic>),
    ];
    return DashboardAppointments(
      periodDays: json['period_days'] as int?,
      total: json['total'] as int? ?? 0,
      pending: status['pending'] as int? ?? 0,
      confirmed: status['confirmed'] as int? ?? 0,
      declined: status['declined'] as int? ?? 0,
      cancelled: status['cancelled'] as int? ?? 0,
      confirmationRate: (json['confirmation_rate'] as num?)?.toDouble(),
      responseHours: (json['response_hours'] as num?)?.toDouble(),
      byType: counts('by_type'),
      byLocation: counts('by_location'),
    );
  }

  final int? periodDays;
  final int total;
  final int pending;
  final int confirmed;
  final int declined;
  final int cancelled;

  /// Confirmés parmi les demandes tranchées (confirmées ou refusées), en %.
  final double? confirmationRate;

  /// Délai moyen entre la demande et la confirmation, en heures.
  final double? responseHours;

  /// Libellé du type (français) ; lieu en valeur brute (`video`, `phone`…).
  final List<CategoryCount> byType;
  final List<CategoryCount> byLocation;

  bool get isEmpty => total == 0;
}

/// Facturation d'une devise : facturé et encaissé sur la période, reste dû et retards.
typedef BillingCurrencyTotal = ({String currency, int invoiced, int collected, int outstanding, int overdue});

/// Facture échue et non payée.
typedef OverdueInvoice = ({
  int id,
  String? number,
  String client,
  int total,
  String currency,
  DateTime? dueAt,
  int daysLate,
});

/// Devis et factures (bloc `billing`).
@immutable
class DashboardBilling {
  const DashboardBilling({
    this.periodDays = 30,
    this.byCurrency = const [],
    this.quotesIssued = 0,
    this.quotesAccepted = 0,
    this.quotesDeclined = 0,
    this.acceptanceRate,
    this.overdueInvoices = const [],
  });

  factory DashboardBilling.fromJson(Map<String, dynamic> json) {
    final quotes = json['quotes'] as Map<String, dynamic>? ?? const {};
    return DashboardBilling(
      periodDays: json['period_days'] as int?,
      byCurrency: [
        for (final item in (json['by_currency'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          (
            currency: item['currency'] as String? ?? '',
            invoiced: item['invoiced'] as int? ?? 0,
            collected: item['collected'] as int? ?? 0,
            outstanding: item['outstanding'] as int? ?? 0,
            overdue: item['overdue'] as int? ?? 0,
          ),
      ],
      quotesIssued: quotes['issued'] as int? ?? 0,
      quotesAccepted: quotes['accepted'] as int? ?? 0,
      quotesDeclined: quotes['declined'] as int? ?? 0,
      acceptanceRate: (quotes['acceptance_rate'] as num?)?.toDouble(),
      overdueInvoices: [
        for (final item in (json['overdue_invoices'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          (
            id: item['id'] as int,
            number: item['number'] as String?,
            client: item['client'] as String? ?? '',
            total: item['total'] as int? ?? 0,
            currency: item['currency'] as String? ?? '',
            dueAt: _parseDate(item['due_at']),
            daysLate: item['days_late'] as int? ?? 0,
          ),
      ],
    );
  }

  final int? periodDays;
  final List<BillingCurrencyTotal> byCurrency;
  final int quotesIssued;
  final int quotesAccepted;
  final int quotesDeclined;

  /// Devis acceptés parmi ceux tranchés, en %.
  final double? acceptanceRate;

  /// Les 5 factures en retard les plus anciennes.
  final List<OverdueInvoice> overdueInvoices;

  bool get isEmpty => byCurrency.isEmpty && quotesIssued == 0;
}

/// `cv_downloads`, `contacts`, `engagements` ou `appointments`.
@immutable
class ConversionGoal {
  const ConversionGoal({required this.key, required this.count, required this.rate});

  factory ConversionGoal.fromJson(Map<String, dynamic> json) => ConversionGoal(
    key: json['key'] as String,
    count: json['count'] as int? ?? 0,
    rate: (json['rate'] as num?)?.toDouble() ?? 0,
  );

  final String key;
  final int count;

  /// Pourcentage des visiteurs uniques, à une décimale.
  final double rate;

  String get label => switch (key) {
    'cv_downloads' => 'CV téléchargés',
    'contacts' => 'Messages',
    'engagements' => 'Demandes de collaboration',
    'appointments' => 'Rendez-vous',
    _ => key,
  };
}

/// Téléchargements du CV : total, sur la période, avec email laissé, et
/// répartitions (libellés déjà prêts côté API).
@immutable
class DashboardCvDownloads {
  const DashboardCvDownloads({
    this.total = 0,
    this.periodDays = 30,
    this.since,
    this.period = 0,
    this.withEmail = 0,
    this.byCountry = const [],
    this.byOrigin = const [],
  });

  factory DashboardCvDownloads.fromJson(Map<String, dynamic> json) => DashboardCvDownloads(
    total: json['total'] as int? ?? 0,
    periodDays: json['period_days'] as int?,
    since: _parseDate(json['since']),
    period: json['period'] as int? ?? 0,
    withEmail: json['with_email'] as int? ?? 0,
    byCountry: [
      for (final item in json['by_country'] as List<dynamic>? ?? const [])
        CategoryCount.fromJson(item as Map<String, dynamic>),
    ],
    byOrigin: [
      for (final item in json['by_origin'] as List<dynamic>? ?? const [])
        CategoryCount.fromJson(item as Map<String, dynamic>),
    ],
  );

  final int total;

  /// `null` pour la période « tout ».
  final int? periodDays;

  /// Début de la période (première donnée pour « tout »).
  final DateTime? since;

  String get periodLabel => describePeriod(periodDays, since);
  final int period;
  final int withEmail;
  final List<CategoryCount> byCountry;
  final List<CategoryCount> byOrigin;
}

@immutable
class DashboardTodo {
  const DashboardTodo({
    required this.contacts,
    required this.engagements,
    required this.testimonials,
    this.appointments = 0,
    this.comments = 0,
    this.projectDrafts = 0,
    this.postDrafts = 0,
    this.contentDrafts = 0,
    this.revisions = 0,
  });

  factory DashboardTodo.fromJson(Map<String, dynamic> json) => DashboardTodo(
    contacts: json['contacts'] as int? ?? 0,
    engagements: json['engagements'] as int? ?? 0,
    testimonials: json['testimonials'] as int? ?? 0,
    appointments: json['appointments'] as int? ?? 0,
    comments: json['comments'] as int? ?? 0,
    projectDrafts: json['project_drafts'] as int? ?? 0,
    postDrafts: json['post_drafts'] as int? ?? 0,
    contentDrafts: json['content_drafts'] as int? ?? 0,
    revisions: json['revisions'] as int? ?? 0,
  );

  final int contacts;
  final int engagements;
  final int testimonials;

  /// Demandes de rendez-vous en attente.
  final int appointments;

  /// Commentaires du blog à modérer.
  final int comments;

  /// Brouillons à relire, souvent proposés par l'IA : projets, articles, et
  /// expériences, formations, certifications, page « Uses », compétences.
  final int projectDrafts;
  final int postDrafts;
  final int contentDrafts;

  /// Révisions de contenus en ligne proposées par l'IA, en attente.
  final int revisions;

  int get drafts => projectDrafts + postDrafts + contentDrafts;

  /// Éléments de la boîte de réception (les brouillons et révisions ont leurs cartes).
  int get total => contacts + engagements + testimonials + appointments + comments;
}

@immutable
class DailyVisit {
  const DailyVisit({required this.date, required this.count});

  factory DailyVisit.fromJson(Map<String, dynamic> json) =>
      DailyVisit(date: DateTime.parse(json['date'] as String), count: json['count'] as int);

  final DateTime date;
  final int count;
}

@immutable
class TopPage {
  const TopPage({required this.path, required this.count});

  factory TopPage.fromJson(Map<String, dynamic> json) =>
      TopPage(path: json['path'] as String, count: json['count'] as int);

  final String path;
  final int count;
}

@immutable
class DashboardVisits {
  const DashboardVisits({
    required this.total,
    required this.periodDays,
    this.since,
    this.granularity = 'day',
    required this.period,
    required this.today,
    required this.french,
    required this.english,
    required this.daily,
    required this.topPages,
    this.visitors = 0,
    this.bySource = const [],
    this.byDevice = const [],
    this.topContent = const [],
  });

  factory DashboardVisits.fromJson(Map<String, dynamic> json) => DashboardVisits(
    total: json['total'] as int? ?? 0,
    periodDays: json['period_days'] as int?,
    since: _parseDate(json['since']),
    period: json['period'] as int? ?? 0,
    today: json['today'] as int? ?? 0,
    french: json['french'] as int? ?? 0,
    english: json['english'] as int? ?? 0,
    daily: [for (final item in json['daily'] as List<dynamic>) DailyVisit.fromJson(item as Map<String, dynamic>)],
    topPages: [for (final item in json['top_pages'] as List<dynamic>) TopPage.fromJson(item as Map<String, dynamic>)],
    visitors: json['visitors'] as int? ?? 0,
    granularity: json['granularity'] as String? ?? 'day',
    bySource: [
      for (final item in json['by_source'] as List<dynamic>? ?? const [])
        CategoryCount.fromJson(item as Map<String, dynamic>),
    ],
    byDevice: [
      for (final item in json['by_device'] as List<dynamic>? ?? const [])
        CategoryCount.fromJson(item as Map<String, dynamic>),
    ],
    topContent: [
      for (final item in json['top_content'] as List<dynamic>? ?? const [])
        TopContent.fromJson(item as Map<String, dynamic>),
    ],
  );

  final int total;

  /// `null` pour la période « tout ».
  final int? periodDays;

  /// Début de la période (première donnée pour « tout »).
  final DateTime? since;

  String get periodLabel => describePeriod(periodDays, since);
  final int period;
  final int today;
  final int french;
  final int english;
  final List<DailyVisit> daily;
  final List<TopPage> topPages;

  /// Visiteurs uniques sur la période (empreinte anonyme du jour, sans cookie).
  final int visitors;

  /// Pas de la courbe [daily] : `day`, `month` ou `year`.
  final String granularity;

  /// Visiteurs uniques par provenance : campagne, site d'origine ou `direct`.
  final List<CategoryCount> bySource;

  /// Visiteurs uniques par appareil : `desktop`, `mobile`, `tablet`.
  final List<CategoryCount> byDevice;

  /// Articles et projets les plus vus (8 au plus), toutes langues réunies.
  final List<TopContent> topContent;
}

/// Article ou projet parmi les plus vus de la période.
@immutable
class TopContent {
  const TopContent({
    required this.type,
    required this.title,
    required this.url,
    required this.visits,
    required this.visitors,
    required this.topSource,
  });

  factory TopContent.fromJson(Map<String, dynamic> json) => TopContent(
    type: json['type'] as String? ?? 'post',
    title: json['title'] as String? ?? '',
    url: json['url'] as String? ?? '',
    visits: json['visits'] as int? ?? 0,
    visitors: json['visitors'] as int? ?? 0,
    topSource: json['top_source'] as String? ?? 'direct',
  );

  /// `post` ou `project`.
  final String type;
  final String title;

  /// Chemin sur le site (`/fr/blog/…`).
  final String url;
  final int visits;
  final int visitors;

  /// Principale provenance : campagne, site d'origine ou `direct`.
  final String topSource;

  bool get isPost => type == 'post';
}

@immutable
class ProjectsStats {
  const ProjectsStats({
    this.draft = 0,
    required this.published,
    required this.archived,
    required this.featured,
    required this.openSource,
  });

  factory ProjectsStats.fromJson(Map<String, dynamic> json) => ProjectsStats(
    draft: json['draft'] as int? ?? 0,
    published: json['published'] as int? ?? 0,
    archived: json['archived'] as int? ?? 0,
    featured: json['featured'] as int? ?? 0,
    openSource: json['open_source'] as int? ?? 0,
  );

  final int draft;
  final int published;
  final int archived;
  final int featured;
  final int openSource;
}

@immutable
class TestimonialsStats {
  const TestimonialsStats({
    required this.approved,
    required this.pending,
    required this.rejected,
    required this.featured,
  });

  factory TestimonialsStats.fromJson(Map<String, dynamic> json) => TestimonialsStats(
    approved: json['approved'] as int? ?? 0,
    pending: json['pending'] as int? ?? 0,
    rejected: json['rejected'] as int? ?? 0,
    featured: json['featured'] as int? ?? 0,
  );

  final int approved;
  final int pending;
  final int rejected;
  final int featured;
}

@immutable
class EngagementsStats {
  const EngagementsStats({required this.freelance, required this.hiring, required this.cvSent});

  factory EngagementsStats.fromJson(Map<String, dynamic> json) => EngagementsStats(
    freelance: json['freelance'] as int? ?? 0,
    hiring: json['hiring'] as int? ?? 0,
    cvSent: json['cv_sent'] as int? ?? 0,
  );

  final int freelance;
  final int hiring;
  final int cvSent;
}

@immutable
class DashboardContent {
  const DashboardContent({
    required this.projects,
    required this.skills,
    required this.technologies,
    required this.domains,
    required this.experiences,
    required this.educations,
    required this.referencesOnCv,
    required this.yearsOfExperience,
    required this.testimonials,
    required this.contacts,
    required this.engagements,
    required this.congratulations,
  });

  factory DashboardContent.fromJson(Map<String, dynamic> json) => DashboardContent(
    projects: ProjectsStats.fromJson(json['projects'] as Map<String, dynamic>),
    skills: json['skills'] as int? ?? 0,
    technologies: json['technologies'] as int? ?? 0,
    domains: json['domains'] as int? ?? 0,
    experiences: json['experiences'] as int? ?? 0,
    educations: json['educations'] as int? ?? 0,
    referencesOnCv: json['references_on_cv'] as int? ?? 0,
    yearsOfExperience: json['years_of_experience'] as int? ?? 0,
    testimonials: TestimonialsStats.fromJson(json['testimonials'] as Map<String, dynamic>),
    contacts: json['contacts'] as int? ?? 0,
    engagements: EngagementsStats.fromJson(json['engagements'] as Map<String, dynamic>),
    congratulations: json['congratulations'] as int? ?? 0,
  );

  final ProjectsStats projects;
  final int skills;
  final int technologies;
  final int domains;
  final int experiences;
  final int educations;
  final int referencesOnCv;
  final int yearsOfExperience;
  final TestimonialsStats testimonials;
  final int contacts;
  final EngagementsStats engagements;
  final int congratulations;
}

@immutable
class DomainCount {
  const DomainCount({required this.label, required this.color, required this.count});

  factory DomainCount.fromJson(Map<String, dynamic> json) => DomainCount(
    label: json['label'] as String? ?? '',
    color: json['color'] as String? ?? '#999999',
    count: json['count'] as int? ?? 0,
  );

  final String label;
  final String color;
  final int count;
}

@immutable
class CategoryCount {
  const CategoryCount({required this.label, required this.count});

  /// Les catégories sont gérées côté API : le libellé (français) arrive déjà prêt.
  factory CategoryCount.fromJson(Map<String, dynamic> json) =>
      CategoryCount(label: json['label'] as String? ?? '', count: json['count'] as int? ?? 0);

  final String label;
  final int count;
}

@immutable
class DashboardDistribution {
  const DashboardDistribution({
    required this.projectsByDomain,
    required this.skillsByDomain,
    required this.technologiesByCategory,
  });

  factory DashboardDistribution.fromJson(Map<String, dynamic> json) => DashboardDistribution(
    projectsByDomain: [
      for (final item in json['projects_by_domain'] as List<dynamic>)
        DomainCount.fromJson(item as Map<String, dynamic>),
    ],
    skillsByDomain: [
      for (final item in json['skills_by_domain'] as List<dynamic>) DomainCount.fromJson(item as Map<String, dynamic>),
    ],
    technologiesByCategory: [
      for (final item in json['technologies_by_category'] as List<dynamic>)
        CategoryCount.fromJson(item as Map<String, dynamic>),
    ],
  );

  final List<DomainCount> projectsByDomain;
  final List<DomainCount> skillsByDomain;
  final List<CategoryCount> technologiesByCategory;
}

/// Une ligne « à compléter » (§4.1). Libellé et écran cible : voir
/// `health_labels.dart` (statiques, la clé seule vient du serveur).
@immutable
class HealthItem {
  const HealthItem({required this.key, required this.ok, required this.count});

  factory HealthItem.fromJson(Map<String, dynamic> json) => HealthItem(
    key: json['key'] as String,
    // `ok` arrive presque toujours en booléen ; tolère aussi une chaîne
    // (vu sur `cv_identity` dans la spec générée).
    ok: switch (json['ok']) {
      bool value => value,
      String value => value == 'true' || value == '1',
      _ => false,
    },
    count: json['count'] as int? ?? 0,
  );

  final String key;
  final bool ok;
  final int count;
}

@immutable
class RecentContact {
  const RecentContact({
    required this.id,
    required this.name,
    required this.subject,
    required this.isNew,
    required this.at,
  });

  factory RecentContact.fromJson(Map<String, dynamic> json) => RecentContact(
    id: json['id'] as int,
    name: json['name'] as String,
    subject: json['subject'] as String?,
    isNew: json['is_new'] as bool? ?? false,
    at: json['at'] == null ? null : DateTime.tryParse(json['at'] as String),
  );

  final int id;
  final String name;
  final String? subject;
  final bool isNew;
  final DateTime? at;
}

@immutable
class RecentEngagement {
  const RecentEngagement({
    required this.id,
    required this.name,
    required this.company,
    required this.type,
    required this.subject,
    required this.isNew,
    required this.at,
  });

  factory RecentEngagement.fromJson(Map<String, dynamic> json) => RecentEngagement(
    id: json['id'] as int,
    name: json['name'] as String,
    company: json['company'] as String?,
    type: json['type'] as String?,
    subject: json['subject'] as String?,
    isNew: json['is_new'] as bool? ?? false,
    at: json['at'] == null ? null : DateTime.tryParse(json['at'] as String),
  );

  final int id;
  final String name;
  final String? company;
  final String? type;
  final String? subject;
  final bool isNew;
  final DateTime? at;
}

@immutable
class RecentTestimonial {
  const RecentTestimonial({required this.id, required this.name, required this.excerpt, required this.at});

  factory RecentTestimonial.fromJson(Map<String, dynamic> json) => RecentTestimonial(
    id: json['id'] as int,
    name: json['name'] as String,
    excerpt: json['excerpt'] as String? ?? '',
    at: json['at'] == null ? null : DateTime.tryParse(json['at'] as String),
  );

  final int id;
  final String name;
  final String excerpt;
  final DateTime? at;
}

@immutable
class DashboardRecent {
  const DashboardRecent({required this.contacts, required this.engagements, required this.testimonials});

  factory DashboardRecent.fromJson(Map<String, dynamic> json) => DashboardRecent(
    contacts: [
      for (final item in json['contacts'] as List<dynamic>) RecentContact.fromJson(item as Map<String, dynamic>),
    ],
    engagements: [
      for (final item in json['engagements'] as List<dynamic>) RecentEngagement.fromJson(item as Map<String, dynamic>),
    ],
    testimonials: [
      for (final item in json['testimonials'] as List<dynamic>)
        RecentTestimonial.fromJson(item as Map<String, dynamic>),
    ],
  );

  final List<RecentContact> contacts;
  final List<RecentEngagement> engagements;
  final List<RecentTestimonial> testimonials;
}

DateTime? _parseDate(Object? value) => value is String ? DateTime.tryParse(value) : null;

/// Périodes proposées (paramètre `days` de l'API).
const dashboardPeriods = [
  (days: '7', label: '7 j'),
  (days: '30', label: '30 j'),
  (days: '90', label: '90 j'),
  (days: '365', label: '12 mois'),
  (days: 'all', label: 'Tout'),
];

/// « 30 derniers jours », « 12 derniers mois », « Depuis le 12 mars 2025 ».
String describePeriod(int? days, DateTime? since) => switch (days) {
  365 => '12 derniers mois',
  final int d => '$d derniers jours',
  null when since != null => 'Depuis le ${DateFormat('d MMMM y', 'fr_FR').format(since)}',
  null => 'Depuis le début',
};
