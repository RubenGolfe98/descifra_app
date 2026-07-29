import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/map_image.dart';
import '../../models/region.dart';
import '../../repositories/maps_repository.dart';
import '../../services/theme_notifier.dart';
import '../../theme/app_colors.dart';
import '../../widgets/dlg_app_bar.dart';
import '../../widgets/image_viewer.dart';

class RegionMapsScreen extends StatefulWidget {
  final Region region;
  const RegionMapsScreen({super.key, required this.region});

  @override
  State<RegionMapsScreen> createState() => _RegionMapsScreenState();
}

class _RegionMapsScreenState extends State<RegionMapsScreen> {
  final _repository = MapsRepository();
  late Future<List<MapImage>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchMapsForRegion(widget.region.slug);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    final bg = AppColors.bg(isDark);
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final sec = AppColors.textSec(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: DlgAppBar(
        title: 'Mapas · ${widget.region.name}',
        isDark: isDark,
      ),
      body: FutureBuilder<List<MapImage>>(
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
                  Text(
                    'No hay mapas disponibles\npara esta región',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: sec, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          final maps = snapshot.data!;

          return Column(
            children: [
              // Cabecera colaboración
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: surf,
                  border: Border(bottom: BorderSide(color: bord, width: 0.5)),
                ),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: sec, fontSize: 18),
                    children: [
                      const TextSpan(text: 'Colaboración con '),
                      TextSpan(
                        text: 'FairPolitik',
                        style: const TextStyle(
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
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
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
                                child: Icon(Icons.map_outlined,
                                    color: AppColors.bord(isDark), size: 32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
