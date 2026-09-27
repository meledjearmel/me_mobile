/// Ton optionnel pour la réécriture d'un texte (`POST /v1/ai/improve`).
enum TextTone {
  formal('formal', 'Formel'),
  friendly('friendly', 'Amical'),
  concise('concise', 'Concis'),
  enthusiastic('enthusiastic', 'Enthousiaste');

  const TextTone(this.wireValue, this.label);

  final String wireValue;
  final String label;
}
