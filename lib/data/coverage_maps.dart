/// Mapas interactivos de Google Maps asociados a ciertas coberturas.
/// La clave es el slug de la cobertura en WordPress.
///
/// No todas las coberturas tienen mapa: las que no aparecen aquí
/// simplemente no muestran esta sección.
const Map<String, String> kCoverageMaps = {
  'guerra-ruso-ucraniana':
      'https://www.google.com/maps/d/u/0/embed?mid=1c-23EAzAQIeGvhBQ26vUl-Y97ZeZ_oHJ&ehbc=2E312F',
  'guerra-contra-los-carteles-en-mexico':
      'https://www.google.com/maps/d/embed?mid=1fssgCzO1J6TnXS2SqlbutbaxbPQFo3I&ehbc=2E312F',
  'guerra-civil-de-sudan':
      'https://www.google.com/maps/d/embed?mid=19IxdgUFhNYyUIXEkYmQgmaYHz6OTMEk&ehbc=2E312F',
  'guerra-civil-en-siria':
      'https://www.google.com/maps/d/embed?mid=1liqnO9iSvshTLwgPB3q9sJTgfUI&ehbc=2E312F',
  'guerra-civil-en-myanmar':
      'https://www.google.com/maps/d/embed?mid=1xyb73mgbBB4tqQ7SjUpZ5OjA5h7oqYM&ehbc=2E312F',
  'guerra-de-yemen':
      'https://www.google.com/maps/d/embed?mid=1k_5mC2oHM9Lj4I5irFA0pkXbqKQ&ehbc=2E312F',
  'guerra-de-libia':
      'https://www.google.com/maps/d/embed?mid=1IQES33xfW4-aFLXRlpQHQggX81CS6qcC&ehbc=2E312F',
  'guerra-de-etiopia':
      'https://www.google.com/maps/d/embed?mid=1q-M9x3Kshld2Ys36jDU0Y45TmvE7E0km&hl=en&ehbc=2E312F',
};

/// Devuelve la URL del mapa de una cobertura, o null si no tiene.
String? coverageMapUrl(String slug) => kCoverageMaps[slug];
