const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ñ': 'n',
  'œ': 'oe', 'æ': 'ae',
};

/// Slug simple à partir d'un titre français : minuscules, sans accents,
/// espaces et symboles réduits à des tirets (§4.3 : « propose de le générer
/// depuis le titre FR »).
String slugify(String input) {
  var result = input.toLowerCase();
  _accents.forEach((accented, plain) => result = result.replaceAll(accented, plain));
  result = result.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  result = result.replaceAll(RegExp(r'^-+|-+$'), '');
  return result;
}
