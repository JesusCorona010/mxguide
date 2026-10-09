const _accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};

/// Minúsculas y sin acentos, para búsquedas: "zocalo" encuentra "Zócalo".
String normalizeText(String text) {
  var result = text.toLowerCase().trim();
  _accents.forEach((from, to) => result = result.replaceAll(from, to));
  return result;
}