import 'package:flutter/foundation.dart';

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
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
        todo: DashboardTodo.fromJson(json['todo'] as Map<String, dynamic>),
        visits: DashboardVisits.fromJson(json['visits'] as Map<String, dynamic>),
        content: DashboardContent.fromJson(json['content'] as Map<String, dynamic>),
        distribution: DashboardDistribution.fromJson(json['distribution'] as Map<String, dynamic>),
        health: [for (final item in json['health'] as List<dynamic>) HealthItem.fromJson(item as Map<String, dynamic>)],
        recent: DashboardRecent.fromJson(json['recent'] as Map<String, dynamic>),
      );

  final DashboardTodo todo;
  final DashboardVisits visits;
  final DashboardContent content;
  final DashboardDistribution distribution;
  final List<HealthItem> health;
  final DashboardRecent recent;
}

@immutable
class DashboardTodo {
  const DashboardTodo({required this.contacts, required this.engagements, required this.testimonials});

  factory DashboardTodo.fromJson(Map<String, dynamic> json) => DashboardTodo(
        contacts: json['contacts'] as int? ?? 0,
        engagements: json['engagements'] as int? ?? 0,
        testimonials: json['testimonials'] as int? ?? 0,
      );

  final int contacts;
  final int engagements;
  final int testimonials;

  int get total => contacts + engagements + testimonials;
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
    required this.period,
    required this.today,
    required this.french,
    required this.english,
    required this.daily,
    required this.topPages,
  });

  factory DashboardVisits.fromJson(Map<String, dynamic> json) => DashboardVisits(
        total: json['total'] as int? ?? 0,
        periodDays: json['period_days'] as int? ?? 30,
        period: json['period'] as int? ?? 0,
        today: json['today'] as int? ?? 0,
        french: json['french'] as int? ?? 0,
        english: json['english'] as int? ?? 0,
        daily: [for (final item in json['daily'] as List<dynamic>) DailyVisit.fromJson(item as Map<String, dynamic>)],
        topPages: [
          for (final item in json['top_pages'] as List<dynamic>) TopPage.fromJson(item as Map<String, dynamic>),
        ],
      );

  final int total;
  final int periodDays;
  final int period;
  final int today;
  final int french;
  final int english;
  final List<DailyVisit> daily;
  final List<TopPage> topPages;
}

@immutable
class ProjectsStats {
  const ProjectsStats({required this.published, required this.archived, required this.featured, required this.openSource});

  factory ProjectsStats.fromJson(Map<String, dynamic> json) => ProjectsStats(
        published: json['published'] as int? ?? 0,
        archived: json['archived'] as int? ?? 0,
        featured: json['featured'] as int? ?? 0,
        openSource: json['open_source'] as int? ?? 0,
      );

  final int published;
  final int archived;
  final int featured;
  final int openSource;
}

@immutable
class TestimonialsStats {
  const TestimonialsStats({required this.approved, required this.pending, required this.rejected, required this.featured});

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
          for (final item in json['projects_by_domain'] as List<dynamic>) DomainCount.fromJson(item as Map<String, dynamic>),
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
  const RecentContact({required this.id, required this.name, required this.subject, required this.isNew, required this.at});

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
          for (final item in json['testimonials'] as List<dynamic>) RecentTestimonial.fromJson(item as Map<String, dynamic>),
        ],
      );

  final List<RecentContact> contacts;
  final List<RecentEngagement> engagements;
  final List<RecentTestimonial> testimonials;
}
