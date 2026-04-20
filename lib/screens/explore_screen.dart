import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import 'analysis_screen.dart';
import 'coverages_screen.dart';
import 'books_screen.dart';
import 'interviews_screen.dart';
import 'seminars_screen.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    final bg  = AppColors.bg(isDark);
    final pri = AppColors.textPri(isDark);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Text(
                'Explorar',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: pri,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  _ExploreCard(
                    icon: Icons.bar_chart_outlined,
                    label: 'Análisis',
                    isDark: isDark,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AnalysisScreen()),
                    ),
                  ),
                  _ExploreCard(
                    icon: Icons.flag_outlined,
                    label: 'Coberturas',
                    isDark: isDark,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CoveragesScreen()),
                    ),
                  ),
                  _ExploreCard(
                    icon: Icons.mic_outlined,
                    label: 'Entrevistas',
                    isDark: isDark,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const InterviewsScreen()),
                    ),
                  ),
                  _ExploreCard(
                    icon: Icons.school_outlined,
                    label: 'Seminarios',
                    isDark: isDark,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SeminarsScreen()),
                    ),
                  ),
                  _ExploreCard(
                    icon: Icons.menu_book_outlined,
                    label: 'Libros',
                    isDark: isDark,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BooksScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  final bool comingSoon;

  const _ExploreCard({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri  = AppColors.textPri(isDark);
    final sec  = AppColors.textSec(isDark);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bord, width: 0.5),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.accent, size: 32),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: TextStyle(
                      color: pri,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (comingSoon)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentDim,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Próximamente',
                    style: TextStyle(
                      color: sec,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}