/// Libellés français et écran cible de chaque ligne « à compléter » (§4.1).
/// Seule la clé (`key`) vient du serveur ; le reste est statique côté client.
class HealthLabel {
  const HealthLabel(this.title, this.destination);

  final String title;

  /// 'Profil' | 'Références' | 'Projets' | 'Avis'.
  final String destination;
}

const healthLabels = <String, HealthLabel>{
  'profile_photo': HealthLabel('Photo du profil (site)', 'Profil'),
  'cv_photo': HealthLabel('Photo du CV', 'Profil'),
  'cv_identity': HealthLabel('Nom et prénoms du CV', 'Profil'),
  'cv_references': HealthLabel('Références à joindre au CV', 'Références'),
  'project_covers': HealthLabel('Images de couverture des projets', 'Projets'),
  'featured_testimonials': HealthLabel('Avis à la une choisis', 'Avis'),
};
