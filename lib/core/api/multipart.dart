import 'package:dio/dio.dart';

import '../models/translated.dart';

/// Construit un corps `multipart/form-data` au format attendu par Laravel.
///
/// - [method] ajoute `_method` (`PUT` pour projets et pistes, `PATCH` pour le profil) :
///   la requête part en `POST`, seul verbe dont PHP lit les fichiers ;
/// - objets et [Translated] → `title[fr]`, `title[en]` ;
/// - listes de valeurs → `domains[]` ; listes d'objets → `highlights[0][text][fr]` ;
/// - booléens → `1` / `0` ; `null` → chaîne vide (convertie en `null` par Laravel) ;
/// - une liste vide n'envoie rien : côté API, une relation absente est vidée.
FormData buildFormData(Map<String, Object?> fields, {String? method}) {
  final form = FormData();
  if (method != null) {
    form.fields.add(MapEntry('_method', method));
  }

  void add(String key, Object? value) {
    switch (value) {
      case null:
        form.fields.add(MapEntry(key, ''));
      case MultipartFile file:
        form.files.add(MapEntry(key, file));
      case bool flag:
        form.fields.add(MapEntry(key, flag ? '1' : '0'));
      case Translated text:
        add(key, text.toJson());
      case Map<dynamic, dynamic> map:
        map.forEach((k, v) => add('$key[$k]', v));
      case List<dynamic> list:
        for (final (index, item) in list.indexed) {
          add(item is Map || item is Translated ? '$key[$index]' : '$key[]', item);
        }
      default:
        form.fields.add(MapEntry(key, value.toString()));
    }
  }

  fields.forEach(add);
  return form;
}
