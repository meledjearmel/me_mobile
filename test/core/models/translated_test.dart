import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/models/translated.dart';

void main() {
  group('Translated.fromJson', () {
    test('lit les deux langues', () {
      final value = Translated.fromJson({'fr': 'Bonjour', 'en': 'Hello'});

      expect(value.fr, 'Bonjour');
      expect(value.en, 'Hello');
    });

    test('une langue absente devient une chaîne vide', () {
      final value = Translated.fromJson({'fr': 'Bonjour'});

      expect(value.en, '');
    });

    test('un tableau vide PHP ([]) devient une valeur vide', () {
      final value = Translated.fromJson(<dynamic>[]);

      expect(value.isEmpty, isTrue);
    });
  });

  test('display renvoie le français, sinon l\'anglais', () {
    expect(const Translated(fr: '', en: 'Hello').display, 'Hello');
    expect(const Translated(fr: 'Bonjour', en: 'Hello').display, 'Bonjour');
  });

  test('toJson renvoie toujours les deux langues ensemble', () {
    expect(const Translated(fr: 'Bonjour').toJson(), {'fr': 'Bonjour', 'en': ''});
  });
}
