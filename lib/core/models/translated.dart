import 'package:flutter/foundation.dart';

/// Texte bilingue `{ "fr": "...", "en": "..." }`.
///
/// Une langue peut manquer dans la réponse, et un objet vide arrive en `[]`
/// (tableau PHP vide) : les deux cas donnent des chaînes vides.
/// À l'envoi, toujours transmettre les deux langues ensemble.
@immutable
class Translated {
  const Translated({this.fr = '', this.en = ''});

  factory Translated.fromJson(Object? json) {
    if (json is Map) {
      return Translated(fr: json['fr']?.toString() ?? '', en: json['en']?.toString() ?? '');
    }
    return const Translated();
  }

  static const locales = ['fr', 'en'];

  final String fr;
  final String en;

  String operator [](String locale) => locale == 'en' ? en : fr;

  /// Texte à afficher dans l'app (en français) : le français, sinon l'anglais.
  String get display => fr.trim().isNotEmpty ? fr : en;

  bool get isEmpty => fr.trim().isEmpty && en.trim().isEmpty;

  bool get isComplete => fr.trim().isNotEmpty && en.trim().isNotEmpty;

  Translated copyWith({String? fr, String? en}) => Translated(fr: fr ?? this.fr, en: en ?? this.en);

  Translated withLocale(String locale, String value) => locale == 'en' ? copyWith(en: value) : copyWith(fr: value);

  Map<String, String> toJson() => {'fr': fr, 'en': en};

  @override
  bool operator ==(Object other) => other is Translated && other.fr == fr && other.en == en;

  @override
  int get hashCode => Object.hash(fr, en);

  @override
  String toString() => 'Translated(fr: $fr, en: $en)';
}
