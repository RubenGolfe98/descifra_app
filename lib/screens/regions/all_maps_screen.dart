import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/map_image.dart';
import '../../repositories/maps_repository.dart';
import '../../services/theme_notifier.dart';
import '../../theme/app_colors.dart';
import '../../widgets/image_viewer.dart';

class AllMapsScreen extends StatefulWidget {
  const AllMapsScreen({super.key});

  @override
  State<AllMapsScreen> createState() => _AllMapsScreenState();
}

class _AllMapsScreenState extends State<AllMapsScreen> {
  final _repository = MapsRepository();
  late Future<Map<String, List<MapImage>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchAllMaps();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    final bg = AppColors.bg(isDark);
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri = AppColors.textPri(isDark);
    final sec = AppColors.textSec(isDark);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: bord, width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: pri, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text('Mapas',
                      style: TextStyle(
                          color: pri,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: surf,
                border: Border(bottom: BorderSide(color: bord, width: 0.5)),
              ),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: sec, fontSize: 18),
                  children: const [
                    TextSpan(text: 'Colaboración con '),
                    TextSpan(
                      text: 'FairPolitik',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<Map<String, List<MapImage>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent, strokeWidth: 2),
                    );
                  }

                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined,
                              color: AppColors.bord(isDark), size: 48),
                          const SizedBox(height: 12),
                          Text('No se pudieron cargar los mapas',
                              style: TextStyle(color: sec, fontSize: 14)),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () {
                              MapsRepository.clearCache();
                              setState(() {
                                _future = _repository.fetchAllMaps();
                              });
                            },
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    );
                  }

                  final regions = {
                    for (final entry in snapshot.data!.entries)
                      entry.key.replaceAll(
                              'Mapas Colaboración con FairPolitik ', ''):
                          entry.value,
                  };
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: regions.length,
                    itemBuilder: (context, index) {
                      final regionName = regions.keys.elementAt(index);
                      final maps = regions[regionName]!;
                      return _RegionSection(
                        regionName: regionName,
                        maps: maps,
                        isDark: isDark,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionSection extends StatelessWidget {
  final String regionName;
  final List<MapImage> maps;
  final bool isDark;

  const _RegionSection({
    required this.regionName,
    required this.maps,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            regionName,
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: maps.length,
          itemBuilder: (context, index) {
            final map = maps[index];
            return GestureDetector(
              onTap: () => showImageViewer(context, map.url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: map.thumbUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: surf),
                      errorWidget: (_, __, ___) => Container(
                        color: surf,
                        child: Icon(Icons.map_outlined, color: bord, size: 32),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
