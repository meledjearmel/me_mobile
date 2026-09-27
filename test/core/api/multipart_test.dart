import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/multipart.dart';
import 'package:me_mobile/core/models/translated.dart';

Map<String, String> _fieldMap(FormData form) => {for (final e in form.fields) e.key: e.value};

void main() {
  group('buildFormData', () {
    test('ajoute _method quand method est fourni (PUT projets/pistes, PATCH profil)', () {
      final form = buildFormData({'name': 'Armel'}, method: 'PUT');

      expect(_fieldMap(form)['_method'], 'PUT');
    });

    test("n'ajoute pas _method quand aucun n'est fourni", () {
      final form = buildFormData({'name': 'Armel'});

      expect(_fieldMap(form).containsKey('_method'), isFalse);
    });

    test('un texte traduit devient title[fr] / title[en]', () {
      final form = buildFormData({'title': const Translated(fr: 'Bonjour', en: 'Hello')});
      final fields = _fieldMap(form);

      expect(fields['title[fr]'], 'Bonjour');
      expect(fields['title[en]'], 'Hello');
    });

    test('une liste de scalaires devient domains[]', () {
      final form = buildFormData({
        'domains': [1, 2, 3],
      });
      final entries = form.fields.where((e) => e.key == 'domains[]').map((e) => e.value).toList();

      expect(entries, ['1', '2', '3']);
    });

    test("une liste d'objets indexe chaque entrée (highlights[0][text][fr])", () {
      final form = buildFormData({
        'highlights': [
          {'text': const Translated(fr: 'Point 1', en: 'Point one')},
        ],
      });
      final fields = _fieldMap(form);

      expect(fields['highlights[0][text][fr]'], 'Point 1');
      expect(fields['highlights[0][text][en]'], 'Point one');
    });

    test('un booléen devient 1 ou 0', () {
      final form = buildFormData({'is_featured': true, 'is_open_source': false});
      final fields = _fieldMap(form);

      expect(fields['is_featured'], '1');
      expect(fields['is_open_source'], '0');
    });

    test('une valeur nulle envoie une chaîne vide (relation à vider)', () {
      final form = buildFormData({'end_date': null});

      expect(_fieldMap(form)['end_date'], '');
    });

    test('un fichier va dans form.files, pas dans form.fields', () {
      final file = MultipartFile.fromBytes([1, 2, 3], filename: 'cover.jpg');
      final form = buildFormData({'cover': file});

      expect(form.files.single.key, 'cover');
      expect(form.fields.any((e) => e.key == 'cover'), isFalse);
    });
  });
}
