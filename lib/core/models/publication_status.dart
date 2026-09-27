/// Statut de publication (§3.6), partagé par domaines, profils métier,
/// compétences, formations et expériences.
enum PublicationStatus {
  draft('draft', 'Brouillon'),
  published('published', 'Publié');

  const PublicationStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static PublicationStatus fromWire(String? value) =>
      values.firstWhere((s) => s.wireValue == value, orElse: () => PublicationStatus.draft);
}
