import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/utils/slugify.dart';

void main() {
  test('minuscules, accents retirés, espaces en tirets', () {
    expect(slugify('Système de Gestion à Événements'), 'systeme-de-gestion-a-evenements');
  });

  test('symboles réduits à un seul tiret, sans tiret en tête ni en fin', () {
    expect(slugify('  Café & Croissants !!  '), 'cafe-croissants');
  });
}
