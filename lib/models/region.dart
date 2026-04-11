class Region {
  final int id;
  final String name;
  final String slug;
  final int count;
  final String imageUrl;

  const Region({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
    required this.imageUrl,
  });
}

/// Regiones hardcodeadas — las imágenes son SVGs fijos del tema de WordPress
const List<Region> kRegions = [
  Region(
    id: 101,
    name: 'Oriente Medio y Norte de África',
    slug: 'oriente-medio-y-norte-de-africa',
    count: 622,
    imageUrl: 'https://www.descifrandolaguerra.es/wp-content/uploads/2023/04/oriente_medio_norte_africa.svg',
  ),
  Region(
    id: 102,
    name: 'Europa',
    slug: 'europa',
    count: 659,
    imageUrl: 'https://www.descifrandolaguerra.es/wp-content/uploads/2023/04/europa.svg',
  ),
  Region(
    id: 98,
    name: 'América',
    slug: 'america',
    count: 574,
    imageUrl: 'https://www.descifrandolaguerra.es/wp-content/uploads/2023/04/america.svg',
  ),
  Region(
    id: 100,
    name: 'Asia - Pacífico',
    slug: 'asia-pacifico',
    count: 340,
    imageUrl: 'https://www.descifrandolaguerra.es/wp-content/uploads/2023/04/asia_pacifico.svg',
  ),
  Region(
    id: 99,
    name: 'Asia Central y Meridional',
    slug: 'asia-central-meridional',
    count: 158,
    imageUrl: 'https://www.descifrandolaguerra.es/wp-content/uploads/2023/04/asia_meridional.svg',
  ),
  Region(
    id: 103,
    name: 'África Subsahariana',
    slug: 'africa-subsahariana',
    count: 289,
    imageUrl: 'https://www.descifrandolaguerra.es/wp-content/uploads/2023/02/africa-subsahariana-mapa.svg',
  ),
];
