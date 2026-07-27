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

const List<Region> kRegions = [
  Region(
    id: 101,
    name: 'Oriente Medio y Norte de África',
    slug: 'oriente-medio-y-norte-de-africa',
    count: 622,
    imageUrl: 'assets/images/regions/oriente_medio_norte_africa.svg',
  ),
  Region(
    id: 102,
    name: 'Europa',
    slug: 'europa',
    count: 659,
    imageUrl: 'assets/images/regions/europa.svg',
  ),
  Region(
    id: 98,
    name: 'América',
    slug: 'america',
    count: 574,
    imageUrl: 'assets/images/regions/america.svg',
  ),
  Region(
    id: 100,
    name: 'Asia - Pacífico',
    slug: 'asia-pacifico',
    count: 340,
    imageUrl: 'assets/images/regions/asia_pacifico.svg',
  ),
  Region(
    id: 99,
    name: 'Asia Central y Meridional',
    slug: 'asia-central-meridional',
    count: 158,
    imageUrl: 'assets/images/regions/asia_meridional.svg',
  ),
  Region(
    id: 103,
    name: 'África Subsahariana',
    slug: 'africa-subsahariana',
    count: 289,
    imageUrl: 'assets/images/regions/africa_subsahariana.svg',
  ),
];