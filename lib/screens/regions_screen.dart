import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../models/region.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import 'region_articles_screen.dart';
import 'region_maps_screen.dart';

class RegionsScreen extends StatelessWidget {
  const RegionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    return Scaffold(
      backgroundColor: AppColors.bg(isDark),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Regiones',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPri(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.1,
                ),
                itemCount: kRegions.length,
                itemBuilder: (context, index) =>
                    _RegionCard(region: kRegions[index], isDark: isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  final Region region;
  final bool isDark;

  const _RegionCard({required this.region, required this.isDark});

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surf(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.bord(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                region.name,
                style: TextStyle(
                  color: AppColors.textPri(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.article_outlined, color: AppColors.accent),
              title: Text('Artículos', style: TextStyle(color: AppColors.textPri(isDark))),
              subtitle: Text('${region.count} artículos', style: TextStyle(color: AppColors.textSec(isDark), fontSize: 12)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RegionArticlesScreen(region: region)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined, color: AppColors.accent),
              title: Text('Mapas', style: TextStyle(color: AppColors.textPri(isDark))),
              subtitle: Text('Infografías y mapas geopolíticos', style: TextStyle(color: AppColors.textSec(isDark), fontSize: 12)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RegionMapsScreen(region: region)),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surf = AppColors.surf(isDark);

    return GestureDetector(
      onTap: () => _showOptions(context),
      child: Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.bord(isDark), width: 0.5),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SvgPicture.network(
                    region.imageUrl,
                    fit: BoxFit.contain,
                    colorFilter: const ColorFilter.mode(Color(0x55C0392B), BlendMode.srcIn),
                    placeholderBuilder: (_) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      region.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPri(isDark),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${region.count} artículos',
                      style: TextStyle(color: AppColors.textSec(isDark), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}